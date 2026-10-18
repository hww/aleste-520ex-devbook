# 12. Interrupts and Jitter

Interrupts are a topic that the Aleste and CPC manuals explain poorly. Meanwhile, without understanding interrupts it is impossible to write a normal program that synchronizes with the screen: music, animation, a game, a demo.

This section covers how interrupts work in the CPC and Aleste, why they "jitter," and how to deal with it.

## Where interrupts come from

In the CPC and Aleste, interrupts are generated not by the processor and not by an external device, but by the **Gate Array** — the same chip that controls the palette, screen modes, and banking.

Inside the Gate Array there is a **6-bit counter** that is incremented on every HSYNC signal (horizontal synchronization). Each screen row is one HSYNC.

The counter counts up to 52, then resets to 0. Since a frame consists of 312 HSYNCs (a standard PAL frame), during one frame the counter manages to count up to 52 six times.

When the counter reaches the value 52 — an interrupt is generated. That is, **there can be up to six interrupts per frame**.

## How the counter reset works

There are two ways to reset the counter.

**First:** bit 4 of the RMR register (Gate Array, register 2). When this bit is set, the HSYNC counter is reset. This is a software reset.

**Second:** the VSYNC signal (vertical synchronization). When the Gate Array "senses" VSYNC, the counter is also reset. This is a hardware reset, and it happens automatically at the start of each frame.

After a reset via VSYNC, a check is made: if bit 6 of the counter was 0 (that is, the counter was less than 32), an interrupt is generated. If the counter was greater than or equal to 32 — no interrupt is generated.

In practice this means: **if an interrupt was not handled (not reset by the processor), then on the next VSYNC the counter has already counted up to 52, and a new interrupt will not be generated**. This is protection against the accumulation of unhandled interrupts.

## The problem: jitter

Here is where the interesting part begins.

The interrupt is generated **not at the moment of VSYNC**, but two HSYNCs after it. That is ~128 microseconds of delay.

In addition, the moment when the processor actually receives the interrupt depends on what it was doing at that moment. If the processor is executing a long instruction — the interrupt will wait. If a short one — it will be handled sooner.

This is called **jitter** — the trembling of the interrupt moment relative to the screen. For music and animation this is critical: if the interrupt handler starts at different moments of the frame, the effect will be unstable.

## The solution: synchronization via HALT

To get precise synchronization with the screen, a combination of polling + HALT is used.

The idea is this:

1. The program polls the VSYNC bit in PPI port B (`#F5XX`) until it becomes active.
2. As soon as VSYNC is detected — the `HALT` instruction is executed. The processor stops and waits for an interrupt.
3. The interrupt arrives two HSYNCs after VSYNC. The processor wakes up exactly at that moment.

Assembly example:

```
; Synchronize with the start of the frame
LD B, #F5          ; PPI port B

vsync_loop:
    IN A, (C)      ; read port B
    RRA            ; bit 0 into carry (VSYNC)
    JR NC, vsync_loop  ; wait until VSYNC becomes active

    HALT           ; sleep until the interrupt
    ; ... wake up synchronized with the screen
```

Why this works: the VSYNC polling code has a **variable delay** at the end (it depends on which iteration of the loop we caught VSYNC on). If we did not use HALT, the wake-up moment would be imprecise. HALT "eats" this uncertainty: the processor sleeps and wakes up strictly on the interrupt signal, regardless of where it was in the loop.

## How long the processor sleeps

After HALT the processor wakes up after **~128 microseconds** plus the time spent in the interrupt handler.

128 microseconds is two HSYNCs. That is exactly how much time passes from VSYNC to the moment the interrupt is generated.

This means: **if you need to do something exactly at the start of the frame, you have 128 microseconds of head start**. Or conversely — you must take this delay into account.

## Practical example: frame counter

A classic task — counting frames. Here is how it is done with synchronization via HALT.

```
FrameCounter: DB 0

; In the interrupt handler
InterruptHandler:
    PUSH AF
    PUSH BC
    PUSH DE
    PUSH HL

    ; Increment the frame counter
    LD HL, FrameCounter
    INC (HL)

    ; ... here is the code that must execute
    ;     once per frame (music, animation)

    POP HL
    POP DE
    POP BC
    POP AF
    EI
    RETI

; Main program
MainLoop:
    ; Synchronization
    LD B, #F5
sync:
    IN A, (C)
    RRA
    JR NC, sync
    HALT

    ; Now we are synchronized with the frame
    ; We can do something that takes less than a frame
    ; ...

    JR MainLoop
```

Note: the interrupt handler must save all registers it uses and end with `EI` + `RETI`.

## Alternative: software delay

Sometimes instead of HALT a software delay is used — an empty loop that takes exactly as much time as needed. This works but is less reliable: if an interrupt occurs during the delay, it will shift.

HALT is more reliable because the processor literally stops and waits for the signal.

## What this means for the programmer

**Interrupts in the CPC/Aleste are 50 Hz.** Six interrupts per frame, but in reality one is used — the one that arrives after VSYNC.

**Jitter is the enemy.** If you do music or animation, synchronize via HALT, not via polling.

**128 microseconds is your head start.** Take it into account if you need precision.

**The handler must be short.** The longer it runs, the more likely the next interrupt will be missed.

**The counter reset is via RMR.** If for some reason an interrupt is not handled and the counter has overflowed, reset it via bit 4 of the Gate Array RMR register.
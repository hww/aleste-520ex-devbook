#!/bin/bash

sjasmplus --raw=magic.com  magic.asm
dsktool a alestedos-dev.dsk magic.com
cp alestedos-dev.dsk /mnt/c/caprice/disk/


#!/usr/bin/env python3
"""Preview a 64-byte C64 sprite frame from the extracted RAM image as ASCII.
Usage: python render_sprite.py <hex_addr>   e.g. python render_sprite.py c000
       python render_sprite.py --ptr 38     (pointer value -> $C000+ptr*64)
"""
import sys
ram=open("bin/full_ram.bin","rb").read()
a=sys.argv[1]
if a=="--ptr":
    addr=0xc000+int(sys.argv[2])*0x40
else:
    addr=int(a,16)
print("sprite @ $%04X (multicolor pairs shown as blocks):"%addr)
for r in range(21):
    b=ram[addr+r*3:addr+r*3+3]
    print("".join("@@" if (by>>(7-bit))&1 else ".." for by in b for bit in range(8)))

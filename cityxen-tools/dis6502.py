# Minimal but complete 6502 disassembler for KickAssembler-ish output
ram=open("ram.bin","rb").read()

# opcode table: mnemonic, addressing mode
# modes: imp, imm, zp, zpx, zpy, izx, izy, abs, abx, aby, ind, rel, acc
T={}
def d(o,m,mode): T[o]=(m,mode)
ops=[
(0x00,"BRK","imp"),(0x01,"ORA","izx"),(0x05,"ORA","zp"),(0x06,"ASL","zp"),(0x08,"PHP","imp"),(0x09,"ORA","imm"),(0x0a,"ASL","acc"),(0x0d,"ORA","abs"),(0x0e,"ASL","abs"),
(0x10,"BPL","rel"),(0x11,"ORA","izy"),(0x15,"ORA","zpx"),(0x16,"ASL","zpx"),(0x18,"CLC","imp"),(0x19,"ORA","aby"),(0x1d,"ORA","abx"),(0x1e,"ASL","abx"),
(0x20,"JSR","abs"),(0x21,"AND","izx"),(0x24,"BIT","zp"),(0x25,"AND","zp"),(0x26,"ROL","zp"),(0x28,"PLP","imp"),(0x29,"AND","imm"),(0x2a,"ROL","acc"),(0x2c,"BIT","abs"),(0x2d,"AND","abs"),(0x2e,"ROL","abs"),
(0x30,"BMI","rel"),(0x31,"AND","izy"),(0x35,"AND","zpx"),(0x36,"ROL","zpx"),(0x38,"SEC","imp"),(0x39,"AND","aby"),(0x3d,"AND","abx"),(0x3e,"ROL","abx"),
(0x40,"RTI","imp"),(0x41,"EOR","izx"),(0x45,"EOR","zp"),(0x46,"LSR","zp"),(0x48,"PHA","imp"),(0x49,"EOR","imm"),(0x4a,"LSR","acc"),(0x4c,"JMP","abs"),(0x4d,"EOR","abs"),(0x4e,"LSR","abs"),
(0x50,"BVC","rel"),(0x51,"EOR","izy"),(0x55,"EOR","zpx"),(0x56,"LSR","zpx"),(0x58,"CLI","imp"),(0x59,"EOR","aby"),(0x5d,"EOR","abx"),(0x5e,"LSR","abx"),
(0x60,"RTS","imp"),(0x61,"ADC","izx"),(0x65,"ADC","zp"),(0x66,"ROR","zp"),(0x68,"PLA","imp"),(0x69,"ADC","imm"),(0x6a,"ROR","acc"),(0x6c,"JMP","ind"),(0x6d,"ADC","abs"),(0x6e,"ROR","abs"),
(0x70,"BVS","rel"),(0x71,"ADC","izy"),(0x75,"ADC","zpx"),(0x76,"ROR","zpx"),(0x78,"SEI","imp"),(0x79,"ADC","aby"),(0x7d,"ADC","abx"),(0x7e,"ROR","abx"),
(0x81,"STA","izx"),(0x84,"STY","zp"),(0x85,"STA","zp"),(0x86,"STX","zp"),(0x88,"DEY","imp"),(0x8a,"TXA","imp"),(0x8c,"STY","abs"),(0x8d,"STA","abs"),(0x8e,"STX","abs"),
(0x90,"BCC","rel"),(0x91,"STA","izy"),(0x94,"STY","zpx"),(0x95,"STA","zpx"),(0x96,"STX","zpy"),(0x98,"TYA","imp"),(0x99,"STA","aby"),(0x9a,"TXS","imp"),(0x9d,"STA","abx"),
(0xa0,"LDY","imm"),(0xa1,"LDA","izx"),(0xa2,"LDX","imm"),(0xa4,"LDY","zp"),(0xa5,"LDA","zp"),(0xa6,"LDX","zp"),(0xa8,"TAY","imp"),(0xa9,"LDA","imm"),(0xaa,"TAX","imp"),(0xac,"LDY","abs"),(0xad,"LDA","abs"),(0xae,"LDX","abs"),
(0xb0,"BCS","rel"),(0xb1,"LDA","izy"),(0xb4,"LDY","zpx"),(0xb5,"LDA","zpx"),(0xb6,"LDX","zpy"),(0xb8,"CLV","imp"),(0xb9,"LDA","aby"),(0xba,"TSX","imp"),(0xbc,"LDY","abx"),(0xbd,"LDA","abx"),(0xbe,"LDX","aby"),
(0xc0,"CPY","imm"),(0xc1,"CMP","izx"),(0xc4,"CPY","zp"),(0xc5,"CMP","zp"),(0xc6,"DEC","zp"),(0xc8,"INY","imp"),(0xc9,"CMP","imm"),(0xca,"DEX","imp"),(0xcc,"CPY","abs"),(0xcd,"CMP","abs"),(0xce,"DEC","abs"),
(0xd0,"BNE","rel"),(0xd1,"CMP","izy"),(0xd5,"CMP","zpx"),(0xd6,"DEC","zpx"),(0xd8,"CLD","imp"),(0xd9,"CMP","aby"),(0xdd,"CMP","abx"),(0xde,"DEC","abx"),
(0xe0,"CPX","imm"),(0xe1,"SBC","izx"),(0xe4,"CPX","zp"),(0xe5,"SBC","zp"),(0xe6,"INC","zp"),(0xe8,"INX","imp"),(0xe9,"SBC","imm"),(0xea,"NOP","imp"),(0xec,"CPX","abs"),(0xed,"SBC","abs"),(0xee,"INC","abs"),
(0xf0,"BEQ","rel"),(0xf1,"SBC","izy"),(0xf5,"SBC","zpx"),(0xf6,"SBC","zpx"),(0xf8,"SED","imp"),(0xf9,"SBC","aby"),(0xfd,"SBC","abx"),(0xfe,"INC","abx"),
]
for o,m,md in ops: d(o,m,md)
ln={"imp":1,"acc":1,"imm":2,"zp":2,"zpx":2,"zpy":2,"izx":2,"izy":2,"rel":2,"abs":3,"abx":3,"aby":3,"ind":3}

def fmt(pc,b):
    op=b[pc]
    if op not in T: return pc+1,".byte $%02x"%op,None
    m,mode=T[op]; n=ln[mode]
    if mode=="imp": return pc+1,m,None
    if mode=="acc": return pc+1,m,None
    if mode=="imm": return pc+2,"%s #$%02x"%(m,b[pc+1]),None
    if mode in("zp","zpx","zpy","izx","izy"):
        v=b[pc+1]
        suf={"zp":"","zpx":",x","zpy":",y","izx":",x)","izy":"),y"}[mode]
        pre="(" if mode in("izx","izy") else ""
        return pc+2,"%s %s$%02x%s"%(m,pre,v,suf),None
    if mode=="rel":
        v=b[pc+1]; tgt=(pc+2+(v-256 if v>127 else v))&0xffff
        return pc+2,"%s $%04x"%(m,tgt),tgt
    # abs modes
    v=b[pc+1]|(b[pc+2]<<8)
    if mode=="abs": return pc+3,"%s $%04x"%(m,v),v
    if mode=="abx": return pc+3,"%s $%04x,x"%(m,v),v
    if mode=="aby": return pc+3,"%s $%04x,y"%(m,v),v
    if mode=="ind": return pc+3,"%s ($%04x)"%(m,v),v
    return pc+n,m,None

def disasm(start,end):
    pc=start
    while pc<end:
        npc,txt,tgt=fmt(pc,ram)
        print("%04x: %-20s ; %s"%(pc,txt," ".join("%02x"%x for x in ram[pc:npc])))
        pc=npc

import sys
s=int(sys.argv[1],16); e=int(sys.argv[2],16)
disasm(s,e)

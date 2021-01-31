
//---------------------------------------------------------------------
//	MOVE SHAPE -> BUF
//---------------------------------------------------------------------

.local	MoveShape2Buf

	mva Sprite0+@Spr.bitmaps,x	zp+@zp.hlp1
	mva Sprite0+@Spr.bitmaps+1,x	zp+@zp.hlp1+1

	lda Sprite0+@Spr.index,x

	asl @
bck	tay
	lda (zp+@zp.hlp1),y
	sta zp+@zp.hlp2
	iny
	lda (zp+@zp.hlp1),y
	bne skp

	lda #0
	sta Sprite0+@Spr.index,x
	beq bck

skp	sta zp+@zp.hlp2+1

	inc Sprite0+@Spr.delay,x
	lda Sprite0+@Spr.delay,x
	and #3
	sne

	inc Sprite0+@Spr.index,x

// ---------------------- Offset Y --------------------------

	lda Sprite0+@Spr.yOk,x
	and #7
	eor #7

	clc

	.rept 16,#
	sta ofs:1+1

	ift :1<>15
	adc #8
	eif
	.endr

// ---------------------- Offset X --------------------------

	lda  Sprite0+@Spr.xOk,x
	and #3
	bne ne0

// --------------------- X and 3 = 0 ------------------------

eq0	.local

	lda #$ff
	:21 sta shpBuf+96+8+#

	lda zp+@zp.hlp2
	sta adr0+1
	adc #21
	sta adr1+1
	adc #21
	sta adr2+1

	lda zp+@zp.hlp2+1
	sta adr0+2
	sta adr1+2
	sta adr2+2

	ldy #20
loop
adr0	lda $ffff,y
	sta shpBuf+8,y

adr1	lda $ffff,y
	sta shpBuf+32+8,y

adr2	lda $ffff,y
	sta shpBuf+64+8,y

	dey
	bpl loop

	jmp MOVE

	.endl

// -------------------- X and 3 <> 0 ------------------------

ne0	.local

	tax
	lda tHShift,x
	sta tShfL0+2
	sta tShfL1+2
	sta tShfL2+2

	lda tLShift,x
	sta tShfH0+2
	sta tShfH1+2
	sta tShfH2+2

	mva tOraLeft,x	_ORA1+1
	mva tOraRight,x	_ORA0+1

	lda zp+@zp.hlp2
	sta adr0+1
	adc #21
	sta adr1+1
	adc #21
	sta adr2+1

	lda zp+@zp.hlp2+1
	sta adr0+2
	sta adr1+2
	sta adr2+2

	ldy #20
loop
adr2	ldx $ffff,y

tShfH0	lda $ff00,x
_ORA0	ora #0
	sta shpBuf+96+8,y

tShfL0	lda $ff00,x

adr1	ldx $ffff,y

tShfH1	ora $ff00,x
	sta shpBuf+64+8,y

tShfL1	lda $ff00,x

adr0	ldx $ffff,y

tShfH2	ora $ff00,x
	sta shpBuf+32+8,y

tShfL2	lda $ff00,x
_ORA1	ora #$f0
	sta shpBuf+0+8,y

	dey
	bpl loop

;	jmp MOVE
	.endl

.endl


//---------------------------------------------------------------------
//	MOVE
//---------------------------------------------------------------------

MOVE
	ldy #7
mloop
ofs0	ldx shpBuf,y
src0	lda $ffff,y
	and tMask,x
	ora tByte,x
dst0	sta $ffff,y

ofs4	ldx shpBuf+32,y
src1	lda $ffff,y
	and tMask,x
	ora tByte,x
dst1	sta $ffff,y

ofs8	ldx shpBuf+64,y
src2	lda $ffff,y
	and tMask,x
	ora tByte,x
dst2	sta $ffff,y

ofs12	ldx shpBuf+96,y
src3	lda $ffff,y
	and tMask,x
	ora tByte,x
dst3	sta $ffff,y


ofs1	ldx shpBuf+8,y
src4	lda $ffff,y
	and tMask,x
	ora tByte,x
dst4	sta $ffff,y

ofs5	ldx shpBuf+40,y
src5	lda $ffff,y
	and tMask,x
	ora tByte,x
dst5	sta $ffff,y

ofs9	ldx shpBuf+72,y
src6	lda $ffff,y
	and tMask,x
	ora tByte,x
dst6	sta $ffff,y

ofs13	ldx shpBuf+104,y
src7	lda $ffff,y
	and tMask,x
	ora tByte,x
dst7	sta $ffff,y


ofs2	ldx shpBuf+16,y
src8	lda $ffff,y
	and tMask,x
	ora tByte,x
dst8	sta $ffff,y

ofs6	ldx shpBuf+48,y
src9	lda $ffff,y
	and tMask,x
	ora tByte,x
dst9	sta $ffff,y

ofs10	ldx shpBuf+80,y
src10	lda $ffff,y
	and tMask,x
	ora tByte,x
dst10	sta $ffff,y

ofs14	ldx shpBuf+112,y
src11	lda $ffff,y
	and tMask,x
	ora tByte,x
dst11	sta $ffff,y


ofs3	ldx shpBuf+24,y
src12	lda $ffff,y
	and tMask,x
	ora tByte,x
dst12	sta $ffff,y

ofs7	ldx shpBuf+56,y
src13	lda $ffff,y
	and tMask,x
	ora tByte,x
dst13	sta $ffff,y

ofs11	ldx shpBuf+88,y
src14	lda $ffff,y
	and tMask,x
	ora tByte,x
dst14	sta $ffff,y

ofs15	ldx shpBuf+120,y
src15	lda $ffff,y
	and tMask,x
	ora tByte,x
dst15	sta $ffff,y

	dey
	jpl mloop
	rts

;//////////////////////////////////////////////////////////////////////////////////////
;// Apple ][e BASE main program by Deadline / CityXen
;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////
;// 
;//  VASM 6502 Required
;// http://www.ibaug.de/vasm/vasm6502.zip
;//
;//////////////////////////////////////////////////////////////////////////////////////

NewLine equ $FC62	;CR - Carriage Return to Screen

	ORG $0C00	;Program Start
	
	jsr NewLine			;Start a new line

	lda #>HelloWorld
	sta $41
	lda #<HelloWorld
	sta $40
	jsr PrintStr

loop:
	jmp loop
	rts
	
HelloWorld:				;255 terminated string
	db "Apple ][e main.asm] ",255
	
PrintChar:
	pha
		clc
		adc #128		;Correction for weird character map!
		jsr $FDF0		;COUT1 - Output Character to Screen
	pla
	rts
	
				

PrintStr:
	ldy #0				;Set Y to zero
PrintStr_again:
	lda ($40),y			;Load a character from addr in $20+Y 
	
	cmp #255			;If we got 255, we're done
	beq PrintStr_Done
	
	jsr PrintChar		;Print Character
	iny					;Inc Y and repeat
	jmp PrintStr_again
PrintStr_Done:
	rts	


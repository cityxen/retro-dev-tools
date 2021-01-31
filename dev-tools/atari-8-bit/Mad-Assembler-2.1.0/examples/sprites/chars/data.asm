
* ---	TABLICE
;
; najlepiej zeby zaczyna�y si� od pocz�tku strony, czy te� mie�ci�y si� w jej granicach
;

*---
	.align

* ---	shpAdr, mskAdr

; adgx
; behx
; cfix
; xxxx  4x4 = 16 + 1

	?b = 16*8		; liczba znak�w przypadaj�ca na 1 klatk� animacji (duch12x24)
	?c = 16			; ?C=16 aby wyr�wna� do strony pami�ci

mskAdr12	:?c	_ADRH #	$6000,$6800,$7000,$7800		; ?c*8 = 128 bajt�w

shpAdr12	:?c	_ADR # 	$4000,$4800,$5000,$5800		; ?c*8 = 128 bajt�w

	ert .lo(mskAdr12)<>0	; mskAdr12 koniecznie od pocz�tku strony pami�ci


; adx
; bex
; cfx
; xxx  3x4 = 12 + 1

	?b = 12*8		; liczba znak�w przypadaj�ca na 1 klatk� animacji (duch8x24)
	?c = 32			; ?C=32 aby wyr�wna� do strony pami�ci

shpAdr8		:?c	_ADR # 	$4000,$4800,$5000,$5800		; ?c*8 = 256 bajt�w

mskAdr8		:?c	_ADRH #	$6000,$6800,$7000,$7800		; ?c*8 = 256 bajt�w

	ert .lo(mskAdr8)<>0	; mskAdr8 koniecznie od pocz�tku strony pami�ci


_ADR	.macro
	dta a(:2+:1*?b)
	dta a(:3+:1*?b)
	dta a(:4+:1*?b)
	dta a(:5+:1*?b)
	.endm

_ADRH	.macro
	dta h(:2+:1*?b , :2+:1*?b)
	dta h(:3+:1*?b , :3+:1*?b)
	dta h(:4+:1*?b , :4+:1*?b)
	dta h(:5+:1*?b , :5+:1*?b)
	.endm


* ---	STRUKTURY DANYCH
; rozmiar struktury @SPRITE limituje maksymaln� liczb� duch�w (256/@SPRITE)
; rozmiar struktury @SHAPE limituje maksymaln� liczb� bank�w pami�ci z kszta�tami duch�w (256/@SHAPE)

sts_visible	= $80	; bit7
sts_newsprt	= $40	; bit6


@SPRITE	.struct
	prg	.word	; adres programu obs�ugi ducha
	frm	.word	; adres tablicy z kolejnymi numerami klatek animacji

	shp	.byte	; bezpo�redni indeks do tablicy SHAPES, pozwala odczyta� parametry dotycz�ce tego kszta�tu ducha
	psx	.byte	; pozycja pozioma X
	psy	.byte	; pozycja pionowa Y
	old_psx	.byte	; poprzednia pozycja pozioma X
	old_psy	.byte	; poprzednia pozycja pionowa Y
	cnt	.byte	; licznik klatek animacji
	sts	.byte	; status sprita
			; bit7 = sts_visible:
			;			0 - widoczny
			;			1 - nie widoczny
			; bit6 = sts_newsprt:
			;			0 - obs�uguj w aktualnej kolejce zada�
			;			1 - obs�uguj w nast�pnej kolejce zada�
	.ends


@SHAPE	.struct
	bnk	.byte	; bank z klatkami animacji ducha (warto�� dla rejestru PORTB)
	typ	.byte	; =0 duch 12x24, <>0 duch 8x24 (!!! tylko jeden typ ducha w banku pami�ci !!!)
	hig	.byte	; wysoko�� dla tego kszta�tu, warto�� pomocna przy detekcji kolizji
			; duchy zawsze maj� wysoko�� 24 linii ale nie zawsze wszystkie linie s� wykorzystane
			; minimalna warto�� HIG = 5 (!!! nie wolno wstawi� mniejszej warto�ci !!!)
	.ends


shapes	dta	@shape	[max_shapes-1]
sprites	dta	@sprite	[max_sprites-1]

/*
 przykladowy program wykorzystujacy deklaracje procedury .PROC z przekazywanymi parametrami typu .REG, .VAR

 program realizuje zamiane wartosci typu WORD na postac hexadecymalna

 ostatnia modyfikacja: 24.06.2007
*/

	org $2000

main
	hex #$12b5 #$bc40+18+10*40	; wywolujemy procedure HEX, pierwszym parametrem jest wartosc #$12b5
					; drugi parametr to adres pamieci obrazu gdzie zostanie wyswietlony tekst z wartoscia HEX

	jmp *				; petla bez konca, aby zobaczyc efekt dzialania



* ----------- *
*  PROCEDURE  *
* ----------- *
// procedurka reprezentujaca wartosc 1-bajtowa (BYTE) w postaci HEXadecymalnej
lHex	.proc ( .byte a ) .reg

// dyrektywa .REG okresla sposob przekazywania parametrow do procedury - przez rejestry CPU
// nazwy parametrow moga skladac sie tylko z liter A,X,Y i ich kombinacji
// maksymalnie mozemy w ten sposob przekazac 3 bajty

	pha		; zawarto�� akumulatora zapami�tamy na stosie
	:4 lsr @

	jsr HEX2INT

	tax		; wynik dzia�ania w regX

	pla		; zdejmujemy ze stosu zapami�tan� wcze�niej zawarto�� akumulatora
	and #$0f

HEX2INT	SED
	CMP #$0A
	ADC #"0"
	CLD
			; wynik dzia�ania w regA
	rts

	.endp


// procedurka reprezentujaca wartosc 2-bajtowa (WORD) w postaci HEXadecymalnej
hex	.proc ( .word par1, out+1 ) .var

// typ parametr�w .VAR oznacza przekazywanie parametr�w przez wcze�niej zdefiniowane zmienne
// MADS najpierw szuka nazw zmiennych zadeklarowanych jako parametry w aktualnie przetwarzanej procedurze .PROC,
// a je�li ich nie znajdzie szuka ich poza procedur� .PROC

	.var	par1	.word	; deklaracja zmiennej PAR1 typu .WORD
				; zmienna zostanie od�o�ona na ko�cu bloku .PROC

	lHex par1

	ldy #3
	jsr put

	lHex par1+1

	ldy #1
	jsr put

	RTS		; wyjscie z procedury HEX

put	jsr out		; regA
	dey
	txa		; regX

out	sta $ffff,y
	rts

	.endp

; ---
	run main

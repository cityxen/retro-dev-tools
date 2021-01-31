
hscrol	= $d404

	org $600

dlist	dta $70,$70,$70		; 24 puste linie ($70 = 8 pustych linii)
	dta $42|$10		; rozkaz ANTIC-a LMS ($42) dla trybu $02 + $10 dla HSCROL
adres	dta a(text)		; adres scrolla
	dta $41,a(dlist)	; zako�czenie programu ANTIC-a

main	mwa #dlist 560		; ustawiamy nowy adres programu ANTIC-a

loop
	lda tmp			; p�ynny scroll, przepisanie warto�ci TMP do rejestru HSCROL
	sta hscrol		; koniecznie przed poni�sz� p�tl� op�niaj�c�

	lda:cmp:req 20

	dec tmp			; zmniejszenie kom�rki TMP [3,2,1,0]
	bpl loop		; p�tla

	mva #3 tmp		; odnowienie warto�ci kom�rki TMP

	inc adres		; scroll zgrubny

	ldx adres

	lda scroll
ascrol	equ *-2

	sta text+48,x
	sta text+48-256,x

	inw ascrol

	cpw ascrol #end_scroll
	scc
	mwa #scroll ascrol

	jmp loop

tmp	dta 3			; pomocnicza kom�rka pami�ci TMP

scroll	dta d'to jest tekst przykladowy, scrolla z buforem ulegajacemu zapetleniu'
end_scroll

	org $a000
text	:48 dta d' '

	run main		; adres uruchomienia tego przyk�adu

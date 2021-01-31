
/*

  Przyklad wykorzystania bliblioteki procedur dla operacji input/output:

  OPEN		(BYTE,BYTE,WORD)
  READ		(BYTE,BYTE,WORD,WORD)
  CLOSE		(BYTE)
  PCIOV

  PUTLINE	(WORD)		- procedura PUTLINE z biblioteki STDIO

  Przykladowy program odczytuje katalog dyskietki wg podanej maski

*/

	org $2000
main
	putchar #'>'		; znak zach�ty '>'

	getline #fnam		; odczyt znak�w, wprowadzana jest nazwa urz�dzenia i maska

	open #$10,#6,#fnam	; otwierany jest #1 kana� do transmisji
	bmi stop
				; czytamy nazwy plik�w z katalogu
loop	read #$10,#5,#buf,#128
	bmi stop		; je�li wyst�pi b��d to ko�czymy odczyt nazw plik�w
	putline #buf		; wy�wietlamy na ekranie odczytan� nazw� pliku
	jmp loop

stop	close #$10		; zamykamy #1 kana�

	printf
	.by $9b 'Press any key' $9b $00

	mwa #$ff 764

wait	ldy:iny 764
	beq wait

	mwa #$ff 764
	rts

	.link 'stdio\printf.obx'
	.link 'stdio\putchar.obx'
	.link 'stdio\getline.obx'
	.link 'stdio\putline.obx'
	.link 'io\io_lib.obx'

fnam	.ds 128

buf	equ *

*---
	run main

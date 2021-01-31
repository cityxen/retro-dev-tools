
* ---	Eratosthenes Sieve benchmark (with speed optimization)

true	= 1
false	= 0
size	= 255
sizepl	= 256

flags	= $8000

iterations = 10


	org $2000

;void wait(void)
;{
; unsigned char a=PEEK(tick);
; while (PEEK(tick)==a) { ; }
;}

.proc wait
	lda:cmp:req 20
	rts
.endp


main

;int main()
;{
;	unsigned int i, prime, k, count, iter;
	.var i, prime, k, count, iter .word = $80

	.var iterations_num = iterations .word

;	printf("10 iterations\n");

	jsr printf
	.by '% iterations' $9b $9b 0
	dta a(iterations_num)

;	wait();
	wait

	mwa #0 $13

;	iter = 1;

	mva #1 iter

;	while (iter <= 10) {
	#while .word iter < #iterations+1	;0

;		count = 0;
		mwa #0 count

;		i = 0;
;		mwa #0 i

		mwa #flags adr1

		ldy #true

;		while (i <= size) {
		#while .word adr1 < #flags+size+1		;1

;			flags[i] = true;

			sty $ffff
		adr1:	equ *-2
		
;			i++;
			inw adr1
;		}
		#end

;		i = 0;
		mwa #0 i
		
;		while (i <= size) {
		#while .word i < #size+1		;2

;			if (flags[i]) {

			lda <flags
			add i
			tay
			lda >flags
			adc i+1
			sta adr2+1

			lda $ff00,y
		adr2:	equ *-2

			#if .byte @

;				prime = i + i + 3;

				adw i i prime

				adw prime #3		
				
;				k = i + prime;

				adw i prime k

;				while (k <= size) {
				#while .word k < #size+1		;3

;					flags[k] = false;

					lda <flags
					add k
					tay
					lda >flags
					adc k+1
					sta adr3+1

					lda #false
					sta $ff00,y
				adr3:	equ *-2

;					k = k + prime;

					adw k prime

;				}
				#end

;				count++;
				inw count

;			}
			#end

;			i++;
			inw i

;		}
		#end

;		iter++;

		inw iter

;	}
	#end
	
;	printf("\n%d primes\n", count);

	.var time .word

	mva $14 time
	mva $13 time+1
	
	jsr printf
	.by '% primes',$9b
	.by '% fps',$9b,$9b
	.by 'Press any key',$9b,0
	dta a(count)
	dta a(time)

	mva #$ff 764

loop	ldy:iny 764
	beq loop

	rts


	.link 'libraries/stdio/lib/printf.obx'


	run main

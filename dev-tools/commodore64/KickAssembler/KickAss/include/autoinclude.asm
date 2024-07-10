/*
//-------------------------------
// Color Constants 
//-------------------------------
.const BLACK = 0
.const WHITE = 1
.const RED = 2
.const CYAN = 3
.const PURPLE = 4
.const GREEN = 5
.const BLUE = 6
.const YELLOW = 7
.const ORANGE = 8
.const BROWN = 9
.const LIGHT_RED = 10
.const DARK_GRAY = 11
.const DARK_GREY = 11
.const GRAY = 12
.const GREY = 12
.const LIGHT_GREEN = 13
.const LIGHT_BLUE = 14
.const LIGHT_GRAY = 15
.const LIGHT_GREY = 15
*/

//-------------------------------
// Macros
//-------------------------------

/*----------------------------------------------------------
 BasicUpstart

 Syntax:	:BasicUpstart(address)	
 Usage example: :BasicUpstart($2000)
 	         Creates a basic program that sys' the address
------------------------------------------------------------*/
.macro BasicUpstart(address) {
	.word upstartEnd  // link address
    .word 10   // line num
    .byte $9e  // sys
	.text toIntString(address)
	.byte 0
upstartEnd:
    .word 0  // empty link signals the end of the program
}

/*----------------------------------------------------------
 BasicUpstart

 Syntax:	:BasicUpstart(address)	
 Usage example: :BasicUpstart($2000)
 	         Creates a basic program that sys' the address
------------------------------------------------------------*/
.macro BasicUpstart2(address) {
	* = $0801 "Basic"
	.word upstartEnd  // link address
    .word 10   // line num
    .byte $9e  // sys
	.text toIntString(address)
	.byte 0
upstartEnd:
    .word 0  // empty link signals the end of the program
    * = $080e "Basic End"
}
 
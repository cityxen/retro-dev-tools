///////////////////////////////////////////////////////////////
// FujiNet Functions - Atari 8-Bit
// By Deadline / CityXen
//
// FujiNet is the native network solution for Atari 8-bit.
// Access uses the N: CIO handler built into FujiNet firmware.
// URL format: N:HTTP://hostname/path
//
// Requires: sys.il.asm, print.il.asm, score.il.asm, input.il.asm

#importonce

// CIO (Central I/O) constants
.const FJ_CIOV       = $E456    // CIO entry point
.const FJ_IOCB1      = $0350    // IOCB channel 1 (channel 0 reserved for E:)
.const FJ_IOCB_BAL   = $04      // buffer address lo offset
.const FJ_IOCB_BAH   = $05      // buffer address hi offset
.const FJ_IOCB_BLL   = $08      // buffer length lo offset
.const FJ_IOCB_BLH   = $09      // buffer length hi offset
.const FJ_IOCB_AX1   = $0A     // AUX1 (open mode)
.const FJ_IOCB_AX2   = $0B     // AUX2
.const FJ_IOCB_COM   = $02      // command offset
.const FJ_CIO_OPEN   = $03
.const FJ_CIO_CLOSE  = $0C
.const FJ_CIO_GET    = $07      // get bytes
.const FJ_OPEN_READ  = $04      // AUX1 = read

///////////////////////////////////////////////////////////////
// State variables

fj_detected:     .byte 0
fj_enabled:      .byte 1

fj_detected_text:
.text "FUJINET FOUND:"
.byte 0
fj_enabled_text:
.text "FUJINET ENABLED:"
.byte 0

fj_detect_url:
.text "N:TCP://localhost/0"
fj_detect_url_end:

///////////////////////////////////////////////////////////////
// fj_detect_fujinet: probe N: handler; set fj_detected=1 if present
fj_detect_fujinet:
    lda #0
    sta fj_detected

    lda #<fj_detect_url
    sta FJ_IOCB1 + FJ_IOCB_BAL
    lda #>fj_detect_url
    sta FJ_IOCB1 + FJ_IOCB_BAH
    lda #(fj_detect_url_end - fj_detect_url)
    sta FJ_IOCB1 + FJ_IOCB_BLL
    lda #0
    sta FJ_IOCB1 + FJ_IOCB_BLH
    lda #FJ_OPEN_READ
    sta FJ_IOCB1 + FJ_IOCB_AX1
    lda #0
    sta FJ_IOCB1 + FJ_IOCB_AX2
    lda #FJ_CIO_OPEN
    sta FJ_IOCB1 + FJ_IOCB_COM
    ldx #$10                // channel 1 = IOCB offset $10
    jsr FJ_CIOV
    bmi fj_detect_done      // negative status = error, not present

    lda #1
    sta fj_detected

    lda #FJ_CIO_CLOSE       // close probe channel
    sta FJ_IOCB1 + FJ_IOCB_COM
    ldx #$10
    jsr FJ_CIOV
fj_detect_done:
    rts

///////////////////////////////////////////////////////////////
// Top-10 score table (loaded directly from FujiNet)
FJHS_API_TOP_10_TABLE:
FJHS1a:  .text "0000000099"  .byte 0
FJHS1b:  .text "CITYXEN"     .byte 0,0,0,0,0,0,0,0,0,0
FJHS2a:  .text "0000000089"  .byte 0
FJHS2b:  .text "CITYXEN"     .byte 0,0,0,0,0,0,0,0,0,0
FJHS3a:  .text "0000000078"  .byte 0
FJHS3b:  .text "CITYXEN"     .byte 0,0,0,0,0,0,0,0,0,0
FJHS4a:  .text "0000000067"  .byte 0
FJHS4b:  .text "CITYXEN"     .byte 0,0,0,0,0,0,0,0,0,0
FJHS5a:  .text "0000000056"  .byte 0
FJHS5b:  .text "CITYXEN"     .byte 0,0,0,0,0,0,0,0,0,0
FJHS6a:  .text "0000000045"  .byte 0
FJHS6b:  .text "CITYXEN"     .byte 0,0,0,0,0,0,0,0,0,0
FJHS7a:  .text "0000000034"  .byte 0
FJHS7b:  .text "CITYXEN"     .byte 0,0,0,0,0,0,0,0,0,0
FJHS8a:  .text "0000000023"  .byte 0
FJHS8b:  .text "CITYXEN"     .byte 0,0,0,0,0,0,0,0,0,0
FJHS9a:  .text "0000000012"  .byte 0
FJHS9b:  .text "CITYXEN"     .byte 0,0,0,0,0,0,0,0,0,0
FJHS10a: .text "0000000011"  .byte 0
FJHS10b: .text "CITYXEN"     .byte 0,0,0,0,0,0,0,0,0,0

///////////////////////////////////////////////////////////////
// URL tables — N:HTTP://... format

FJHS_API_URL_ADD_SCORE:
.text "N:HTTP://scores.cityxen.com/WAD"
FJHS_API_URL_AS_RETS:   .text "?X="
FJHS_API_URL_AS_NUM:    .text "10"
                        .text "&S="
FJHS_API_URL_AS_SCORE:  .text "SSSSSSSSSS"
                        .text "&N="
FJHS_API_URL_AS_NAME:   .text "NNNNNNNNNNNNNNNN"
FJHS_API_URL_ADD_SCORE_END:
FJHS_API_URL_ADD_SCORE_LENGTH: .byte 0

FJHS_API_URL_GET_SCORE:
.text "N:HTTP://scores.cityxen.com/WAD"
.text "?X="
FJHS_API_URL_GS_NUM:    .text "10"
FJHS_API_URL_GET_SCORE_END:
FJHS_API_URL_GET_SCORE_LENGTH: .byte 0

FJHS_USER_NAME: .text "NNNNNNNNNNNNNNNN"  .byte 0

FJHS_CALC_URL_LENS:
    lda #(FJHS_API_URL_GET_SCORE_END - FJHS_API_URL_GET_SCORE)
    sta FJHS_API_URL_GET_SCORE_LENGTH
    lda #(FJHS_API_URL_ADD_SCORE_END - FJHS_API_URL_ADD_SCORE)
    sta FJHS_API_URL_ADD_SCORE_LENGTH
    rts

///////////////////////////////////////////////////////////////
// fj_url_clear: reset score and name fields in URL table
fj_url_clear:
    lda #$20
    ldx #0
fjuc_name:
    sta FJHS_API_URL_AS_NAME,x
    inx
    cpx #16
    bne fjuc_name
    lda #$30
    ldx #0
fjuc_score:
    sta FJHS_API_URL_AS_SCORE,x
    inx
    cpx #10
    bne fjuc_score
    rts

///////////////////////////////////////////////////////////////
// fj_cio_load: open URL in FJHS_API_URL_ADD_SCORE (length in A),
//              read into FJHS_API_TOP_10_TABLE, then close.
// Caller sets: url pointer in zero page via fj_set_url_ptr
fj_cio_url:     .word 0     // pointer to URL string
fj_cio_len:     .byte 0     // URL length
fj_cio_dest:    .word 0     // destination buffer
fj_cio_size:    .word 0     // bytes to read

fj_cio_load:
    lda fj_cio_url
    sta FJ_IOCB1 + FJ_IOCB_BAL
    lda fj_cio_url+1
    sta FJ_IOCB1 + FJ_IOCB_BAH
    lda fj_cio_len
    sta FJ_IOCB1 + FJ_IOCB_BLL
    lda #0
    sta FJ_IOCB1 + FJ_IOCB_BLH
    lda #FJ_OPEN_READ
    sta FJ_IOCB1 + FJ_IOCB_AX1
    sta FJ_IOCB1 + FJ_IOCB_AX2  // AX2=0 handled by lda #0 above... use separate
    lda #0
    sta FJ_IOCB1 + FJ_IOCB_AX2
    lda #FJ_CIO_OPEN
    sta FJ_IOCB1 + FJ_IOCB_COM
    ldx #$10
    jsr FJ_CIOV
    bmi fjcl_done           // open failed

    lda fj_cio_dest
    sta FJ_IOCB1 + FJ_IOCB_BAL
    lda fj_cio_dest+1
    sta FJ_IOCB1 + FJ_IOCB_BAH
    lda fj_cio_size
    sta FJ_IOCB1 + FJ_IOCB_BLL
    lda fj_cio_size+1
    sta FJ_IOCB1 + FJ_IOCB_BLH
    lda #FJ_CIO_GET
    sta FJ_IOCB1 + FJ_IOCB_COM
    ldx #$10
    jsr FJ_CIOV

    lda #FJ_CIO_CLOSE
    sta FJ_IOCB1 + FJ_IOCB_COM
    ldx #$10
    jsr FJ_CIOV
fjcl_done:
    rts

///////////////////////////////////////////////////////////////
// FJHS_API_GET_SCORE: fetch top-10 table from FujiNet server
FJHS_API_GET_SCORE:
    lda fj_enabled
    bne !+
    rts
!:
    jsr fj_url_clear
    lda #<FJHS_API_URL_GET_SCORE
    sta fj_cio_url
    lda #>FJHS_API_URL_GET_SCORE
    sta fj_cio_url+1
    lda FJHS_API_URL_GET_SCORE_LENGTH
    sta fj_cio_len
    lda #<FJHS_API_TOP_10_TABLE
    sta fj_cio_dest
    lda #>FJHS_API_TOP_10_TABLE
    sta fj_cio_dest+1
    lda #<(FJHS10b + 17 - FJHS_API_TOP_10_TABLE)
    sta fj_cio_size
    lda #>(FJHS10b + 17 - FJHS_API_TOP_10_TABLE)
    sta fj_cio_size+1
    jmp fj_cio_load

///////////////////////////////////////////////////////////////
// FJHS_API_SET_SCORE: submit score+name to FujiNet server
FJHS_API_SET_SCORE:
    lda fj_enabled
    bne !+
    rts
!:
    jsr fj_url_clear
    // Copy score string and name into URL (caller sets score_str, user_name)
    StrCpyL(score_str, FJHS_API_URL_AS_SCORE, 10)
    StrCpyL(FJHS_USER_NAME, FJHS_API_URL_AS_NAME, 15)
    lda #<FJHS_API_URL_ADD_SCORE
    sta fj_cio_url
    lda #>FJHS_API_URL_ADD_SCORE
    sta fj_cio_url+1
    lda FJHS_API_URL_ADD_SCORE_LENGTH
    sta fj_cio_len
    lda #<FJHS_API_TOP_10_TABLE
    sta fj_cio_dest
    lda #>FJHS_API_TOP_10_TABLE
    sta fj_cio_dest+1
    lda #<(FJHS10b + 17 - FJHS_API_TOP_10_TABLE)
    sta fj_cio_size
    lda #>(FJHS10b + 17 - FJHS_API_TOP_10_TABLE)
    sta fj_cio_size+1
    jmp fj_cio_load

///////////////////////////////////////////////////////////////
// FJHS_DRAW: display top-10 scores (uses Print macros)
FJHS_NL: .byte $9B, 0      // Atari EOL ($9B) then null terminator

FJHS_API_SCORE_MSG:
.text "   -= FUJINET HISCORES =-"
.byte $9B, 0

FJHS_DRAW:
    Print(FJHS_API_SCORE_MSG)
    Print(FJHS_NL)
    PrintLeadingZerosAsSpaces(FJHS1a)  PrintChr($20)  Print(FJHS1b)
    Print(FJHS_NL)
    PrintLeadingZerosAsSpaces(FJHS2a)  PrintChr($20)  Print(FJHS2b)
    Print(FJHS_NL)
    PrintLeadingZerosAsSpaces(FJHS3a)  PrintChr($20)  Print(FJHS3b)
    Print(FJHS_NL)
    PrintLeadingZerosAsSpaces(FJHS4a)  PrintChr($20)  Print(FJHS4b)
    Print(FJHS_NL)
    PrintLeadingZerosAsSpaces(FJHS5a)  PrintChr($20)  Print(FJHS5b)
    Print(FJHS_NL)
    PrintLeadingZerosAsSpaces(FJHS6a)  PrintChr($20)  Print(FJHS6b)
    Print(FJHS_NL)
    PrintLeadingZerosAsSpaces(FJHS7a)  PrintChr($20)  Print(FJHS7b)
    Print(FJHS_NL)
    PrintLeadingZerosAsSpaces(FJHS8a)  PrintChr($20)  Print(FJHS8b)
    Print(FJHS_NL)
    PrintLeadingZerosAsSpaces(FJHS9a)  PrintChr($20)  Print(FJHS9b)
    Print(FJHS_NL)
    PrintLeadingZerosAsSpaces(FJHS10a) PrintChr($20)  Print(FJHS10b)
    Print(FJHS_NL)
    rts

///////////////////////////////////////////////////////////////
// FJHS_NAME_ENTRY: display game-over screen, collect name, submit
FJHS_API_ENTER_MSG:
.byte $93
.text "   GAME OVER!"
.byte $9B, $9B
.text "   SUBMIT YOUR SCORE:"
.byte $9B, $9B
.text "   NAME: "
.byte $9B, $9B
.text "HISCORE POWERED BY FUJINET"
.byte $9B
.text "   FUJINET.ONLINE"
.byte 0

FJHS_NAME_ENTRY:
    jsr is_score_zero
    bne !+
    rts
!:
    Print(FJHS_API_ENTER_MSG)
    DrawScore(16, 5)
    InputText2(FJHS_USER_NAME, 15, 15, 9, 1)
    jsr FJHS_API_SET_SCORE
    rts

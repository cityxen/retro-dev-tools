///////////////////////////////////////////////////////////////
// FujiNet Functions - Commodore VIC-20
// By Deadline / CityXen
//
// FujiNet connects via the VIC-20 IEC serial bus (same bus as
// disk drives, same KERNAL jump table as C64).
// FujiNet appears as a standard CBM serial device (default: 8).
// URL format for network files: FJ:HTTP://hostname/path
//
// KERNAL addresses match the C64 ($FF81-$FFF3 jump table).
// Note: VIC-20 has no hardware sprites (VIC-I chip only).
//
// Requires: sys.il.asm, print.il.asm, score.il.asm, input.il.asm

#importonce

.const FJ_KERNAL_SETNAM = $FFBD
.const FJ_KERNAL_SETLFS = $FFBA
.const FJ_KERNAL_OPEN   = $FFC0
.const FJ_KERNAL_CLOSE  = $FFC3
.const FJ_KERNAL_CHKIN  = $FFC6
.const FJ_KERNAL_CHRIN  = $FFCF
.const FJ_KERNAL_CLRCHN = $FFCC
.const FJ_KERNAL_LOAD   = $FFD5
.const FJ_KERNAL_READST = $FFB7

///////////////////////////////////////////////////////////////
// State variables

fj_drive_number: .byte 8
fj_detected:     .byte 0
fj_enabled:      .byte 1

fj_detected_text:
.encoding "petscii_mixed"
.text "fujinet found:"
.byte 0
fj_enabled_text:
.text "fujinet enabled:"
.byte 0

///////////////////////////////////////////////////////////////
// fj_detect_fujinet: open error channel on fj_drive_number,
//                    scan for "fujinet" in status string
fj_detect_byte:  .byte 0
fj_detect_check: .byte 0

fj_detect_cmd:
.encoding "petscii_mixed"
.text "i0:"
fj_detect_cmd_end:

fj_detect_fujinet:
    lda #0
    sta fj_detect_byte
    sta fj_detected
    sta fj_detect_check

    // Open error channel (file 15, secondary 15)
    lda #(fj_detect_cmd_end - fj_detect_cmd)
    ldx #<fj_detect_cmd
    ldy #>fj_detect_cmd
    jsr FJ_KERNAL_SETNAM
    lda #$0f
    ldx fj_drive_number
    ldy #$0f
    jsr FJ_KERNAL_SETLFS
    jsr FJ_KERNAL_OPEN

    // Re-open to read the status string
    lda #0
    ldx #0
    ldy #0
    jsr FJ_KERNAL_SETNAM
    lda #$0f
    ldx fj_drive_number
    ldy #$0f
    jsr FJ_KERNAL_SETLFS
    jsr FJ_KERNAL_OPEN
    bcs fj_det_close

    ldx #$0f
    jsr FJ_KERNAL_CHKIN
fj_det_loop:
    jsr FJ_KERNAL_READST
    bne fj_det_eof
    jsr FJ_KERNAL_CHRIN
    sta fj_detect_check
    inc fj_detect_byte
    lda fj_detect_byte
    cmp #$04
    bne fj_det_next
    lda fj_detect_check
    cmp #'f'                // "fujinet" begins at byte 4 of status
    bne fj_det_next
    lda #1
    sta fj_detected
fj_det_next:
    jmp fj_det_loop
fj_det_eof:
fj_det_close:
    lda #$0f
    jsr FJ_KERNAL_CLOSE
    jsr FJ_KERNAL_CLRCHN
    rts

///////////////////////////////////////////////////////////////
// Top-10 score table (loaded directly from FujiNet via KERNAL LOAD)
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
// URL tables — FJ: prefix routes through FujiNet firmware
.encoding "screencode_mixed"

FJHS_API_URL_ADD_SCORE:
.text "FJ:%WAD"
FJHS_API_URL_AS_RETS:   .text "?X="
FJHS_API_URL_AS_NUM:    .text "10"
                        .text "&S="
FJHS_API_URL_AS_SCORE:  .text "SSSSSSSSSS"
                        .text "&N="
FJHS_API_URL_AS_NAME:   .text "NNNNNNNNNNNNNNNN"
FJHS_API_URL_ADD_SCORE_LENGTH: .byte 0

FJHS_API_URL_GET_SCORE:
.text "FJ:%WAD"
.text "?X="
FJHS_API_URL_GS_NUM:    .text "10"
FJHS_API_URL_GET_SCORE_LENGTH: .byte 0

FJHS_USER_NAME: .text "NNNNNNNNNNNNNNNN"  .byte 0

FJHS_CALC_URL_LENS:
    lda #(FJHS_API_URL_GET_SCORE_LENGTH - FJHS_API_URL_GET_SCORE)
    sta FJHS_API_URL_GET_SCORE_LENGTH
    lda #(FJHS_API_URL_ADD_SCORE_LENGTH - FJHS_API_URL_ADD_SCORE)
    sta FJHS_API_URL_ADD_SCORE_LENGTH
    rts

///////////////////////////////////////////////////////////////
// fj_url_clear: reset score/name fields
fj_url_clear:
    lda #$20
    ldx #0
fjuc_name:
    sta FJHS_API_URL_AS_NAME, x
    inx
    cpx #16
    bne fjuc_name
    lda #$30
    ldx #0
fjuc_score:
    sta FJHS_API_URL_AS_SCORE, x
    inx
    cpx #10
    bne fjuc_score
    rts

///////////////////////////////////////////////////////////////
// FJHS_API_LOAD: internal — KERNAL LOAD a URL into memory
FJHS_API_LOAD:
    lda #$01
    ldx fj_drive_number
    ldy #$00
    jsr FJ_KERNAL_SETLFS
    lda #$00
    ldx #<FJHS_API_TOP_10_TABLE
    ldy #>FJHS_API_TOP_10_TABLE
    jsr FJ_KERNAL_LOAD
    rts

///////////////////////////////////////////////////////////////
// FJHS_API_GET_SCORE: fetch top-10 from FujiNet
FJHS_API_GET_SCORE:
    lda fj_enabled
    bne !+
    rts
!:
    jsr fj_url_clear
    lda FJHS_API_URL_GET_SCORE_LENGTH
    ldx #<FJHS_API_URL_GET_SCORE
    ldy #>FJHS_API_URL_GET_SCORE
    jsr FJ_KERNAL_SETNAM
    jmp FJHS_API_LOAD

///////////////////////////////////////////////////////////////
// FJHS_API_SET_SCORE: submit score+name to FujiNet
FJHS_API_SET_SCORE:
    lda fj_enabled
    bne !+
    rts
!:
    jsr fj_url_clear
    StrCpyL(score_str, FJHS_API_URL_AS_SCORE, 10)
    StrCpyL(FJHS_USER_NAME, FJHS_API_URL_AS_NAME, 15)
    lda FJHS_API_URL_ADD_SCORE_LENGTH
    ldx #<FJHS_API_URL_ADD_SCORE
    ldy #>FJHS_API_URL_ADD_SCORE
    jsr FJ_KERNAL_SETNAM
    jmp FJHS_API_LOAD

///////////////////////////////////////////////////////////////
// FJHS_DRAW: display top-10 scores
FJHS_NL:
.byte $0D,$11,$1D,$1D,$1D,$1D,$1D,$1D,$1D
.byte 0

FJHS_API_SCORE_MSG:
.encoding "petscii_mixed"
.byte $93, $05
.text "   -= fujinet hiscores =-"
.byte $0D, 0

FJHS_DRAW:
    jsr wait_vbl
    Print(FJHS_API_SCORE_MSG)
    Print(FJHS_NL)  PrintLeadingZerosAsSpaces(FJHS1a)   PrintChr($20)  Print(FJHS1b)
    Print(FJHS_NL)  PrintLeadingZerosAsSpaces(FJHS2a)   PrintChr($20)  Print(FJHS2b)
    Print(FJHS_NL)  PrintLeadingZerosAsSpaces(FJHS3a)   PrintChr($20)  Print(FJHS3b)
    Print(FJHS_NL)  PrintLeadingZerosAsSpaces(FJHS4a)   PrintChr($20)  Print(FJHS4b)
    Print(FJHS_NL)  PrintLeadingZerosAsSpaces(FJHS5a)   PrintChr($20)  Print(FJHS5b)
    Print(FJHS_NL)  PrintLeadingZerosAsSpaces(FJHS6a)   PrintChr($20)  Print(FJHS6b)
    Print(FJHS_NL)  PrintLeadingZerosAsSpaces(FJHS7a)   PrintChr($20)  Print(FJHS7b)
    Print(FJHS_NL)  PrintLeadingZerosAsSpaces(FJHS8a)   PrintChr($20)  Print(FJHS8b)
    Print(FJHS_NL)  PrintLeadingZerosAsSpaces(FJHS9a)   PrintChr($20)  Print(FJHS9b)
    Print(FJHS_NL)  PrintLeadingZerosAsSpaces(FJHS10a)  PrintChr($20)  Print(FJHS10b)
    rts

///////////////////////////////////////////////////////////////
// FJHS_NAME_ENTRY: game-over, name input, score submit
FJHS_API_ENTER_MSG:
.encoding "petscii_mixed"
.byte $93, $02
.text "   game over!"
.byte $0D,$0D
.text "   submit your score:"
.byte $0D,$0D
.text "   name: "
.byte $0D,$0D
.text "hiscore powered by fujinet"
.byte $0D
.text "   fujinet.online"
.byte 0

FJHS_NAME_ENTRY:
    jsr is_score_zero
    bne !+
    rts
!:
    Print(FJHS_API_ENTER_MSG)
    DrawScore(28, 7)
    InputText2(FJHS_USER_NAME, 15, 15, 9, 1)
    jsr FJHS_API_SET_SCORE
    rts

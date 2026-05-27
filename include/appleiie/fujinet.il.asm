///////////////////////////////////////////////////////////////
// FujiNet Functions - Apple IIe
// By Deadline / CityXen
//
// FujiNet on Apple IIe connects via SmartPort (slot-based).
// Network access uses the FujiNet N: SmartPort unit exposed
// as a block device.  Score data is fetched/submitted via
// ProDOS MLI reads from FujiNet-resolved paths.
//
// Requires: sys.il.asm, print.il.asm, disk.il.asm, score.il.asm, input.il.asm

#importonce

///////////////////////////////////////////////////////////////
// FujiNet SmartPort / ProDOS constants
// FujiNet appears as a ProDOS device; paths are case-insensitive.
// The device prefix "/FN/" routes through FujiNet firmware.
.const PRODOS_MLI  = $BF00
.const MLI_OPEN    = $C8
.const MLI_READ    = $CA
.const MLI_WRITE   = $CB
.const MLI_CLOSE   = $CC
.const MLI_QUIT    = $65

///////////////////////////////////////////////////////////////
// State variables

fj_detected:     .byte 0
fj_enabled:      .byte 1
fj_file_ref:     .byte 0

fj_detected_text:
.text "FUJINET FOUND"
.byte 0
fj_enabled_text:
.text "FUJINET ENABLED"
.byte 0

///////////////////////////////////////////////////////////////
// ProDOS I/O buffer (512 bytes required per open file)
fj_iobuf: .fill 512, 0

///////////////////////////////////////////////////////////////
// ProDOS parameter blocks

fj_pb_open:
    .byte 3
fj_pb_open_path:  .word fj_path_buf
fj_pb_open_iobuf: .word fj_iobuf
fj_pb_open_ref:   .byte 0

fj_pb_read:
    .byte 4
fj_pb_read_ref:    .byte 0
fj_pb_read_addr:   .word 0
fj_pb_read_req:    .word 0
fj_pb_read_trans:  .word 0

fj_pb_close:
    .byte 1
fj_pb_close_ref:  .byte 0

///////////////////////////////////////////////////////////////
// Path buffer — ProDOS pathname, FujiNet-routed
// FujiNet firmware maps /N/ to its network stack
fj_path_buf: .fill 65, 0

fj_probe_path:
.text "/N/TCP/localhost/0"
fj_probe_path_end:

///////////////////////////////////////////////////////////////
// fj_set_path: copy null-terminated string from A(lo)/Y(hi) into fj_path_buf
fj_set_path_src: .word 0

fj_set_path:
    sta fj_set_path_src
    sty fj_set_path_src+1
    ldy #0
fsp_loop:
    lda (fj_set_path_src), y
    sta fj_path_buf, y
    beq fsp_done
    iny
    cpy #64
    bne fsp_loop
    stz fj_path_buf+64
fsp_done:
    rts

///////////////////////////////////////////////////////////////
// fj_detect_fujinet: attempt ProDOS OPEN on probe path; set fj_detected
fj_detect_fujinet:
    lda #0
    sta fj_detected

    lda #<fj_probe_path
    ldy #>fj_probe_path
    jsr fj_set_path

    jsr PRODOS_MLI
    .byte MLI_OPEN
    .word fj_pb_open
    bcs fj_detect_done      // carry set = error

    lda #1
    sta fj_detected

    lda fj_pb_open_ref
    sta fj_pb_close_ref
    jsr PRODOS_MLI
    .byte MLI_CLOSE
    .word fj_pb_close
fj_detect_done:
    rts

///////////////////////////////////////////////////////////////
// Top-10 score table
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
// URL / path tables — FujiNet-routed ProDOS paths

FJHS_PATH_GET_SCORE:
.text "/N/HTTP/scores.cityxen.com/WAD?X=10"
FJHS_PATH_GET_SCORE_END:

FJHS_PATH_ADD_SCORE:
.text "/N/HTTP/scores.cityxen.com/WAD?X=10&S="
FJHS_PATH_AS_SCORE: .text "SSSSSSSSSS"
                    .text "&N="
FJHS_PATH_AS_NAME:  .text "NNNNNNNNNNNNNNNN"
FJHS_PATH_ADD_SCORE_END:

FJHS_USER_NAME: .text "NNNNNNNNNNNNNNNN"  .byte 0

///////////////////////////////////////////////////////////////
// fj_url_clear: reset score/name fields in add-score path
fj_url_clear:
    lda #$20
    ldx #0
fjuc_name:
    sta FJHS_PATH_AS_NAME, x
    inx
    cpx #16
    bne fjuc_name
    lda #'0'
    ldx #0
fjuc_score:
    sta FJHS_PATH_AS_SCORE, x
    inx
    cpx #10
    bne fjuc_score
    rts

///////////////////////////////////////////////////////////////
// fj_load_path: open fj_path_buf, read into dest, close
fj_load_dest: .word 0
fj_load_size: .word 0

fj_load_path:
    jsr PRODOS_MLI
    .byte MLI_OPEN
    .word fj_pb_open
    bcs fjlp_done

    lda fj_pb_open_ref
    sta fj_pb_read_ref
    sta fj_pb_close_ref

    lda fj_load_dest
    sta fj_pb_read_addr
    lda fj_load_dest+1
    sta fj_pb_read_addr+1
    lda fj_load_size
    sta fj_pb_read_req
    lda fj_load_size+1
    sta fj_pb_read_req+1

    jsr PRODOS_MLI
    .byte MLI_READ
    .word fj_pb_read

    jsr PRODOS_MLI
    .byte MLI_CLOSE
    .word fj_pb_close
fjlp_done:
    rts

///////////////////////////////////////////////////////////////
// FJHS_API_GET_SCORE: fetch top-10 from FujiNet
FJHS_API_GET_SCORE:
    lda fj_enabled
    bne !+
    rts
!:
    jsr fj_url_clear
    lda #<FJHS_PATH_GET_SCORE
    ldy #>FJHS_PATH_GET_SCORE
    jsr fj_set_path
    lda #<FJHS_API_TOP_10_TABLE
    sta fj_load_dest
    lda #>FJHS_API_TOP_10_TABLE
    sta fj_load_dest+1
    lda #<(FJHS10b + 17 - FJHS_API_TOP_10_TABLE)
    sta fj_load_size
    lda #>(FJHS10b + 17 - FJHS_API_TOP_10_TABLE)
    sta fj_load_size+1
    jmp fj_load_path

///////////////////////////////////////////////////////////////
// FJHS_API_SET_SCORE: submit score and name to FujiNet
FJHS_API_SET_SCORE:
    lda fj_enabled
    bne !+
    rts
!:
    jsr fj_url_clear
    StrCpyL(score_str, FJHS_PATH_AS_SCORE, 10)
    StrCpyL(FJHS_USER_NAME, FJHS_PATH_AS_NAME, 15)
    lda #<FJHS_PATH_ADD_SCORE
    ldy #>FJHS_PATH_ADD_SCORE
    jsr fj_set_path
    lda #<FJHS_API_TOP_10_TABLE
    sta fj_load_dest
    lda #>FJHS_API_TOP_10_TABLE
    sta fj_load_dest+1
    lda #<(FJHS10b + 17 - FJHS_API_TOP_10_TABLE)
    sta fj_load_size
    lda #>(FJHS10b + 17 - FJHS_API_TOP_10_TABLE)
    sta fj_load_size+1
    jmp fj_load_path

///////////////////////////////////////////////////////////////
// FJHS_DRAW: display top-10 scores
FJHS_NL: .byte $0D, 0

FJHS_API_SCORE_MSG:
.text "   -= FUJINET HISCORES =-"
.byte $0D, 0

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
// FJHS_NAME_ENTRY: game-over, name input, score submit
FJHS_API_ENTER_MSG:
.byte $0C                   // form feed (clear screen)
.text "   GAME OVER!"
.byte $0D,$0D
.text "   SUBMIT YOUR SCORE:"
.byte $0D,$0D
.text "   NAME: "
.byte $0D,$0D
.text "HISCORE POWERED BY FUJINET"
.byte $0D
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

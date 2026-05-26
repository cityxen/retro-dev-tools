///////////////////////////////////////////////////////////////
// CITYXEN COMMODORE 128 LIBRARY
// Meatloaf Functions
// By Deadline / CityXen
//
// https://github.com/cityxen/Commodore128_Programming
//
// https://linktr.ee/cityxen
//
ml_drive_number: .byte 8
ml_detect_cmd:
.encoding "petscii_mixed"
.text "i0:"     // command string
ml_detect_cmd_end:
ml_detect_byte:  .byte 0
ml_detect_check: .byte 0
ml_detected:     .byte 0
ml_enabled:      .byte 0
ml_detected_text: .text "meatloaf found:"
.byte 0
ml_enabled_text:  .text "meatloaf enabled:"
.byte 0
ml_detect_meatloaf:
        lda #$00
        sta ml_detect_byte
        sta ml_detected
        sta ml_detect_check
        lda #ml_detect_cmd_end-ml_detect_cmd
        ldx #<ml_detect_cmd
        ldy #>ml_detect_cmd
        jsr KERNAL_SETNAM
        lda #$0F      // file number 15
        ldx ml_drive_number
ml_i_skip:
        ldy #$0F      // secondary address 15
        jsr KERNAL_SETLFS
        jsr KERNAL_OPEN
ml_i_close:
        lda #$0F      // filenumber 15
        jsr KERNAL_CLOSE
        jsr KERNAL_CLRCHN
ml_show_drive_status:
        lda #$00      // no filename
        ldx #$00
        ldy #$00
        jsr KERNAL_SETNAM
        lda #$0F
        ldx ml_drive_number
ml_sdsskip:
        ldy #$0F      // secondary address 15 (error channel)
        jsr KERNAL_SETLFS
        jsr KERNAL_OPEN
        bcs ml_sdserror  // if carry set, the file could not be opened
        ldx #$0F      // filenumber 15
        jsr KERNAL_CHKIN
ml_sdsloop:
        jsr KERNAL_READST
        bne ml_sdseof    // either eof or read error
        jsr KERNAL_CHRIN
        sta ml_detect_check
        inc ml_detect_byte
        lda ml_detect_byte
        cmp #$04
        bne !+
        lda ml_detect_check
        cmp #'m'
        bne !+
        lda #$01
        sta ml_detected
!:
        jmp ml_sdsloop   // next byte
ml_sdseof:
ml_sdsclose:
        lda #$0F      // filenumber 15
        jsr KERNAL_CLOSE
        jsr KERNAL_CLRCHN
        rts
ml_sdserror:
        // accumulator contains basic error code, most likely error: a = $05 (device not present)
        jmp ml_sdsclose

//////////////////////////////////////////////////////////////////////////////////////
// CityXen - https://linktr.ee/cityxen
//////////////////////////////////////////////////////////////////////////////////////
// Deadline's Commodore PET Assembly Language Library:
// Disk / File I/O
// Target: Commodore PET 4032 (BASIC 4.0, MOS 6502)
//
// Uses the standard Kernal file API ($FF81-$FFF3) which is compatible
// across PET and C64.  The IEEE-488 disk bus (CBM 4040/8050/etc.) is
// accessed via KERNAL_LISTEN/TALK/SETLFS/SETNAM/OPEN/CLOSE/LOAD/SAVE.
//////////////////////////////////////////////////////////////////////////////////////

#importonce

.const zp_pointer_lo = $fb
.const zp_pointer_hi = $fc

device_not_present_text:
    .encoding "petscii_mixed"
    .text "DEVICE NOT PRESENT"
    .byte $0d
    .byte 0

drive_number_text:
    .text "0809101112131415161718192021222324252627282930"
drive_number:
    .byte 8

filename_length: .byte 255
filename:
filename_buffer:
    .fill 256, 0

use_file_loc: .byte 0
sec_command:  .byte 1       // 0 = load to file address, 1 = load to specified address

file_loc:
file_loc_lo:  .byte 0
file_loc_hi:  .byte 0

file_loc_end:
file_loc_end_lo: .byte 0
file_loc_end_hi: .byte 0

file_size:
file_size_hi: .byte 0
file_size_lo: .byte 0

load_address_end:
load_address_end_lo: .byte 0
load_address_end_hi: .byte 0

.const LOAD_ADDRESS_HI = $c2
.const LOAD_ADDRESS_LO = $c1

//////////////////////////////////////////////////////////////////////////////////////
// zeroize_filename_buffer

zeroize_filename_buffer:
    lda #$00
    ldx #$00
zfb_loop:
    sta filename_buffer, x
    inx
    bne zfb_loop
    rts

//////////////////////////////////////////////////////////////////////////////////////
// load_file — load a file using Kernal LOAD

load_file:
    lda filename_length
    ldx #<filename_buffer
    ldy #>filename_buffer
    jsr KERNAL_SETNAM
    lda #$01
    ldx drive_number
    ldy sec_command
    jsr KERNAL_SETLFS
    lda #00
    ldx file_loc_lo
    ldy file_loc_hi
    jsr KERNAL_LOAD
    txa
    sta load_address_end_lo
    tya
    sta load_address_end_hi
    sec
    lda load_address_end_lo
    sbc file_loc_lo
    sta file_size_lo
    lda load_address_end_hi
    sbc file_loc_hi
    sta file_size_hi
    rts

//////////////////////////////////////////////////////////////////////////////////////
// save_file — save a memory range using Kernal SAVE

save_file:
    lda filename_length
    ldx #<filename
    ldy #>filename
    jsr KERNAL_SETNAM
    lda #$01
    ldx drive_number
    ldy sec_command
    jsr KERNAL_SETLFS
    lda #<file_loc
    sta zp_pointer_lo
    lda #>file_loc
    sta zp_pointer_hi
    ldx #<file_loc_end
    ldy #>file_loc_end
    lda #<zp_pointer_lo
    jsr KERNAL_SAVE
    lda #$01
    jsr KERNAL_CLOSE
    rts

//////////////////////////////////////////////////////////////////////////////////////
// show_drive_status — read and print error channel from drive

show_drive_status:
    lda #$00
    ldx #$00
    ldy #$00
    jsr KERNAL_SETNAM

    lda #$0f            // file number 15
    ldx drive_number
    bne sds_skip
    ldx #$08            // default device 8
sds_skip:
    ldy #$0f            // secondary address 15 (error channel)
    jsr KERNAL_SETLFS
    jsr KERNAL_OPEN
    bcs sds_error

    ldx #$0f
    jsr KERNAL_CHKIN

sds_loop:
    jsr KERNAL_READST
    bne sds_eof
    jsr KERNAL_CHRIN
    jsr KERNAL_CHROUT
    jmp sds_loop

sds_eof:
sds_close:
    lda #$0f
    jsr KERNAL_CLOSE
    jsr KERNAL_CLRCHN
    rts

sds_error:
    jmp sds_close

//////////////////////////////////////////////////////////////////////////////////////
// show_directory — list disk directory

show_directory:
    sta dir_pause
    ClearScreen()
    lda #dirname_end - dirname
    ldx #<dirname
    ldy #>dirname
    jsr KERNAL_SETNAM
    lda #$02
    ldx drive_number
    ldy #$00
    jsr KERNAL_SETLFS
    jsr KERNAL_OPEN
    bcs sdir_error
    ldx #$02
    jsr KERNAL_CHKIN
    ldy #$04
    jmp sdir_skip2
sdir_next:
    ldy #$02
sdir_skip2:
    jsr sdir_getbyte
    dey
    bne sdir_skip2
    jsr sdir_getbyte
    tay
    jsr sdir_getbyte
    pha
    tya
    tax
    pla
    jsr KERNAL_CHROUT  // simple line number print
    lda #$20
sdir_char:
    jsr KERNAL_CHROUT
    jsr sdir_getbyte
    bne sdir_char
    lda #$0d
    jsr KERNAL_CHROUT
    jsr KERNAL_STOP
    bne sdir_next
sdir_error:
sdir_exit:
    lda #$02
    jsr KERNAL_CLOSE
    jsr KERNAL_CLRCHN
    lda #$0d
    jsr KERNAL_CHROUT
    jsr show_drive_status
    lda dir_pause
    beq sdir_done
    jsr KERNAL_GETIN
    beq sdir_waitkey
sdir_waitkey:
    jsr KERNAL_GETIN
    beq sdir_waitkey
sdir_done:
    rts

sdir_getbyte:
    jsr KERNAL_READST
    bne sdir_end
    jmp KERNAL_CHRIN
sdir_end:
    pla
    pla
    jmp sdir_exit

dirname: .text "$"
dirname_end:
dir_pause: .byte 0

//////////////////////////////////////////////////////////////////////////////////////
// Macros

.macro ClearFileLocation() {
    lda #$00
    sta sec_command
    lda #$ff
    sta file_loc_lo
    sta file_loc_hi
}

.macro SetFileLocation(in_file_loc) {
    lda #$01
    sta sec_command
    lda in_file_loc
    sta file_loc_lo
    lda in_file_loc+1
    sta file_loc_hi
}

.macro SetFileLocationEnd(in_file_loc_end) {
    lda in_file_loc_end
    sta file_loc_end_lo
    lda in_file_loc_end+1
    sta file_loc_end_hi
}

.macro SetFileName(infilename) {
    jsr zeroize_filename_buffer
    ldx #$00
sfn_loop:
    lda infilename, x
    beq sfn_done
    sta filename_buffer, x
    inx
    jmp sfn_loop
sfn_done:
    stx filename_length
    lda #$00
    sta filename_buffer, x
}

.macro KeyFileLoad(key, file, loc) {
    cmp #key
    bne kfl_skip
    SetFileName(file)
    lda #<loc
    sta file_loc_lo
    lda #>loc
    sta file_loc_hi
    jsr load_file
    jmp main_loop
kfl_skip:
}

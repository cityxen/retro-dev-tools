#importonce
//////////////////////////////////////////////////////////////////
// CITYXEN ATARI 800XL LIBRARY — RLE Compress / Decompress
//
// https://github.com/cityxen/Atari_8Bit_Programming
// https://linktr.ee/cityxen
//
// Hardware-independent; identical algorithm to the C64 version.
//
// USAGE — Compress:
//   RLE_SetSrc(my_data)
//   RLE_SetSrcEnd(my_data + my_data_length)
//   RLE_SetDest(my_output_buffer)
//   jsr rle_compress
//
// USAGE — Decompress:
//   RLE_SetSrc(my_compressed_data)
//   RLE_SetDest(my_output_buffer)
//   jsr rle_decompress
//
// ZP used: $F7-$FE  (safe user area $80-$FF on Atari)
//////////////////////////////////////////////////////////////////

.const zp_rle_src   = $F7   // source pointer
.const zp_rle_dst   = $F9   // destination pointer
.const zp_rle_start = $FB   // remembers start of output (compress)
.const zp_rle_end   = $FD   // computed end of output (compress)

rle_data_size_lo:   .byte 0
rle_data_size_hi:   .byte 0
rle_src_end_lo:     .byte 0
rle_src_end_hi:     .byte 0
rle_count:          .byte 0
rle_byte:           .byte 0

// Macros ─────────────────────────────────────────────────────

.macro RLE_SetSrc(addr) {
    lda #<addr
    sta zp_rle_src
    lda #>addr
    sta zp_rle_src+1
}

.macro RLE_SetSrcEnd(addr) {
    lda #<addr
    sta rle_src_end_lo
    lda #>addr
    sta rle_src_end_hi
}

.macro RLE_SetDest(addr) {
    lda #<addr
    sta zp_rle_dst
    lda #>addr
    sta zp_rle_dst+1
}

// rle_inc_size ────────────────────────────────────────────────
rle_inc_size:
    inc rle_data_size_lo
    bne !+
    inc rle_data_size_hi
!:
    rts

// rle_compress ────────────────────────────────────────────────
rle_compress:
    lda zp_rle_dst
    sta zp_rle_start
    lda zp_rle_dst+1
    sta zp_rle_start+1
    lda #0
    sta rle_data_size_lo
    sta rle_data_size_hi
    sta rle_count
    ldy #0
    lda (zp_rle_src),y
    sta rle_byte
    inc rle_count
    inc zp_rle_src
    bne rc_loop
    inc zp_rle_src+1

rc_loop:
    lda (zp_rle_src),y
    cmp rle_byte
    bne rc_diff
rc_same:
    lda rle_count
    cmp #255
    bne rc_next
rc_diff:
    lda rle_count
    sta (zp_rle_dst),y
    jsr rle_inc_size
    lda rle_byte
    iny
    sta (zp_rle_dst),y
    jsr rle_inc_size
    dey
    lda (zp_rle_src),y
    sta rle_byte
    lda #0
    sta rle_count
    clc
    lda zp_rle_dst
    adc #2
    sta zp_rle_dst
    bcc rc_next
    inc zp_rle_dst+1
rc_next:
    inc rle_count
    inc zp_rle_src
    bne !+
    inc zp_rle_src+1
!:
    lda zp_rle_src+1
    cmp rle_src_end_hi
    bcc rc_loop
    bne rc_done
    lda zp_rle_src
    cmp rle_src_end_lo
    bcc rc_loop
rc_done:
    lda rle_count
    beq !+
    sta (zp_rle_dst),y
    jsr rle_inc_size
    iny
    lda rle_byte
    sta (zp_rle_dst),y
    jsr rle_inc_size
    iny
    lda #0
    sta (zp_rle_dst),y
    jsr rle_inc_size
    iny
    sta (zp_rle_dst),y
    jsr rle_inc_size
!:
    lda rle_data_size_lo
    clc
    adc zp_rle_start
    sta zp_rle_end
    lda rle_data_size_hi
    adc zp_rle_start+1
    sta zp_rle_end+1
    rts

// rle_decompress ──────────────────────────────────────────────
rle_decompress:
    ldy #0
    lda (zp_rle_src),y
    beq rd_done
    tax
    pha
    iny
    lda (zp_rle_src),y
    dey
rd_fill:
    sta (zp_rle_dst),y
    iny
    dex
    bne rd_fill
    pla
    clc
    adc zp_rle_dst
    sta zp_rle_dst
    bcc !+
    inc zp_rle_dst+1
!:
    lda zp_rle_src
    clc
    adc #2
    sta zp_rle_src
    bcc !+
    inc zp_rle_src+1
!:
    jmp rle_decompress
rd_done:
    rts

//////////////////////////////////////////////////////////////////

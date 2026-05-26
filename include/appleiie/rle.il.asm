#importonce
//===========================================================================
// CityXen Apple IIe Library - RLE Compression / Decompression
//
// Run-Length Encoding format (same as C64 port, hardware-independent):
//   Compressed stream: pairs of (count_byte, data_byte)
//   count_byte=0, data_byte=0  -> end of stream
//   count_byte=1               -> single occurrence of data_byte
//   count_byte=N (2-255)       -> N occurrences of data_byte
//
// Usage:
//   Set RLE_SetSrc / RLE_SetSrcEnd / RLE_SetDest macros, then:
//     jsr rle_compress    (src -> dest in RLE format)
//     jsr rle_decompress  (RLE src -> raw dest)
//===========================================================================

// Working state
rle_src:        .word 0     // source start address (lo/hi)
rle_src_end:    .word 0     // source end address (exclusive)
rle_dest:       .word 0     // destination address
rle_data_size:  .word 0     // size of decompressed data (output from compress)
rle_count:      .byte 0     // current run count
rle_byte:       .byte 0     // current run byte

// Zero-page working pointers (borrow from ZP_PTR0/PTR1 during RLE ops)
.const RLE_SRC_PTR  = ZP_PTR0
.const RLE_DST_PTR  = ZP_PTR1

//---------------------------------------------------------------------------
// Macros
//---------------------------------------------------------------------------
.macro RLE_SetSrc(src_addr) {
    lda #<src_addr
    sta rle_src
    lda #>src_addr
    sta rle_src + 1
}

.macro RLE_SetSrcEnd(src_end_addr) {
    lda #<src_end_addr
    sta rle_src_end
    lda #>src_end_addr
    sta rle_src_end + 1
}

.macro RLE_SetDest(dest_addr) {
    lda #<dest_addr
    sta rle_dest
    lda #>dest_addr
    sta rle_dest + 1
}

//---------------------------------------------------------------------------
// rle_decompress - Expand RLE stream from rle_src to rle_dest
//   Reads (count, byte) pairs until (0, 0) terminator.
//   Trashes: A, X, Y, RLE_SRC_PTR, RLE_DST_PTR
//---------------------------------------------------------------------------
rle_decompress:
    lda rle_src
    sta RLE_SRC_PTR
    lda rle_src + 1
    sta RLE_SRC_PTR + 1
    lda rle_dest
    sta RLE_DST_PTR
    lda rle_dest + 1
    sta RLE_DST_PTR + 1
    ldy #0
rld_pair:
    lda (RLE_SRC_PTR), y    // read count byte
    sta rle_count
    iny
    lda (RLE_SRC_PTR), y    // read data byte
    sta rle_byte
    iny

    // Check for end-of-stream (0, 0)
    lda rle_count
    bne rld_emit
    lda rle_byte
    beq rld_done

rld_emit:
    // Advance source pointer if Y crossed page boundary
    tya
    clc
    adc RLE_SRC_PTR
    sta RLE_SRC_PTR
    bcc rld_no_carry_s
    inc RLE_SRC_PTR + 1
rld_no_carry_s:
    ldy #0

    // Emit rle_count copies of rle_byte to destination
    ldx rle_count
    lda rle_byte
rld_fill:
    sta (RLE_DST_PTR), y
    iny
    bne rld_no_carry_d
    inc RLE_DST_PTR + 1
rld_no_carry_d:
    dex
    bne rld_fill

    // Flush Y into DST_PTR
    tya
    clc
    adc RLE_DST_PTR
    sta RLE_DST_PTR
    bcc rld_next
    inc RLE_DST_PTR + 1
rld_next:
    ldy #0
    jmp rld_pair

rld_done:
    rts

//---------------------------------------------------------------------------
// rle_compress - Compress raw data from rle_src..rle_src_end to rle_dest
//   Output: RLE pairs in dest; updates rle_data_size with compressed size.
//   Trashes: A, X, Y, RLE_SRC_PTR, RLE_DST_PTR, rle_count, rle_byte
//---------------------------------------------------------------------------
rle_compress:
    lda rle_src
    sta RLE_SRC_PTR
    lda rle_src + 1
    sta RLE_SRC_PTR + 1
    lda rle_dest
    sta RLE_DST_PTR
    lda rle_dest + 1
    sta RLE_DST_PTR + 1

    ldy #0                  // source index
    lda #0
    sta rle_data_size
    sta rle_data_size + 1

rlc_next:
    // Check if source exhausted
    lda RLE_SRC_PTR
    cmp rle_src_end
    bne rlc_read
    lda RLE_SRC_PTR + 1
    cmp rle_src_end + 1
    beq rlc_term

rlc_read:
    lda (RLE_SRC_PTR), y    // read first byte of run
    sta rle_byte
    lda #1
    sta rle_count

    // Advance source
    inc RLE_SRC_PTR
    bne rlc_adv_ok
    inc RLE_SRC_PTR + 1
rlc_adv_ok:

    // Count run length (max 255)
rlc_run:
    lda RLE_SRC_PTR
    cmp rle_src_end
    bne rlc_run_check
    lda RLE_SRC_PTR + 1
    cmp rle_src_end + 1
    beq rlc_emit

rlc_run_check:
    lda (RLE_SRC_PTR), y    // peek next byte (y=0)
    cmp rle_byte
    bne rlc_emit
    lda rle_count
    cmp #255
    beq rlc_emit
    inc rle_count
    inc RLE_SRC_PTR
    bne rlc_run
    inc RLE_SRC_PTR + 1
    bra rlc_run

rlc_emit:
    // Write (count, byte) pair to destination
    lda rle_count
    sta (RLE_DST_PTR), y
    iny
    lda rle_byte
    sta (RLE_DST_PTR), y
    iny
    // Advance dest pointer if needed
    tya
    clc
    adc RLE_DST_PTR
    sta RLE_DST_PTR
    bcc rlc_emit_ok
    inc RLE_DST_PTR + 1
rlc_emit_ok:
    ldy #0
    // Update size count
    clc
    lda rle_data_size
    adc #2
    sta rle_data_size
    bcc rlc_next
    inc rle_data_size + 1
    bra rlc_next

rlc_term:
    // Write (0, 0) end marker — stz (zp),y is invalid on 65C02, use sta
    lda #0
    sta (RLE_DST_PTR), y
    iny
    sta (RLE_DST_PTR), y
    rts

//===========================================================================

///////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE VIC-20 LIBRARY — RLE Compress / Decompress
//
// https://github.com/cityxen/CommodoreVIC20_Programming
// https://linktr.ee/cityxen
//
// Platform-independent — identical to C64 version.
//
// USAGE:
//
//// Compress:
//    RLE_SetSrc(my_data)
//    RLE_SetSrcEnd(my_data + my_data_length)
//    RLE_SetDest(my_output_buffer)
//    jsr rle_compress
//
//// Decompress:
//    RLE_SetSrc(my_compressed_data)
//    RLE_SetDest(my_output_buffer)
//    jsr rle_decompress
//
///////////////////////////////////////////////////////////////////

#importonce

.const zp_src       = $f7
.const zp_rle_start = $f9
.const zp_dest      = $fb
.const zp_rle_end   = $fd

rle_data_size:
rle_data_size_lo: .byte $00
rle_data_size_hi: .byte $00

rle_src_end_lo: .byte $00
rle_src_end_hi: .byte $00

rle_count: .byte $00
rle_byte:  .byte $00
rle_data:  .byte $00, $30

rle_set_dest:
  stx zp_dest
  sty zp_dest+1
  rts

rle_set_src:
  stx zp_src
  sty zp_src+1
  rts

inc_rle_data_size:
  inc rle_data_size_lo
  bne !+
  inc rle_data_size_hi
!:
  rts

rle_compress:
  lda zp_dest
  sta zp_rle_start
  lda zp_dest+1
  sta zp_rle_start+1
  lda #$00
  sta rle_data_size_lo
  sta rle_data_size_hi
  sta rle_count
  ldy #$00
  lda (zp_src),y
  sta rle_byte
  inc rle_count
  inc zp_src
  bne !+
  inc zp_src+1
!:
gr_loop:
  lda (zp_src),y
  cmp rle_byte
  bne gr_diff
gr_same:
  lda rle_count
  cmp #255
  bne gr_next
gr_diff:
  lda rle_count
  sta (zp_dest),y
  jsr inc_rle_data_size
  lda rle_byte
  iny
  sta (zp_dest),y
  jsr inc_rle_data_size
  dey
  lda (zp_src),y
  sta rle_byte
  lda #0
  sta rle_count
  clc
  lda zp_dest
  adc #2
  sta zp_dest
  bcc gr_next
  inc zp_dest+1
gr_next:
  inc rle_count
  inc zp_src
  bne !+
  inc zp_src+1
!:
  lda zp_src+1
  cmp rle_src_end_hi
  bcc gr_loop
  bne gr_done
  lda zp_src
  cmp rle_src_end_lo
  bcc gr_loop
gr_done:
  lda rle_count
  beq !+
  sta (zp_dest),y
  jsr inc_rle_data_size
  iny
  lda rle_byte
  sta (zp_dest),y
  jsr inc_rle_data_size
  iny
  lda #0
  sta (zp_dest),y
  jsr inc_rle_data_size
  iny
  sta (zp_dest),y
  jsr inc_rle_data_size
!:
  lda rle_data_size
  clc
  adc zp_rle_start
  sta zp_rle_end
  lda rle_data_size+1
  adc zp_rle_start+1
  sta zp_rle_end+1
  rts

rle_decompress:
rd1:
  ldy #0
  lda (zp_src),y
  beq rd2
  tax
  pha
  iny
  lda (zp_src),y
  dey
!:
  sta (zp_dest),y
  iny
  dex
  bne !-
  pla
  clc
  adc zp_dest
  sta zp_dest
  bcc !+
  inc zp_dest+1
!:
  lda zp_src
  clc
  adc #2
  sta zp_src
  bcc !+
  inc zp_src+1
!:
  jmp rd1
rd2:
  rts

.macro RLE_SetSrc(num) {
    lda #<num
    sta zp_src
    lda #>num
    sta zp_src+1
}

.macro RLE_SetSrcEnd(num) {
    lda #<num
    sta rle_src_end_lo
    lda #>num
    sta rle_src_end_hi
}

.macro RLE_SetDest(num) {
    lda num
    sta zp_dest
    lda num+1
    sta zp_dest+1
}

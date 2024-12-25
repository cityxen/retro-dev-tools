a_reg:  .byte 0
x_reg:  .byte 0
y_reg:  .byte 0
tmp_1:  .byte 0
tmp_2:  .byte 0
tmp_3:  .byte 0

wait_vbl:
    lda VIC_RASTER_COUNTER
    bne wait_vbl
    rts
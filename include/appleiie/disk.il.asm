#importonce
//===========================================================================
// CityXen Apple IIe Library - Disk / File I/O (ProDOS MLI)
//
// Provides high-level wrappers around ProDOS MLI calls.
// All filenames are ProDOS pathnames: null-terminated ASCII, up to 64 chars.
// MLI calls follow the convention:
//   jsr PRODOS_MLI
//   .byte command_code
//   .word parameter_block_address
// Returns with carry set on error; error code in A.
//===========================================================================

// Working storage
disk_filename:      .fill 65, 0     // pathname buffer (64 chars + null)
disk_drive_num:     .byte 0         // device/unit number (ProDOS format)
disk_file_ref:      .byte 0         // open file reference number
disk_io_buffer:     .word 0         // address of 512-byte I/O buffer
disk_load_addr:     .word 0         // address to load data into
disk_data_size:     .word 0         // number of bytes to read/write
disk_last_error:    .byte 0         // last MLI error code

// ProDOS requires a 512-byte I/O buffer for each open file.
// Reserve one here; your program may redirect disk_io_buffer to a custom one.
disk_default_buf:   .fill 512, 0

//---------------------------------------------------------------------------
// MLI Parameter Blocks (inline, filled by subroutines)
//---------------------------------------------------------------------------

// OPEN parameter block
pb_open:
    .byte 3                 // param count
pb_open_path:
    .word disk_filename     // pointer to pathname
pb_open_iobuf:
    .word disk_default_buf  // pointer to 512-byte I/O buffer
pb_open_ref:
    .byte 0                 // receives file reference number (output)

// READ parameter block
pb_read:
    .byte 4
pb_read_ref:
    .byte 0                 // file reference number
pb_read_addr:
    .word 0                 // data buffer address
pb_read_reqcount:
    .word 0                 // requested byte count
pb_read_transcount:
    .word 0                 // actual bytes transferred (output)

// WRITE parameter block
pb_write:
    .byte 4
pb_write_ref:
    .byte 0
pb_write_addr:
    .word 0
pb_write_reqcount:
    .word 0
pb_write_transcount:
    .word 0                 // actual bytes written (output)

// CLOSE parameter block
pb_close:
    .byte 1
pb_close_ref:
    .byte 0

// GET_FILE_INFO parameter block
pb_getinfo:
    .byte 10
pb_getinfo_path:
    .word disk_filename
pb_getinfo_access:
    .byte 0                 // access flags (output)
pb_getinfo_ftype:
    .byte 0                 // file type (output)
pb_getinfo_auxtype:
    .word 0                 // aux type / load addr (output)
pb_getinfo_storage:
    .byte 0                 // storage type (output)
pb_getinfo_blocks:
    .word 0                 // blocks used (output)
pb_getinfo_moddate:
    .word 0
pb_getinfo_modtime:
    .word 0
pb_getinfo_createdate:
    .word 0
pb_getinfo_createtime:
    .word 0

//---------------------------------------------------------------------------
// Macros
//---------------------------------------------------------------------------

.macro ClearFileName() {
    ldx #0
cfn_loop:
    stz disk_filename, x
    inx
    cpx #65
    bne cfn_loop
}

.macro SetFileName(src_addr) {
    lda #<src_addr
    sta ZP_PTR0
    lda #>src_addr
    sta ZP_PTR0 + 1
    jsr disk_copy_filename
}

.macro KeyFileLoad(key_char, filename_addr) {
    lda #key_char
    cmp ZP_TMP1             // compare against last key stored by input routine
    bne kfl_skip
    SetFileName(filename_addr)
    jsr disk_load_file
kfl_skip:
}

//---------------------------------------------------------------------------
// disk_copy_filename - Copy null-terminated string from ZP_PTR0 to disk_filename
//---------------------------------------------------------------------------
disk_copy_filename:
    ldy #0
dcf_loop:
    lda (ZP_PTR0), y
    sta disk_filename, y
    beq dcf_done
    iny
    cpy #64
    bne dcf_loop
    stz disk_filename + 64
dcf_done:
    rts

//---------------------------------------------------------------------------
// disk_open_file - Open the file named in disk_filename
//   On success: carry clear, disk_file_ref = reference number
//   On error:   carry set,  disk_last_error = error code
//---------------------------------------------------------------------------
disk_open_file:
    jsr PRODOS_MLI
    .byte MLI_OPEN
    .word pb_open
    bcs dof_err
    lda pb_open_ref
    sta disk_file_ref
    sta pb_read_ref
    sta pb_write_ref
    sta pb_close_ref
    clc
    rts
dof_err:
    sta disk_last_error
    rts

//---------------------------------------------------------------------------
// disk_close_file - Close the currently open file (disk_file_ref)
//---------------------------------------------------------------------------
disk_close_file:
    lda disk_file_ref
    sta pb_close_ref
    jsr PRODOS_MLI
    .byte MLI_CLOSE
    .word pb_close
    bcs dcl_err
    stz disk_file_ref
    clc
    rts
dcl_err:
    sta disk_last_error
    rts

//---------------------------------------------------------------------------
// disk_load_file - Open, read disk_data_size bytes to disk_load_addr, close
//   Caller sets: disk_filename, disk_load_addr, disk_data_size
//---------------------------------------------------------------------------
disk_load_file:
    jsr disk_open_file
    bcs dlf_done

    lda disk_load_addr
    sta pb_read_addr
    lda disk_load_addr + 1
    sta pb_read_addr + 1
    lda disk_data_size
    sta pb_read_reqcount
    lda disk_data_size + 1
    sta pb_read_reqcount + 1

    lda disk_file_ref
    sta pb_read_ref
    jsr PRODOS_MLI
    .byte MLI_READ
    .word pb_read
    bcs dlf_err

    jsr disk_close_file
    clc
    rts
dlf_err:
    sta disk_last_error
    pha
    jsr disk_close_file
    pla
    sec
dlf_done:
    rts

//---------------------------------------------------------------------------
// disk_save_file - Open, write disk_data_size bytes from disk_load_addr, close
//   Caller sets: disk_filename, disk_load_addr, disk_data_size
//   NOTE: File must already exist (use disk_create_file first if needed)
//---------------------------------------------------------------------------
disk_save_file:
    jsr disk_open_file
    bcs dsf_done

    lda disk_load_addr
    sta pb_write_addr
    lda disk_load_addr + 1
    sta pb_write_addr + 1
    lda disk_data_size
    sta pb_write_reqcount
    lda disk_data_size + 1
    sta pb_write_reqcount + 1

    lda disk_file_ref
    sta pb_write_ref
    jsr PRODOS_MLI
    .byte MLI_WRITE
    .word pb_write
    bcs dsf_err

    jsr disk_close_file
    clc
    rts
dsf_err:
    sta disk_last_error
    pha
    jsr disk_close_file
    pla
    sec
dsf_done:
    rts

//---------------------------------------------------------------------------
// disk_show_error - Print last error code as hex to current cursor position
//---------------------------------------------------------------------------
disk_show_error:
    lda disk_last_error
    jsr PRBYTE
    rts

//===========================================================================

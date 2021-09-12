.model small
.stack 100h
.data

; DESCRIPTION OF THE PROGRAM:
	description db 10, 13
				db 9, "Viktorija Baikauskaite, Software Engineering year 1, gr. 4", 10, 13
				db 9, "1) user provides .com file to disassemble", 10, 13
				db 9, "2) program creates res.txt file to write in.", 10, 13, "$"

	is_success db 10, 13
				db 9, "Your file has been disassembled succesfully.", 10, 13, "$"
	
; FILE VARIABLES:
	input_file db 10 dup (0)
	input_handle dw ?
	output_file db "res.txt", 0
	output_handle dw ?

; READING BUFFER:
	read_buffer db 16 dup ("$")
	read_length dw 16
	read_index dw 0

; WRITING BUFFER:
	; The writing buffer will produce lines in the res.txt according to the syntax below
	; offset_cs: machine_code instruction_name operand_1(, operand_2)
	; offset_cs: machine_code UNDEFINED
	write_buffer db 4 dup (?), ":", 9, 60 dup (?)
	write_index dw 6

; SYMBOLS AND WORDS FOR THE WRITING BUFFER:
	endline db 10, 13
	byte_ptr db "byte ptr "
	word_ptr db "word ptr "
	left_bracket db "["
	right_bracket db "]"
	colon db ":"
	plus_sign db "+"
	undefined db "UNDEFINED"

; VARIOUS VARIABLES FOR DETECTING THE FORMAT:
	offset_cs dw 0100h
	operation_byte db ?
	current_byte db ?
	address_byte db ?
	hex_byte db ?
	ascii_byte db 2 dup (?)
	temp_lower_byte db ?
	temp_higher_byte db ?
	is_offset db 0
	is_immediate db 0

	reg_width db 0
	direction db 0
	a_mod db ?
	a_reg db ?
	a_rm db ?
	reg db ?
	sw db ?

	prefix db 0
	seg_reg db 0
	byte_offset dw 0
	offset_hb db 0
	offset_lb db 0
	lower_byte db 0
	a_hb db 0
	a_lb db 0
	sr_hb db 0
	sr_lb db 0

; NAMES OF INSTRUCTIONS:
	i_mov db "MOV"
	i_push db "PUSH"
	i_pop db "POP"
	i_add db "ADD"
	i_inc db "INC"
	i_sub db "SUB"
	i_dec db "DEC"
	i_cmp db "CMP"
	i_mul db "MUL"
	i_div db "DIV"
	i_call db "CALL"
	i_call_far db "CALL FAR"
	i_ret db "RET"
	i_retf db "RETF"
	i_jmp db "JMP"
	i_jmp_0000 db "JO"
	i_jmp_0001 db "JNO"
	i_jmp_0010 db "JB"
	i_jmp_0011 db "JNB"
	i_jmp_0100 db "JE"
	i_jmp_0101 db "JNE"
	i_jmp_0110 db "JBE"
	i_jmp_0111 db "JA"
	i_jmp_1000 db "JS"
	i_jmp_1001 db "JNS"
	i_jmp_1010 db "JP"
	i_jmp_1011 db "JNP"
	i_jmp_1100 db "JL"
	i_jmp_1101 db "JGE"
	i_jmp_1110 db "JLE"
	i_jmp_1111 db "JG"
	i_jcxz db "JCXZ"
	i_loop db "LOOP"
	i_int db "INT"
	i_int3 db "INT 3"
	i_xor db "XOR"

; NAMES OF REGISTERS:
	r_ax db "AX"
	r_bx db "BX"
	r_cx db "CX"
	r_dx db "DX"
	r_al db "AL"
	r_ah db "AH"
	r_bl db "BL"
	r_bh db "BH"
	r_ch db "CH"
	r_cl db "CL"
	r_dh db "DH"
	r_dl db "DL"
	r_sp db "SP"
	r_bp db "BP"
	r_si db "SI"
	r_di db "DI"
	r_bxsi db "BX+SI"
	r_bxdi db "BX+DI"
	r_bpsi db "BP+SI"
	r_bpdi db "BP+DI"

; NAMES OF SEGMENTS:
	seg_es db "ES:"
	seg_cs db "CS:"
	seg_ss db "SS:"
	seg_ds db "DS:"

; ERROR MESSAGES:
	error_1 db 10, 13, 9, "The file's name should be no longer than 10 characters", 10, 13, "$"
	error_2 db 10, 13, 9, "Unable to open file.", 10, 13, "$"
	error_3 db 10, 13, 9, "Unable to create file.", 10, 13, "$"
	error_4 db 10, 13, 9, "Unable to read file.", 10, 13, "$"
	error_5 db 10, 13, 9, "Unable to write file.", 10, 13, "$"
	error_6 db 10, 13, 9, "Unable to close file.", 10, 13, "$"

.code

MAIN PROC NEAR
	
	BEGGINING:
	mov ax, @data
	mov ds, ax

	call SCAN_PARAMETRES
	call OPEN_FILE
	call CREATE_FILE
	call READ_FILE

	MAIN_PROGRAM:
	mov is_offset, 0
	mov prefix, 0
	call GET_CS_OFFSET
	call GET_ONE_BYTE
	call IF_PREFIX
	call FIND_FORMAT
	jmp MAIN_PROGRAM
	
	NAME_TOO_LONG:
	mov ah, 9
	mov dx, offset error_1
	int 21h
	jmp ENDING
    
	HELP:
	mov ah, 9
	mov dx, offset description
	int 21h
	jmp ENDING

    CLOSING_FILES:
    call CLOSE_FILE
   	mov ax, output_handle
    mov input_handle, ax
    call CLOSE_FILE
    mov ah, 9
	mov dx, offset is_success
	int 21h

    ENDING:
	mov ax, 4C00h
	int 21h

MAIN ENDP

SCAN_PARAMETRES PROC NEAR

	mov bx, 81h
	PARAMETRES:
	mov dx, es:[bx]
	inc bx
	cmp dl, " "
	je PARAMETRES
	cmp dl, 13
	je JUMP_TO_HELP
	cmp dx, "?/"
	je JUMP_TO_HELP
	
    mov si, offset input_file
    xor cx, cx
	INPUT_FILE_NAME:
	cmp dl, 13
	je IF_COM_SUFFIX
	cmp dl, " "
	je INC_BX
	inc cx
	cmp cx, 10
	jg NAME_TOO_LONG ; the input file's name should be no longer than 10 characters
	mov [si], dl
	INC_BX:
	mov dl, byte ptr es:[bx]
	inc bx
	inc si
	jmp INPUT_FILE_NAME

	IF_COM_SUFFIX: ; it is checked whether the given file has an appropriate suffix
	add cx, offset input_file
	mov si, cx
	cmp [si-4], "c."
	je IF_OM
	cmp [si-4], "C."
	jne JUMP_TO_HELP
	cmp [si-2], "MO"
	jne JUMP_TO_HELP
		IF_OM:
		cmp [si-2], "mo"
		jne JUMP_TO_HELP
	jmp RET_PARAMETRES
		
	JUMP_TO_HELP:
	jmp HELP

	RET_PARAMETRES:
    RET

SCAN_PARAMETRES ENDP

OPEN_FILE PROC NEAR
	
	push ax
	push dx

	mov ah, 3Dh
	mov al, 02h
	mov dx, offset input_file ; moving the name of the input file
	int 21h
	mov input_handle, ax ; saving the descriptor of the file to a variable
	jnc RET_OPEN
	
	mov ah, 9
	mov dx, offset error_2
	int 21h
    jmp ENDING
	
	RET_OPEN:
	pop dx
	pop ax
	RET

OPEN_FILE ENDP

CREATE_FILE PROC NEAR

	push ax
	push bx
	push cx
	push dx

	CREATING_FILE:
	mov ah, 3Ch
	xor cx, cx
	mov dx, offset output_file
	int 21h
	jnc RET_CREATE_FILE
	
	UNABLE_TO_CREATE:
	mov ah, 9
	mov dx, offset error_3
	int 21h
    jmp ENDING

	RET_CREATE_FILE:
	mov output_handle, ax ; saving the descriptor of the file to a variable
	pop dx
    pop cx
    pop bx
    pop ax
	RET

CREATE_FILE ENDP

READ_FILE PROC NEAR

	push ax
	push bx
	push cx
	push dx

	mov ah, 3Fh
	mov dx, offset read_buffer
	mov bx, input_handle
	mov cx, read_length
	int 21h
	jnc RET_READ_FILE

	mov ah, 9
	mov dx, offset error_4
	int 21h
    jmp ENDING

    RET_READ_FILE:
    mov read_length, ax ; the amount of read bytes
    cmp read_length, 0 ; if 0 bytes have been read, the program ends
	je TO_ENDING    
    mov read_index, 0
    pop dx
    pop cx
    pop bx
    pop ax
    RET

    TO_ENDING:
    jmp CLOSING_FILES

READ_FILE ENDP

GET_ONE_BYTE PROC NEAR ; takes on byte from the reading buffer

	push ax
	push bx
	push cx
	push dx

	mov si, read_index
	inc si
	cmp si, read_length ; checks whether this is the last byte in the reading buffer
	jbe GET_BYTE
	call READ_FILE ; if so, latter bytes from the input file are written into the reading buffer
	GET_BYTE:
	mov bx, offset read_buffer
	mov si, read_index
	mov al, byte ptr [bx+si]
	mov current_byte, al
	mov hex_byte, al
	mov bx, offset read_index
	inc byte ptr [bx] ; the index of read_buffer is incremented

	INC_CS_OFFSET:
	mov bx, offset offset_cs
	inc word ptr [bx] ; the offset of the CS is incremented

	WRITE_MACHINE_CODE: ; the byte is written in ascii code to the writing buffer
	mov si, write_index
	mov bx, offset write_buffer
	call WRITE_HEX
	mov di, offset ascii_byte
	mov al, [di]
	mov [bx+si], al
	mov al, [di+1]
	inc si
	mov [bx+si], al
	inc si
	mov write_index, si
    
	pop dx
    pop cx
    pop bx
    pop ax
	RET

GET_ONE_BYTE ENDP

WRITE_HEX PROC NEAR

	push ax
	push bx
	push cx
	push dx
	push di
	push si
	
	mov di, offset ascii_byte
	
	NUMBER_2:
	mov bl, hex_byte
	and bl, 0F0h
	mov cl, 4
	shr bl, cl
	call TURNING
	mov [di], bl

	NUMBER_1:
	mov bl, hex_byte
	and bl, 0Fh
	call TURNING
	mov [di+1], bl
	jmp RET_HEX
	
	TURNING:
	cmp bl, 9
	jbe HEX_NUMBER
	HEX_LETTER:
	add bl, 37h
	jmp RET_NUMBER
	HEX_NUMBER:
	add bl, "0"
	RET_NUMBER:
	ret

	RET_HEX:
	pop si
	pop di
	pop dx
    pop cx
    pop bx
    pop ax
	RET    

WRITE_HEX ENDP

GET_CS_OFFSET PROC NEAR

	push ax
	push bx
	push cx
	push dx
	push si
	push di

	mov di, offset write_buffer

	mov bx, offset_cs
	mov hex_byte, bh
	call WRITE_HEX
	call CS_WRITE_BUFFER
	add di, 1
	mov bx, offset_cs
	mov hex_byte, bl
	call WRITE_HEX
	call CS_WRITE_BUFFER
	jmp RET_CS_OFFSET

	CS_WRITE_BUFFER: ; the offset of CS is written into the writing buffer
	mov si, offset ascii_byte
	mov al, byte ptr [si]
	mov byte ptr [di], al
	inc si
	inc di
	mov al, byte ptr [si]
	mov byte ptr [di], al
	ret

	RET_CS_OFFSET:
	pop di
	pop si
	pop dx
    pop cx
    pop bx
    pop ax
	RET

GET_CS_OFFSET ENDP

IF_PREFIX PROC NEAR

	push ax
	push bx
	push cx
	push dx

	cmp current_byte, 26h
	je IS_PREFIX
	cmp current_byte, 2Eh
	je IS_PREFIX
	cmp current_byte, 36h
	je IS_PREFIX
	cmp current_byte, 3Eh
	je IS_PREFIX
	jmp RET_IF_PREFIX

	IS_PREFIX: ; the prefix is saved into a variable
	mov al, current_byte
	mov prefix, al

	CALL_GET_BYTE: ; if the byte is a prefix, another byte is read
	call GET_ONE_BYTE

	RET_IF_PREFIX:
	pop dx
    pop cx
    pop bx
    pop ax
	RET

IF_PREFIX ENDP

FIND_FORMAT PROC NEAR

	push ax
	push bx
	push cx
	push dx
	
	mov al, current_byte
	mov operation_byte, al

	mov al, operation_byte
	and al, 11111100b
	cmp al, 00110000b ; xor reg r/m
	je TO_FORMAT_1
	cmp al, 00000000b ; add reg
	je TO_FORMAT_1
	cmp al, 00101000b ; sub reg
	je TO_FORMAT_1
	cmp al, 00111000b ; cmp reg
	je TO_FORMAT_1
	cmp al, 10001000b ; mov reg r/m
	je TO_FORMAT_1

	mov al, operation_byte
	and al, 11111110b
	cmp al, 00000100b ; add acc
	je TO_FORMAT_2
	cmp al, 00101100b ; sub acc
	je TO_FORMAT_2
	cmp al, 00111100b ; cmp acc
	je TO_FORMAT_2
	mov al, operation_byte
	and al, 11110000b
	cmp al, 10110000b ; mov reg < imm
	je TO_FORMAT_2

	mov al, operation_byte
	and al, 11100111b
	cmp al, 00000110b ; push sr
	je TO_FORMAT_3
	cmp al, 00000111b ; pop sr
	je TO_FORMAT_3

	mov al, operation_byte
	and al, 11111000b
	cmp al, 01000000b ; inc reg
	je TO_FORMAT_4
	cmp al, 01001000b ; dec reg
	je TO_FORMAT_4
	cmp al, 01010000b ; push reg
	je TO_FORMAT_4
	cmp al, 01011000b ; pop reg
	je TO_FORMAT_4

	mov al, operation_byte
	and al, 11110000b
	cmp al, 01110000b ; conditional jumps
	je TO_FORMAT_5
	mov al, operation_byte ; JCXZ
	cmp al, 11100011b
	je TO_FORMAT_5

	mov al, operation_byte
	and al, 11111100b
	cmp al, 10000000b ; add, sub, cmp
	je TO_FORMAT_6
	mov al, operation_byte
	and al, 11111110b ; mov
	cmp al, 11000110b
	je TO_FORMAT_6

	jmp SKIP
	TO_FORMAT_1:
	jmp FORMAT_1
	TO_FORMAT_2:
	jmp FORMAT_2
	TO_FORMAT_3:
	jmp FORMAT_3
	TO_FORMAT_4:
	jmp FORMAT_4
	TO_FORMAT_5:
	jmp FORMAT_5
	TO_FORMAT_6:
	jmp FORMAT_6
	SKIP:

	mov al, operation_byte
	and al, 11111110b
	cmp al, 10100000b ; mov acc < mem
	je TO_FORMAT_7
	cmp al, 10100010b ; mov mem < acc
	je TO_FORMAT_7

	mov al, operation_byte
	and al, 11111101b
	cmp al, 10001100b ; mov
	je TO_FORMAT_8

	mov al, operation_byte
	cmp al, 11100010b ; loop direct within segment-short
	je TO_FORMAT_9
	cmp al, 11101001b ; jmp direct within segment
	je TO_FORMAT_9
	cmp al, 11101010b ; jmp direct intersegment
	je TO_FORMAT_9
	cmp al, 11101011b ; jmp direct within segment-short
	je TO_FORMAT_9
	cmp al, 11101000b ; call direct within segment
	je TO_FORMAT_9
	cmp al, 10011010b ; call direct intersegment
	je TO_FORMAT_9

	mov al, operation_byte
	cmp al, 10001111b
	je TO_FORMAT_10

	mov al, operation_byte
	cmp al, 11000011b ; ret
	je TO_FORMAT_11
	cmp al, 11001011b ; retf
	je TO_FORMAT_11
	cmp al, 11001100b ; int 3
	je TO_FORMAT_11
	cmp al, 11001101b ; int type
	je TO_FORMAT_11
	cmp al, 11000010b ; ret imm
	je TO_FORMAT_11
	cmp al, 11001010b ; retf imm
	je TO_FORMAT_11

	mov al, operation_byte
	and al, 11110110b
	cmp al, 11110110b ; mul, div
	je TO_FORMAT_12
	mov al, operation_byte
	cmp al, 11111111b ; call, jmp: indirect within segment, indirect intersegment
					  ; inc, dec, push
	je TO_FORMAT_12
	cmp al, 11111110b
	je TO_FORMAT_12

	jmp IF_UNDEFINED_BYTE

	TO_FORMAT_7:
	jmp FORMAT_7
	TO_FORMAT_8:
	jmp FORMAT_8
	TO_FORMAT_9:
	jmp FORMAT_9
	TO_FORMAT_10:
	jmp FORMAT_10
	TO_FORMAT_11:
	jmp FORMAT_11
	TO_FORMAT_12:
	jmp FORMAT_12

	IF_UNDEFINED_BYTE:
	call UNDEFINED_BYTE

	RET_FIND_FORMAT:
	call WRITE_FILE
    pop dx
    pop cx
    pop bx
    pop ax
	RET

FIND_FORMAT ENDP

FORMAT_1 PROC NEAR

	call FIND_WIDTH
	call FIND_DIRECTION
	call GET_ONE_BYTE
	call FIND_MOD_REG_RM
	call FIND_OFFSET ; finds the offset if mod is either 00 or 01

	call MOVE_SOME_SPACES

	FORMAT_1_INS:
	mov al, operation_byte
	and al, 11111100b
	cmp al, 00000000b ; add reg
	je ADD_REG
	cmp al, 00101000b ; sub reg
	je SUB_REG
	cmp al, 00111000b ; cmp reg
	je CMP_REG
	cmp al, 10001000b ; mov reg r/m
	je MOV_REG
	cmp al, 00110000b ; xor reg
	je XOR_REG

	ADD_REG:
	mov bx, offset i_add
	jmp FORMAT_1_DIR
	SUB_REG:
	mov bx, offset i_sub
	jmp FORMAT_1_DIR
	CMP_REG:
	mov bx, offset i_cmp
	jmp FORMAT_1_DIR
	MOV_REG:
	mov bx, offset i_mov
	jmp FORMAT_1_DIR
	XOR_REG:
	mov bx, offset i_xor

	FORMAT_1_DIR:
	mov cx, 3
	call MOVE_INSTRUCTION
	mov cx, 1
	call MOVE_SPACES
	mov al, direction
	cmp al, 1
	je DIR_1

	DIR_0:
	mov al, a_mod
	cmp al, 11000000b
	je DIR_0_11
	jmp DIR_0_00_01_10
	DIR_0_11:
	call MOVE_PREFIX
	call MOD_11_OP2
	call MOVE_COMMA
	call MOD_11_OP1
	jmp RET_FORMAT_1
	DIR_0_00_01_10:
	call MOVE_PREFIX
	call MOD_00_01_10_OP2
	call MOVE_COMMA
	call MOD_00_01_10_OP1
	jmp RET_FORMAT_1

	DIR_1:
	mov al, a_mod
	cmp al, 11000000b
	je DIR_1_11
	jmp DIR_1_00_01_10
	DIR_1_11:
	call MOD_11_OP1
	call MOVE_COMMA
	call MOVE_PREFIX
	call MOD_11_OP2
	jmp RET_FORMAT_1
	DIR_1_00_01_10:
	call MOD_00_01_10_OP1
	call MOVE_COMMA
	call MOVE_PREFIX
	call MOD_00_01_10_OP2
	jmp RET_FORMAT_1

	MOD_11_OP1:
	mov al, a_reg
	mov reg, al
	call REGISTER
	ret
	MOD_11_OP2:
	mov al, a_rm
	mov reg, al
	call REGISTER
	ret
	MOD_00_01_10_OP1:
	mov al, a_reg
	mov reg, al
	call REGISTER
	ret
	MOD_00_01_10_OP2:
	call MOD_00_01_10
	ret

	RET_FORMAT_1:
	call MOVE_ENDLINE
	jmp RET_FIND_FORMAT

FORMAT_1 ENDP

FORMAT_2 PROC NEAR

	call FIND_WIDTH
	call GET_ONE_BYTE
	mov al, current_byte
	mov lower_byte, al

	mov reg, 000h ; the first operand is an accumulator (AX, AH, AL)
	mov al, operation_byte
	and al, 11110000b
	cmp al, 10110000b
	jne FURTHER
	mov al, operation_byte
	and al, 00001000b
	mov cl, 3
	shr al, cl
	mov reg_width, al
	mov al, operation_byte
	and al, 00000111b
	mov reg, al

	FURTHER:
	cmp reg_width, 1
	je FORMAT_2_WORD

	FORMAT_2_BYTE:
	mov cx, 16
	call MOVE_SPACES
	call FORMAT_2_INS
	call MOVE_INSTRUCTION
	mov cx, 1
	call MOVE_SPACES
	call REGISTER
	call MOVE_COMMA
	mov al, lower_byte
	mov hex_byte, al
	call WRITE_HEX
	call MOVE_BYTE
	jmp RET_FORMAT_2

	FORMAT_2_WORD:
	call GET_ONE_BYTE
	mov cx, 14
	call MOVE_SPACES
	call FORMAT_2_INS
	call MOVE_INSTRUCTION
	mov cx, 1
	call MOVE_SPACES
	call REGISTER
	call MOVE_COMMA
	call MOVE_WORD
	jmp RET_FORMAT_2

	FORMAT_2_INS:
	mov al, operation_byte
	and al, 11111110b
	cmp al, 00000100b
	je ADD_ACC
	cmp al, 00101100b
	je SUB_ACC
	cmp al, 00111100b
	je CMP_ACC
	jmp MOV_IMM

	ADD_ACC:
	mov bx, offset i_add
	mov cx, 3
	ret
	SUB_ACC:
	mov bx, offset i_sub
	mov cx, 3
	ret
	CMP_ACC:
	mov bx, offset i_cmp
	mov cx, 3
	ret
	MOV_IMM:
	mov bx, offset i_mov
	mov cx, 3
	ret

	RET_FORMAT_2:
	call MOVE_ENDLINE
	jmp RET_FIND_FORMAT

FORMAT_2 ENDP

FORMAT_3 PROC NEAR

	mov cx, 18
	call MOVE_SPACES	

	mov al, operation_byte
	and al, 11100111b
	cmp al, 00000110b
	je PUSH_SR
	cmp al, 00000111b
	je POP_SR

	PUSH_SR:
	mov cx, 4
	mov bx, offset i_push
	jmp FORMAT_3_SR
	POP_SR:
	mov cx, 3
	mov bx, offset i_pop

	FORMAT_3_SR:
	call MOVE_INSTRUCTION
	mov cx, 1
	call MOVE_SPACES
	mov al, operation_byte
	and al, 00011000b
	mov cl, 3
	shr al, cl
	mov seg_reg, al
	call SEG_REGISTER
	call MOVE_ENDLINE
	jmp RET_FIND_FORMAT

FORMAT_3 ENDP

FORMAT_4 PROC NEAR

	mov reg_width, 1
	mov cx, 18
	call MOVE_SPACES	

	mov al, operation_byte
	and al, 11111000b
	cmp al, 01000000b
	je INC_REG
	cmp al, 01001000b
	je DEC_REG
	cmp al, 01010000b
	je PUSH_REG
	cmp al, 01011000b
	je POP_REG

	INC_REG:
	mov cx, 3
	mov bx, offset i_inc
	jmp FORMAT_4_REG
	DEC_REG:
	mov cx, 3
	mov bx, offset i_dec
	jmp FORMAT_4_REG
	PUSH_REG:
	mov cx, 4
	mov bx, offset i_push
	jmp FORMAT_4_REG
	POP_REG:
	mov cx, 3
	mov bx, offset i_pop

	FORMAT_4_REG:
	call MOVE_INSTRUCTION
	mov cx, 1
	call MOVE_SPACES
	mov al, operation_byte
	and al, 00000111b
	mov reg, al
	call REGISTER
	call MOVE_ENDLINE
	jmp RET_FIND_FORMAT

FORMAT_4 ENDP

FORMAT_5 PROC NEAR

	call GET_ONE_BYTE
	call IF_NEGATIVE
	mov cx, 16
	call MOVE_SPACES
	call CONDITIONAL_JUMPS
	call MOVE_INSTRUCTION
	mov cx, 1
	call MOVE_SPACES
	mov ax, offset_cs
	add byte_offset, ax
	mov ax, byte_offset
	mov lower_byte, al
	mov current_byte, ah
	call MOVE_WORD
	call MOVE_ENDLINE
	jmp RET_FIND_FORMAT

	CONDITIONAL_JUMPS:
	mov al, operation_byte
	cmp al, 01110000b
	je PRINT_JO
	cmp al, 01110001b
	je PRINT_JNO
	cmp al, 01110010b
	je PRINT_JB
	cmp al, 01110011b
	je PRINT_JNB
	cmp al, 01110100b
	je PRINT_JE
	cmp al, 01110101b
	je PRINT_JNE
	cmp al, 01110110b
	je PRINT_JBE
	cmp al, 01110111b
	je PRINT_JA
	cmp al, 01111000b
	je PRINT_JS
	cmp al, 01111001b
	je PRINT_JNS
	cmp al, 01111010b
	je PRINT_JP
	cmp al, 01111011b
	je PRINT_JNP
	cmp al, 01111100b
	je PRINT_JL
	cmp al, 01111101b
	je PRINT_JGE
	cmp al, 01111110b
	je PRINT_JLE
	cmp al, 01111111b
	je PRINT_JG
	jmp PRINT_JCXZ

	PRINT_JO:
	mov bx, offset i_jmp_0000
	mov cx, 2
	ret
	PRINT_JNO:
	mov bx, offset i_jmp_0001
	mov cx, 3
	ret
	PRINT_JB:
	mov bx, offset i_jmp_0010
	mov cx, 2
	ret
	PRINT_JNB:
	mov bx, offset i_jmp_0011
	mov cx, 3
	ret
	PRINT_JE:
	mov bx, offset i_jmp_0100
	mov cx, 2
	ret
	PRINT_JNE:
	mov bx, offset i_jmp_0101
	mov cx, 3
	ret
	PRINT_JBE:
	mov bx, offset i_jmp_0110
	mov cx, 3
	ret
	PRINT_JA:
	mov bx, offset i_jmp_0111
	mov cx, 2
	ret
	PRINT_JS:
	mov bx, offset i_jmp_1000
	mov cx, 2
	ret
	PRINT_JNS:
	mov bx, offset i_jmp_1001
	mov cx, 3
	ret
	PRINT_JP:
	mov bx, offset i_jmp_1010
	mov cx, 2
	ret
	PRINT_JNP:
	mov bx, offset i_jmp_1011
	mov cx, 3
	ret
	PRINT_JL:
	mov bx, offset i_jmp_1100
	mov cx, 2
	ret
	PRINT_JGE:
	mov bx, offset i_jmp_1101
	mov cx, 3
	ret
	PRINT_JLE:
	mov bx, offset i_jmp_1110
	mov cx, 3
	ret
	PRINT_JG:
	mov bx, offset i_jmp_1111
	mov cx, 2
	ret
	PRINT_JCXZ:
	mov bx, offset i_jcxz
	mov cx, 4
	ret

FORMAT_5 ENDP

FORMAT_6 PROC NEAR

	call FIND_SW
	call GET_ONE_BYTE
	call FIND_MOD_REG_RM
	mov al, a_rm
	mov reg, al
	call FIND_WIDTH
	call FIND_OFFSET
	
	mov al, operation_byte
	cmp al, 11000110b
	je FORMAT_6_SW_11
	cmp al, 11000111b
	je FORMAT_6_SW_01

	mov al, sw
	cmp al, 01
	je FORMAT_6_SW_01

	FORMAT_6_SW_11: ; if one immediate byte
	call GET_ONE_BYTE
	mov al, sw
	cmp al, 00
	je FURTHER_00
	call IF_NEGATIVE
	jmp FURTHER_11
	FURTHER_00: ; if one unsigned immediate byte
	xor ax, ax
	mov al, current_byte
	mov byte_offset, ax
	FURTHER_11:
	mov ax, byte_offset
	mov temp_lower_byte, al
	mov temp_higher_byte, ah
	mov is_immediate, 1
	call MOVE_SOME_SPACES
	call FORMAT_8_INS
	call MOVE_INSTRUCTION
	mov cx, 1
	call MOVE_SPACES
	mov al, a_mod
	cmp al, 11000000b
	je FURTHER_1
	call MOVE_BYTE_PTR
	FURTHER_1:
	call MOVE_PREFIX
	call FORMAT_8_MOD
	call MOVE_COMMA
	mov al, temp_lower_byte
	mov lower_byte, al
	mov al, temp_higher_byte
	mov current_byte, al
	call MOVE_WORD
	jmp RET_FORMAT_6

	FORMAT_6_SW_01: ; if two immediate bytes
	call GET_ONE_BYTE
	mov al, current_byte
	mov temp_lower_byte, al
	mov is_immediate, 2
	call GET_ONE_BYTE
	mov al, current_byte
	mov temp_higher_byte, al
	call MOVE_SOME_SPACES
	call FORMAT_8_INS
	call MOVE_INSTRUCTION
	mov cx, 1
	call MOVE_SPACES
	mov al, a_mod
	cmp al, 11000000b
	je FURTHER_2
	call MOVE_WORD_PTR
	FURTHER_2:
	call MOVE_PREFIX
	call FORMAT_8_MOD
	call MOVE_COMMA
	mov al, temp_lower_byte
	mov lower_byte, al
	mov al, temp_higher_byte
	mov current_byte, al
	call MOVE_WORD
	jmp RET_FORMAT_6

	FORMAT_8_MOD:
	mov al, a_mod
	cmp al, 11000000b
	jne FORMAT_8_MOD_00_01_10
	FORMAT_8_MOD_11:
	call REGISTER
	ret
	FORMAT_8_MOD_00_01_10:
	call MOD_00_01_10
	ret

	FORMAT_8_INS:
	mov al, operation_byte
	and al, 11111110b
	cmp al, 11000110b
	je MOV_REG_IMM
	mov al, a_reg
	cmp al, 00000000b
	je ADD_IMM
	cmp al, 00000101b
	je SUB_IMM
	cmp al, 00000111b
	je CMP_IMM

	ADD_IMM:
	mov bx, offset i_add
	mov cx, 3
	ret
	SUB_IMM:
	mov bx, offset i_sub
	mov cx, 3
	ret
	CMP_IMM:
	mov bx, offset i_cmp
	mov cx, 3
	ret
	MOV_REG_IMM:
	mov bx, offset i_mov
	mov cx, 3
	ret

	RET_FORMAT_6:
	call MOVE_ENDLINE
	mov is_immediate, 0
	jmp RET_FIND_FORMAT

FORMAT_6 ENDP

FORMAT_7 PROC NEAR

	call FIND_WIDTH
	call GET_ONE_BYTE
	mov al, current_byte
	mov lower_byte, al
	call GET_ONE_BYTE
	mov cx, 14
	call MOVE_SPACES

	mov bx, offset i_mov
	mov cx, 3
	call MOVE_INSTRUCTION
	mov cx, 1
	call MOVE_SPACES

	mov reg, 000h ; the operand is an accumulator (AX, AH, AL)

	FORMAT_7_INS:
	mov al, operation_byte
	and al, 11111110b
	cmp al, 10100000b ; mov acc <- mem
	je MOV_ACC_MEM
	cmp al, 10100010b ; mov mem <- acc
	je MOV_MEM_ACC

	MOV_ACC_MEM:
	call REGISTER
	call MOVE_COMMA
	mov bx, offset left_bracket
	call MOVE_SYMBOL
	call MOVE_WORD
	mov bx, offset right_bracket
	call MOVE_SYMBOL
	jmp RET_FORMAT_7

	MOV_MEM_ACC:
	mov bx, offset left_bracket
	call MOVE_SYMBOL
	call MOVE_WORD
	mov bx, offset right_bracket
	call MOVE_SYMBOL
	call MOVE_COMMA
	call REGISTER
	jmp RET_FORMAT_7

	RET_FORMAT_7:
	call MOVE_ENDLINE
	jmp RET_FIND_FORMAT

FORMAT_7 ENDP

FORMAT_8 PROC NEAR

	call GET_ONE_BYTE
	call FIND_MOD_REG_RM
	mov al, 1
	mov reg_width, al
	mov al, a_reg
	mov seg_reg, al
	mov al, a_rm 
	mov reg, al
	call FIND_DIRECTION
	call FIND_OFFSET
	call MOVE_SOME_SPACES

	mov bx, offset i_mov
	mov cx, 3
	call MOVE_INSTRUCTION
	mov cx, 1
	call MOVE_SPACES

	mov al, direction
	cmp al, 0
	je FORMAT_8_0

	FORMAT_8_1:
	mov al, a_mod
	cmp al, 11000000b
	je FORMAT_8_1_11
	jmp FORMAT_8_1_00_01_10
	FORMAT_8_1_11:
	call SEG_REGISTER
	call MOVE_COMMA
	call REGISTER
	jmp RET_FORMAT_8
	FORMAT_8_1_00_01_10:
	call SEG_REGISTER
	call MOVE_COMMA
	call MOVE_PREFIX
	call MOD_00_01_10

	FORMAT_8_0:
	mov al, a_mod
	cmp al, 11000000b
	je FORMAT_8_0_11
	jmp FORMAT_8_0_00_01_10
	FORMAT_8_0_11:
	call REGISTER
	call MOVE_COMMA
	call SEG_REGISTER
	jmp RET_FORMAT_8
	FORMAT_8_0_00_01_10:
	call MOVE_PREFIX
	call MOD_00_01_10
	call MOVE_COMMA
	call SEG_REGISTER
	jmp RET_FORMAT_8

	RET_FORMAT_8:
	mov direction, 0 ; the direction variable is reset to 0
	call MOVE_ENDLINE
	jmp RET_FIND_FORMAT

FORMAT_8 ENDP

FORMAT_9 PROC NEAR

	mov al, operation_byte
	cmp al, 11100010b ; loop direct within segment-short
	je SHORT_JMP
	cmp al, 11101011b ; jmp direct within segment-short
	je SHORT_JMP	
	cmp al, 11101001b ; jmp direct within segment
	je JMP_DIR_SEG
	cmp al, 11101010b ; jmp direct intersegment
	je TO_JMP_DIR_INT
	cmp al, 11101000b ; call direct within segment
	je JMP_DIR_SEG
	cmp al, 10011010b ; call direct intersegment
	je TO_JMP_DIR_INT

	SHORT_JMP:
	call GET_ONE_BYTE
	call IF_NEGATIVE
	mov cx, 16
	call MOVE_SPACES
	call FORMAT_9_INS
	call MOVE_INSTRUCTION
	mov cx, 1
	call MOVE_SPACES
	mov ax, offset_cs
	add byte_offset, ax
	mov ax, byte_offset
	mov lower_byte, al
	mov current_byte, ah
	call MOVE_WORD
	jmp RET_FORMAT_9

	TO_JMP_DIR_INT:
	je JMP_DIR_INT

	FORMAT_9_INS:
	mov al, operation_byte
	cmp al, 11100010b ; loop direct within segment-short
	je WRITE_LOOP
	cmp al, 11101011b ; jmp direct within segment-short
	je WRITE_JMP	
	cmp al, 11101001b ; jmp direct within segment
	je WRITE_JMP
	cmp al, 11101010b ; jmp direct intersegment
	je WRITE_JMP
	cmp al, 11101000b ; call direct within segment
	je WRITE_CALL
	cmp al, 10011010b ; call direct intersegment
	je WRITE_CALL
	WRITE_LOOP:
	mov bx, offset i_loop
	mov cx, 4
	ret
	WRITE_JMP:
	mov bx, offset i_jmp
	mov cx, 3
	ret
	WRITE_CALL:
	mov bx, offset i_call
	mov cx, 4
	ret

	JMP_DIR_SEG:
	call GET_ONE_BYTE
	mov al, current_byte
	mov lower_byte, al
	call GET_ONE_BYTE
	mov cx, 14
	call MOVE_SPACES
	call FORMAT_9_INS
	call MOVE_INSTRUCTION
	mov cx, 1
	call MOVE_SPACES
	mov ah, current_byte
	mov al, lower_byte
	add ax, offset_cs
	mov lower_byte, al
	mov current_byte, ah
	call MOVE_WORD
	jmp RET_FORMAT_9

	JMP_DIR_INT:
	call GET_ONE_BYTE
	mov al, current_byte
	mov a_lb, al
	call GET_ONE_BYTE
	mov al, current_byte
	mov a_hb, al
	call GET_ONE_BYTE
	mov al, current_byte
	mov sr_lb, al
	call GET_ONE_BYTE
	mov al, current_byte
	mov sr_hb, al
	mov cx, 10
	call MOVE_SPACES
	call FORMAT_9_INS
	call MOVE_INSTRUCTION
	mov cx, 1
	call MOVE_SPACES
	mov al, sr_hb 
	mov current_byte, al
	mov al, sr_lb
	mov lower_byte, al
	call MOVE_WORD
	mov bx, offset colon
	call MOVE_SYMBOL
	mov al, a_hb 
	mov current_byte, al
	mov al, a_lb
	mov lower_byte, al
	call MOVE_WORD

	RET_FORMAT_9:
	call MOVE_ENDLINE
	jmp RET_FIND_FORMAT

FORMAT_9 ENDP

FORMAT_10 PROC NEAR

	call GET_ONE_BYTE
	call FIND_MOD_REG_RM
	mov al, 1
	mov reg_width, al
	mov al, a_rm 
	mov reg, al
	call FIND_OFFSET
	call MOVE_SOME_SPACES

	mov bx, offset i_pop
	mov cx, 3
	call MOVE_INSTRUCTION
	mov cx, 1
	call MOVE_SPACES

	MOD_FORMAT_10:
	mov al, a_mod
	cmp al, 11000000b
	je FORMAT_10_11
	jmp FORMAT_10_00_01_10
	FORMAT_10_11:
	call REGISTER
	jmp RET_FORMAT_10
	FORMAT_10_00_01_10:
	call BYTE_WORD_PTR
	call MOVE_PREFIX
	call MOD_00_01_10

	RET_FORMAT_10:
	call MOVE_ENDLINE
	jmp RET_FIND_FORMAT

FORMAT_10 ENDP

FORMAT_11 PROC NEAR

	cmp operation_byte, 11000011b
	je WRITE_RET
	cmp operation_byte, 11001011b ; retf
	je WRITE_RET
	cmp operation_byte, 11001100b
	je WRITE_INT3
	cmp operation_byte, 11001101b
	je INT_TYPE
	cmp operation_byte, 11001010b
	je RET_IMM
	cmp operation_byte, 11000010b
	je RET_IMM

	WRITE_RET:
	mov cx, 18
	call MOVE_SPACES
	call FORMAT_11_INS
	call MOVE_INSTRUCTION
	call MOVE_ENDLINE
	jmp RET_FIND_FORMAT
	WRITE_INT3:
	mov cx, 18
	call MOVE_SPACES
	call FORMAT_11_INS
	call MOVE_INSTRUCTION
	call MOVE_ENDLINE
	jmp RET_FIND_FORMAT
	INT_TYPE:
	call GET_ONE_BYTE
	mov cx, 16
	call MOVE_SPACES
	call FORMAT_11_INS
	call MOVE_INSTRUCTION
	mov cx, 1
	call MOVE_SPACES
	mov al, current_byte
	mov hex_byte, al
	call WRITE_HEX
	call MOVE_BYTE
	call MOVE_ENDLINE
	jmp RET_FIND_FORMAT
	RET_IMM:
	call GET_ONE_BYTE
	mov al, current_byte
	mov lower_byte, al
	call GET_ONE_BYTE
	mov cx, 14
	call MOVE_SPACES
	call FORMAT_11_INS
	call MOVE_INSTRUCTION
	mov cx, 1
	call MOVE_SPACES
	call MOVE_WORD
	call MOVE_ENDLINE
	jmp RET_FIND_FORMAT

	FORMAT_11_INS:
	cmp operation_byte, 11000011b
	je INS_RET
	cmp operation_byte, 11001011b ; retf
	je INS_RETF
	cmp operation_byte, 11001100b
	je INS_INT_3
	cmp operation_byte, 11001101b
	je INS_INT
	cmp operation_byte, 11001010b
	je INS_RETF
	cmp operation_byte, 11000010b
	je INS_RET

	INS_RETF:
	mov bx, offset i_retf
	mov cx, 4
	ret
	INS_RET:
	mov bx, offset i_ret
	mov cx, 3
	ret
	INS_INT:
	mov bx, offset i_int
	mov cx, 3
	ret
	INS_INT_3:
	mov bx, offset i_int3
	mov cx, 5
	ret

FORMAT_11 ENDP

FORMAT_12 PROC NEAR

	call FIND_WIDTH
	call GET_ONE_BYTE
	call FIND_MOD_REG_RM
	call FIND_OFFSET
	call MOVE_SOME_SPACES

	mov al, a_reg
	cmp al, 00000000b
	je FORMAT_12_INC
	cmp al, 00000001b
	je FORMAT_12_DEC
	cmp al, 00000010b
	je FORMAT_12_CALL
	cmp al, 00000011b
	je FORMAT_12_CALL_FAR
	mov bl, operation_byte
	and bl, 11111110b
	cmp bl, 11110110b
	je MUL_OR_DIV
	cmp al, 00000110b
	je FORMAT_12_PUSH
	cmp al, 00000100b
	je FORMAT_12_JMP ; both jumps
	MUL_OR_DIV:
	cmp al, 00000100b
	je FORMAT_12_MUL
	cmp al, 00000110b
	je FORMAT_12_DIV
	jmp IF_UNDEFINED_BYTE

	FORMAT_12_DIV:
	mov bx, offset i_div
	mov cx, 3
	jmp FORMAT_12_MOD

	FORMAT_12_INC:
	mov bx, offset i_inc
	mov cx, 3
	jmp FORMAT_12_MOD

	FORMAT_12_DEC:
	mov bx, offset i_dec
	mov cx, 3
	jmp FORMAT_12_MOD

	FORMAT_12_MUL:
	mov bx, offset i_mul
	mov cx, 3
	jmp FORMAT_12_MOD

	FORMAT_12_JMP:
	mov bx, offset i_jmp
	mov cx, 3
	jmp FORMAT_12_MOD_JMP

	FORMAT_12_CALL:
	mov bx, offset i_call
	mov cx, 4
	jmp FORMAT_12_MOD_JMP

	FORMAT_12_CALL_FAR:
	mov bx, offset i_call_far
	mov cx, 8
	jmp FORMAT_12_MOD_JMP

	FORMAT_12_PUSH:
	mov bx, offset i_push
	mov cx, 4

	FORMAT_12_MOD:
	call MOVE_INSTRUCTION
	mov cx, 1
	call MOVE_SPACES
	mov al, a_mod
	cmp al, 11000000b
	je FORMAT_12_11
	jmp FORMAT_12_00_01_10
	FORMAT_12_11:
	mov al, a_rm
	mov reg, al
	call REGISTER
	jmp RET_FORMAT_12
	FORMAT_12_00_01_10:
	call BYTE_WORD_PTR
	call MOVE_PREFIX
	call MOD_00_01_10
	jmp RET_FORMAT_12

	FORMAT_12_MOD_JMP:
	call MOVE_INSTRUCTION
	mov cx, 1
	call MOVE_SPACES
	mov al, a_mod
	cmp al, 11000000b
	je FORMAT_12_11_JMP
	jmp FORMAT_12_00_01_10_JMP
	FORMAT_12_11_JMP:
	mov al, a_rm
	mov reg, al
	call REGISTER
	jmp RET_FORMAT_12
	FORMAT_12_00_01_10_JMP:
	call MOVE_PREFIX
	call MOD_00_01_10

	RET_FORMAT_12:
	call MOVE_ENDLINE
	jmp RET_FIND_FORMAT

FORMAT_12 ENDP

IF_NEGATIVE PROC NEAR

	push ax
	push bx
	push cx
	push dx

	xor ax, ax
	mov al, current_byte
	cmp al, 80h
	jb RET_IF_NEGATIVE

	mov ah, 0FFh
	
	RET_IF_NEGATIVE:
	mov byte_offset, ax
	pop dx
    pop cx
    pop bx
    pop ax
	RET

IF_NEGATIVE ENDP

FIND_MOD_REG_RM PROC NEAR

	push ax
	push bx
	push cx
	push dx

	mov al, current_byte
	mov address_byte, al
	and al, 11000000b
	mov a_mod, al
	mov al, address_byte
	and al, 00111000b
	mov cl, 3
	shr al, cl
	mov a_reg, al
	mov al, address_byte
	and al, 00000111b
	mov a_rm, al

	pop dx
    pop cx
    pop bx
    pop ax
	RET

FIND_MOD_REG_RM ENDP

MOD_00_01_10 PROC NEAR

	mov bx, offset left_bracket
	call MOVE_SYMBOL
	mov al, a_rm
	cmp al, 00000000b
	je WRITE_BX_SI
	cmp al, 00000001b
	je WRITE_BX_DI
	cmp al, 00000010b
	je WRITE_BP_SI
	cmp al, 00000011b
	je WRITE_BP_DI
	cmp al, 00000100b
	je WRITE_SI
	cmp al, 00000101b
	je WRITE_DI
	cmp al, 00000110b ; skiriasi mod 00 ir mod 01,10
	je WRITE_DIR_BP
	cmp al, 00000111b
	je WRITE_BX

	WRITE_BX_SI:
	mov bx, offset r_bxsi
	mov cx, 5
	jmp WRITE_EA

	WRITE_BX_DI:
	mov bx, offset r_bxdi
	mov cx, 5
	jmp WRITE_EA

	WRITE_BP_SI:
	mov bx, offset r_bpsi
	mov cx, 5
	jmp WRITE_EA

	WRITE_BP_DI:
	mov bx, offset r_bpdi
	mov cx, 5
	jmp WRITE_EA

	WRITE_SI:
	mov bx, offset r_si
	mov cx, 2
	jmp WRITE_EA

	WRITE_DI:
	mov bx, offset r_di
	mov cx, 2
	jmp WRITE_EA

	WRITE_DIR_BP:
	mov al, a_mod
	cmp al, 00000000b
	je WRITE_DIR
	mov bx, offset r_bp
	mov cx, 2
	jmp WRITE_EA

	WRITE_BX:
	mov bx, offset r_bx
	mov cx, 2

	WRITE_EA:
	call MOVE_INSTRUCTION
	mov al, a_mod
	cmp al, 00000000b
	je NO_OFFSET
	mov bx, offset plus_sign ; writing in the '+' sign
	call MOVE_SYMBOL	
	mov al, offset_hb
	mov current_byte, al
	mov al, offset_lb
	mov lower_byte, al
	call MOVE_WORD
	NO_OFFSET:
	mov bx, offset right_bracket
	call MOVE_SYMBOL
	ret

	WRITE_DIR:
	mov al, offset_hb
	mov current_byte, al
	mov al, offset_lb
	mov lower_byte, al
	call MOVE_WORD
	mov bx, offset right_bracket
	call MOVE_SYMBOL
	ret

MOD_00_01_10 ENDP

FIND_OFFSET PROC NEAR

	push ax
	push bx
	push cx
	push dx

	mov al, a_mod
	cmp al, 01000000b ; one byte offset
	je OFFSET_1_BYTE
	cmp al, 10000000b ; two byte offset
	je OFFSET_2_BYTES
	mov al, a_rm
	cmp al, 00000110b ; direct adress
	jne RET_FIND_OFFSET
	mov al, a_mod
	cmp al, 00000000b ; direct adress
	je OFFSET_2_BYTES
	jmp RET_FIND_OFFSET

	OFFSET_1_BYTE:
	call GET_ONE_BYTE
	call IF_NEGATIVE
	mov ax, byte_offset
	mov offset_hb, ah
	mov offset_lb, al
	mov is_offset, 1
	jmp RET_FIND_OFFSET

	OFFSET_2_BYTES:
	call GET_ONE_BYTE
	mov al, current_byte
	mov offset_lb, al
	call GET_ONE_BYTE
	mov al, current_byte
	mov offset_hb, al
	mov is_offset, 2

	RET_FIND_OFFSET:
	pop dx
    pop cx
    pop bx
    pop ax
	RET

FIND_OFFSET ENDP

FIND_WIDTH PROC NEAR

	push ax
	push bx
	push cx
	push dx

	mov al, operation_byte
	and al, 00000001b
	mov reg_width, al

	RET_FIND_WIDTH:
	pop dx
    pop cx
    pop bx
    pop ax
	RET

FIND_WIDTH ENDP

FIND_SW PROC NEAR

	push ax
	push bx
	push cx
	push dx

	mov al, operation_byte
	and al, 00000011b
	mov sw, al

	RET_FIND_SW:
	pop dx
    pop cx
    pop bx
    pop ax
	RET

FIND_SW ENDP

FIND_DIRECTION PROC NEAR

	push ax
	push bx
	push cx
	push dx

	mov al, operation_byte
	and al, 00000010b
	mov cl, 1
	shr al, cl
	mov direction, al

	RET_FIND_DIR:
	pop dx
    pop cx
    pop bx
    pop ax
	RET

FIND_DIRECTION ENDP

REGISTER PROC NEAR

	push ax
	push bx
	push cx
	push dx

	mov al, reg
	cmp reg_width, 1
	je WORD_REG
	cmp reg_width, 0
	je BYTE_REG

	WORD_REG:
	cmp al, 000b
	je AX_REGISTER
	cmp al, 001b
	je CX_REGISTER
	cmp al, 010b
	je DX_REGISTER
	cmp al, 011b
	je BX_REGISTER
	cmp al, 100b
	je SP_REGISTER
	cmp al, 101b
	je BP_REGISTER
	cmp al, 110b
	je SI_REGISTER
	cmp al, 111b
	je DI_REGISTER

	BYTE_REG:
	cmp al, 000b
	je AL_REGISTER
	cmp al, 001b
	je CL_REGISTER
	cmp al, 010b
	je DL_REGISTER
	cmp al, 011b
	je BL_REGISTER
	cmp al, 100b
	je AH_REGISTER
	cmp al, 101b
	je CH_REGISTER
	cmp al, 110b
	je DH_REGISTER
	cmp al, 111b
	je BH_REGISTER


	AX_REGISTER:
	mov bx, offset r_ax
	jmp CALL_MOVE_REG
	CX_REGISTER:
	mov bx, offset r_cx
	jmp CALL_MOVE_REG
	DX_REGISTER:
	mov bx, offset r_dx
	jmp CALL_MOVE_REG
	BX_REGISTER:
	mov bx, offset r_bx
	jmp CALL_MOVE_REG
	SP_REGISTER:
	mov bx, offset r_sp
	jmp CALL_MOVE_REG
	BP_REGISTER:
	mov bx, offset r_bp
	jmp CALL_MOVE_REG
	SI_REGISTER:
	mov bx, offset r_si
	jmp CALL_MOVE_REG
	DI_REGISTER:
	mov bx, offset r_di
	jmp CALL_MOVE_REG
	AL_REGISTER:
	mov bx, offset r_al
	jmp CALL_MOVE_REG
	CL_REGISTER:
	mov bx, offset r_cl
	jmp CALL_MOVE_REG
	DL_REGISTER:
	mov bx, offset r_dl
	jmp CALL_MOVE_REG
	BL_REGISTER:
	mov bx, offset r_bl
	jmp CALL_MOVE_REG
	AH_REGISTER:
	mov bx, offset r_ah
	jmp CALL_MOVE_REG
	CH_REGISTER:
	mov bx, offset r_ch
	jmp CALL_MOVE_REG
	DH_REGISTER:
	mov bx, offset r_dh
	jmp CALL_MOVE_REG
	BH_REGISTER:
	mov bx, offset r_bh

	CALL_MOVE_REG:
	mov cx, 2
	call MOVE_INSTRUCTION

	pop dx
    pop cx
    pop bx
    pop ax
	RET

REGISTER ENDP

SEG_REGISTER PROC NEAR

	push ax
	push bx
	push cx
	push dx

	cmp seg_reg, 00b
	je ES_REGISTER
	cmp seg_reg, 01b
	je CS_REGISTER
	cmp seg_reg, 10b
	je SS_REGISTER
	cmp seg_reg, 11b
	je DS_REGISTER

	ES_REGISTER:
	mov bx, offset seg_es
	jmp CALL_MOVE_SEG

	CS_REGISTER:
	mov bx, offset seg_cs
	jmp CALL_MOVE_SEG

	SS_REGISTER:
	mov bx, offset seg_ss
	jmp CALL_MOVE_SEG

	DS_REGISTER:
	mov bx, offset seg_ds

	CALL_MOVE_SEG:
	mov cx, 2
	call MOVE_INSTRUCTION

	pop dx
    pop cx
    pop bx
    pop ax
	RET

SEG_REGISTER ENDP

UNDEFINED_BYTE PROC NEAR

	push ax
	push bx
	push cx
	push dx
	push si

	mov cx, 18
	call MOVE_SPACES

	mov bx, offset undefined
	mov cx, 9
	call MOVE_INSTRUCTION
	call MOVE_ENDLINE

	pop si
	pop dx
    pop cx
    pop bx
    pop ax
	RET

UNDEFINED_BYTE ENDP

MOVE_INSTRUCTION PROC NEAR

	push ax
	push bx ; parameter of this function, the offset of the instruction
	push cx ; parameter of this function, the length of the instruction
	push dx
	push si

	MOVING_INS:
	mov si, offset write_buffer
	mov di, offset write_index
	add si, write_index
	mov al, byte ptr [bx]
	mov byte ptr [si], al
	inc bx
	inc word ptr [di]
	loop MOVING_INS

	pop si
	pop dx
    pop cx
    pop bx
    pop ax
	RET

MOVE_INSTRUCTION ENDP

MOVE_BYTE PROC NEAR

	push ax
	push bx
	push cx
	push dx
	push si
	push di

	mov cx, 2
	mov bx, offset ascii_byte
	MOVING_BYTE: ; the byte is imported to the writing buffer
	mov si, offset write_buffer
	mov di, offset write_index
	add si, write_index
	mov al, byte ptr [bx]
	mov byte ptr [si], al
	inc bx
	inc word ptr [di]
	loop MOVING_BYTE

	pop di
	pop si
	pop dx
    pop cx
    pop bx
    pop ax
	RET

MOVE_BYTE ENDP

MOVE_WORD PROC NEAR

	push ax
	push bx
	push cx
	push dx
	push si
	push di

	mov al, current_byte
	cmp al, 00 ; the byte is not imported to the writing buffer if it is equal to 0
	je SKIP_00
	mov hex_byte, al
	call WRITE_HEX ; importing the higher byte to the writing buffer
	call MOVE_BYTE
	SKIP_00:
	mov al, lower_byte
	mov hex_byte, al
	call WRITE_HEX ; importing the lower byte to the writing buffer
	call MOVE_BYTE

	pop di
	pop si
	pop dx
    pop cx
    pop bx
    pop ax
	RET

MOVE_WORD ENDP

MOVE_PREFIX PROC NEAR

	push ax
	push bx
	push cx
	push dx
	push si
	push di

	cmp prefix, 26h
	je ES_PREFIX
	cmp prefix, 2Eh
	je CS_PREFIX
	cmp prefix, 36h
	je SS_PREFIX
	cmp prefix, 3Eh
	je DS_PREFIX
	jmp RET_MOVE_PREFIX ; if the prefix variable is equal to 0, return from the procedure

	ES_PREFIX:
	mov bx, offset seg_es
	jmp MOVING_PREFIX

	CS_PREFIX:
	mov bx, offset seg_cs
	jmp MOVING_PREFIX

	SS_PREFIX:
	mov bx, offset seg_ss
	jmp MOVING_PREFIX

	DS_PREFIX:
	mov bx, offset seg_ds

	MOVING_PREFIX:
	mov cx, 3
	call MOVE_INSTRUCTION ; importing the prefix to the writing buffer

	RET_MOVE_PREFIX:
	pop di
	pop si
	pop dx
    pop cx
    pop bx
    pop ax
	RET

MOVE_PREFIX ENDP

BYTE_WORD_PTR PROC NEAR ; checking whether to write "word ptr" or "byte ptr"

	cmp reg_width, 1
	je IS_WORD_PTR
	call MOVE_BYTE_PTR
	ret
	IS_WORD_PTR:
	call MOVE_WORD_PTR
	RET

BYTE_WORD_PTR ENDP	

MOVE_BYTE_PTR PROC NEAR

	push ax
	push bx
	push cx
	push dx
	push si
	push di

	mov bx, offset byte_ptr
	mov cx, 9
	MOVING_BYTE_PTR:
	mov si, offset write_buffer
	mov di, offset write_index
	add si, write_index
	mov al, byte ptr [bx]
	mov byte ptr [si], al
	inc bx
	inc word ptr [di]
	loop MOVING_BYTE_PTR

	pop di
	pop si
	pop dx
    pop cx
    pop bx
    pop ax
	RET

MOVE_BYTE_PTR ENDP

MOVE_WORD_PTR PROC NEAR

	push ax
	push bx
	push cx
	push dx
	push si
	push di

	mov bx, offset word_ptr
	mov cx, 9
	MOVING_WORD_PTR:
	mov si, offset write_buffer
	mov di, offset write_index
	add si, write_index
	mov al, byte ptr [bx]
	mov byte ptr [si], al
	inc bx
	inc word ptr [di]
	loop MOVING_WORD_PTR

	pop di
	pop si
	pop dx
    pop cx
    pop bx
    pop ax
	RET

MOVE_WORD_PTR ENDP

MOVE_SPACES PROC NEAR

	push ax
	push bx
	push cx ; parameter of this function, the amount of spaces needed to be imported to the writing buffer
	push dx
	push si

	mov si, offset write_buffer
	mov di, offset write_index
	MAKE_SPACE:
	mov bx, write_index
	mov byte ptr [bx+si], " "
	inc word ptr [di]	
	loop MAKE_SPACE

	pop si
	pop dx
    pop cx
    pop bx
    pop ax
	RET

MOVE_SPACES ENDP

MOVE_SOME_SPACES PROC NEAR

	push ax
	push bx
	push cx
	push dx

	mov al, prefix
	cmp al, 0
	jne SPACES_IS_PREF

	SPACES_NO_PREF:
	mov al, is_offset
	cmp al, 1
	je SPACES_1_OFFS
	cmp al, 2
	je SPACES_2_OFFS
	jmp SPACES_NO_OFFS
	SPACES_1_OFFS:
	mov cx, 14
	call SPACES_IS_IMM
	jmp RET_SOME_SPACES
	SPACES_2_OFFS:
	mov cx, 12
	call SPACES_IS_IMM
	jmp RET_SOME_SPACES
	SPACES_NO_OFFS:
	mov cx, 16
	call SPACES_IS_IMM
	jmp RET_SOME_SPACES

	SPACES_IS_PREF:
	mov al, is_offset
	cmp al, 1
	je SPACES_1_OFFS_P
	cmp al, 2
	je SPACES_2_OFFS_P
	jmp SPACES_NO_OFFS_P
	SPACES_1_OFFS_P:
	mov cx, 12
	call SPACES_IS_IMM
	jmp RET_SOME_SPACES
	SPACES_2_OFFS_P:
	mov cx, 10
	call SPACES_IS_IMM
	jmp RET_SOME_SPACES
	SPACES_NO_OFFS_P:
	mov cx, 14
	call SPACES_IS_IMM
	jmp RET_SOME_SPACES

	SPACES_IS_IMM:
	mov al, is_immediate
	cmp al, 1
	je SPACES_1_IMM
	cmp al, 2
	je SPACES_2_IMM
	ret
	SPACES_1_IMM:
	sub cx, 2
	ret
	SPACES_2_IMM:
	sub cx, 4
	ret

	RET_SOME_SPACES:
	call MOVE_SPACES
	pop dx
    pop cx
    pop bx
    pop ax
	RET

MOVE_SOME_SPACES ENDP

MOVE_ENDLINE PROC NEAR

	push ax
	push bx
	push cx
	push dx
	push si

	mov bx, offset endline
	mov cx, 2
	MOVING_ENDL:
	mov si, offset write_buffer
	mov di, offset write_index
	add si, write_index
	mov al, byte ptr [bx]
	mov byte ptr [si], al
	inc bx
	inc word ptr [di]
	loop MOVING_ENDL

	pop si
	pop dx
    pop cx
    pop bx
    pop ax
	RET

MOVE_ENDLINE ENDP

MOVE_COMMA PROC NEAR

	push ax
	push bx
	push cx
	push dx
	push si

	mov si, offset write_buffer
	mov di, offset write_index
	MAKE_COMMA:
	mov bx, write_index
	mov word ptr [bx+si], " ,"
	add word ptr [di], 2

	pop si
	pop dx
    pop cx
    pop bx
    pop ax
	RET

MOVE_COMMA ENDP

MOVE_SYMBOL PROC NEAR

	push ax
	push bx ; parameter of this function, the offset of the symbol wanted to be written to the writing buffer
	push cx
	push dx
	push si

	mov si, offset write_buffer
	mov di, offset write_index
	add si, write_index
	mov al, byte ptr [bx]
	mov byte ptr [si], al
	inc word ptr [di]

	pop si
	pop dx
    pop cx
    pop bx
    pop ax
	RET

MOVE_SYMBOL ENDP

WRITE_FILE PROC NEAR
	
	push ax
	push bx
	push cx
	push dx

	mov ah, 40h
	mov bx, output_handle ; the descriptor of the output file
	mov cx, write_index
	mov dx, offset write_buffer
	int 21h
	jnc RET_WRITE
	
	mov ah, 9
	mov dx, offset error_5
	int 21h
    jmp ENDING
    
    RET_WRITE:
    mov write_index, 6
    pop dx
    pop cx
    pop bx
    pop ax
	RET

WRITE_FILE ENDP

CLOSE_FILE PROC NEAR
    
    push ax
	push bx
	push dx

    mov ah, 3Eh
	mov bx, input_handle
	int 21h
	jnc RET_CLOSE
    
    mov ah, 9
	mov dx, offset error_6
	int 21h
    jmp ENDING
    
    RET_CLOSE:
    pop dx
    pop bx
    pop ax
	RET
    
CLOSE_FILE ENDP

END

# x86 disassembler

A x86 disassembler which disassebles the main 8086/8088 instructions. These include:

	* All MOV instructions
	* All PUSH instructions
	* All POP instructions
	* All ADD instructions
	* All SUB instructions
	* All INC instructions
	* All DEC instructions
	* All CMP instructions
	* MUL instruction
	* DIV instruction
	* LOOP instruction
	* All CALL instructions
	* All RET instructions
	* All JMP instructions
	* All conditional jump instructions
	* All INT instructions

## How to run the program

Use the Turbo Assembler compiler (TASM) to compile the program.
The executable file should be run with the name of an input file as a parameter:

	disasm.exe [input_file]
	
The program's output is a file named `res.txt` containing disassembled instructions.

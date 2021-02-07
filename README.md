# x86 disassembler

*This program has been written as an optional project during the first semester of the Software Engineering degree in Vilnius University.*

A program written in x86 assembly which disassembles the main 8086/8088 assembly instructions. 

The disassembled instructions include:

	* All MOV instructions
	* All PUSH instructions
	* All POP instructions
	* All ADD instructions
	* All SUB instructions
	* All INC instructions
	* All DEC instructions
	* All CMP instructions
	* All CALL instructions
	* All RET instructions
	* All JMP instructions
	* All conditional jump instructions
	* All INT instructions
	* MUL instruction
	* DIV instruction
	* LOOP instruction

## How to run the program

Compile the code in the *DOSBox emulator* by using the *Turbo Assembler (TASM)*. This should be done by assembling and linking with *TASM* tools. The following lines should be entered to produce the executable:

	tasm disasm
	tlink disasm

Run the program with an input file which has a `.com` suffix:

	disasm [input_file.com]
	
The program will disassemble the instructions in your given `input_file.com` and produce a `res.txt` containing the disassembled instructions.

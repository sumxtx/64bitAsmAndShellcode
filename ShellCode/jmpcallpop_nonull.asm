section .text
global _start
_start:
	jmp one 

shellcode:

	; Put string string to print from stack into the rsi
	pop rsi

	; Move Syscall = 1
	;mov rax,1
	xor rax,rax     ; eliminate nulls
	add rax,0x1        ;

	; Move fd = stdout = 1
	;mov rdi,1
	xor rdi,rdi     ; eliminate nulls
	add rdi,0x1       ;


	; Move length = 12
	;mov rdx,12
	xor rdx, rdx    ; eliminate nulls
	add rdx,0xc      ;
	syscall

	; exit (avoid segfault)
	xor rax,rax     ;eliminate nulls
	mov al,60       ; exit syscall
	xor rdi,rdi     
	syscall 

one:
	call shellcode
	string_msg: db "Hello world",0xa ;;Hello world\n\0

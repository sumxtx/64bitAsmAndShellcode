section .text
global _start
_start:
    jmp one 

shellcode:
    pop rsi
    mov rax,1
    mov rdi,1
    mov rdx,12
    syscall

one:
call shellcode
string_msg: db "Hello world", 0xa
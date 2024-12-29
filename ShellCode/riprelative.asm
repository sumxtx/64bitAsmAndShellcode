section .text

global _start

_start:
    mov rax,1
    mov rdi,1
    lea rsi,[rel hello_world]
    mov rdx,12
    syscall


    mov rax,60
    mov rdi,0
    syscall
    
    hello_world: db "Hello World",0xa


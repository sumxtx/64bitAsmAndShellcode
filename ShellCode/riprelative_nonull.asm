section .text

global _start

_start:

    jmp shellcode

    hello_world: db "Hello World",0xa

shellcode:
    xor rax,rax
    mov al,1

    xor rdi,rdi
    add rdi,1

    lea rsi,[rel hello_world]
    xor rdx,rdx
    add rdx,12
    syscall

    xor rax,rax
    add rax,0x3c
    xor rdi,rdi
    syscall
    


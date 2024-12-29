;int execve(const char *filename, char *const argv[], char *const envp[])
;      59          rdi,binary              rsi                 rdx

section .data
binary_file: db "/bin/sh", 0
section .text
global _start
_start:
    mov rax,59
    mov rdi,binary_file
    mov rsi,0
    mov rdx,0
    syscall


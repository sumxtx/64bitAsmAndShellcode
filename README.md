## Steps To creating a Shellcode

#### 0. If the code is in C, Compile to a .o file. If written in Assembly compile the code into .o.
#### 1. Extract the Assembly code from the .o file with objdump.
#### 2. Modify the Assembly code to remove nullbytes (null bytes breaks shellcode execution).
- Ex: 
    ```asm
    mov rax,60
    mov rdi,0
    syscall
    ```
- To:
    ```asm
    xor rax,rax
    mov al,60
    xor rdi,rdi
    syscall
    ```
#### 3. In Case of modifying repeat steps 1 and 2
#### 4. Extract the shellcode from the Assembly code in hexadecimal
- Ex:
    `0:b8 3c     mov eax,0x3c                ->   \xb8\x3c`
#### 5. Create the C Code program to launch the shellcode
- Ex:
```c
usigned char code[] = "\x48\x31\xc0\xb0\x3c\x48\x31\xff\x0f\x05";
int main()
{
    int (*ret)() = (int(*)())code;
    ret();
}
```
#### 6. Compile the code with no stack protection

## Diving in
### Nasm an Yasm
Nasm may modify the code so it uses 32bit registers for example using eax,edi instead of rax,rdi

```
            objdump -d exit.o -M intel

            exit.o:     file format elf64-x86-64


Disassembly of section .text:

0000000000000000 <_start>:
   0:   b8 3c 00 00 00          mov    eax,0x3c
   5:   bf 00 00 00 00          mov    edi,0x0
   a:   0f 05                   syscall
```
Yasm preserves the use of 64bit registers
```
objdump -d exit_yasm.o -M intel

exit_yasm.o:     file format elf64-x86-64


Disassembly of section .text:

0000000000000000 <_start>:
   0:   48 c7 c0 3c 00 00 00    mov    rax,0x3c
   7:   48 c7 c7 00 00 00 00    mov    rdi,0x0
   e:   0f 05                   syscall
```
Why the Difference Exists:

- ABI Convention: 

Both assemblers are targeting the x86-64 architecture. But they are following different conventions or configurations regarding which registers to use. While the 64-bit rax and rdi registers are standard for modern system calls in x86-64 Linux NASM might default to using 32-bit registers for simplicity or backwards compatibility in certain cases.  

- Assembler Defaults:  

NASM might use 32-bit registers for system calls because it’s treating the system call number as a 32-bit value in the ABI. On the other hand, YASM might automatically use 64-bit registers as per the standard 64-bit Linux ABI.  

Conclusion:

The differences are mainly due to the different register conventions followed by nasm and yasm. nasm uses 32-bit registers by default (even in 64-bit mode), while yasm uses 64-bit registers. Both versions still achieve the same result when run on an x86-64 machine, as the Linux kernel ABI for system calls expects the same behavior, but they use different conventions for the register sizes.  


### Removing Null bytes from the code

If we notice on the dump above there are a few padding null bytes (00 00 00). These null bytes in interaction with C later on, may break the execution of our shell code. For that we need to remove them from our code. If we notice above, this code doesn't have any null padding character.  

> Here is an extensive [list of techniques](#obfuscating-shellcode-techniques) used to remove or bypass null bytes in shellcode.  
```
objdump -d exit_nonull.o -M intel

exit_nonull.o:     file format elf64-x86-64


Disassembly of section .text:

0000000000000000 <_start>:
   0:   48 31 c0                xor    rax,rax
   3:   b0 3c                   mov    al,0x3c
   5:   48 31 ff                xor    rdi,rdi
   8:   0f 05                   syscall
```

### Extracting the opcode in hex format 

The Opcode would be ->
    \x48\x31\xc0\xb0\x3c\x48\x31\xff\x0f\x05

### Creating the C program to execute the shellcode


The Opcode launcher would be
```c
    usigned char code[] = "\x48\x31\xc0\xb0\x3c\x48\x31\xff\x0f\x05";
    int main()
    {
        printf("Shellcode Length: %d\n", (int)strlen(code));
        int (*ret)() = (int(*)())code;
        ret();
    }
```

Let's break down the line:

```c
int (*ret)() = (int(*)())code;
```

This is a somewhat advanced C construct, 
so it's helpful to understand the components of it one by one. 
I'll explain each part, and then how it all fits together.

##### 1. **`int (*ret)()`**: 
This declares a **function pointer**.

- `int`: This is the return type of the function the pointer will point to. In this case, the function is expected to return an `int`.
- `(*ret)`: This means `ret` is a pointer to a function. In C, a function pointer is declared using `(*pointer_name)`.
- `()` after `(*ret)` means that the function pointer `ret` points to a function that **takes no arguments**. So, the signature of the function `ret` points to is: `int func(void)`.

So, at this point, `ret` is a pointer to a function that returns `int` and takes no arguments.

##### 2. **`(int(*)())code;`**: 
This is a **cast**. It's casting `code` (which is a `char[]`) into a function pointer type (`int(*)()`).

- `code`: In the context of this example, `code` is an array of characters, i.e., `char code[] = "";`. However, this is just a placeholder in your code snippet; `code` could contain raw byte values (machine code instructions), so treating it as function code could be meaningful in low-level, self-modifying, or dynamically-generated code contexts.
- `(int(*)())`: This is a **type cast** that converts `code` into a pointer to a function that returns `int` and takes no arguments. Specifically, `code` is being treated as a pointer to a function that takes no arguments and returns an integer. This is important because C does not allow you to directly cast a `char*` to a function pointer without specifying the desired function signature.
  - `int(*)()` indicates the function signature you're casting `code` to: a function returning `int` with no arguments.

##### 3. **Putting It All Together**:
The full line of code:

```c
int (*ret)() = (int(*)())code;
```

This line does the following:
- **`ret`** is declared as a pointer to a function that returns an `int` and takes no parameters (`int (*ret)()`).
- **`code`** (a `char[]` or `char*`) is cast into a function pointer (`int(*)()`) — specifically, a function that returns an `int` and takes no arguments.
- This means that `ret` now points to whatever address `code` holds. If `code` contains executable machine code at that address (e.g., raw bytes of a function), `ret()` can be called as a function.

##### 4. **What Happens When You Call `ret()`**:
```c
ret();
```
This line calls the function pointed to by `ret`. Since `ret` now points to the start of `code` (which is treated as a function), it attempts to execute whatever machine code is stored at that address.

##### Important Notes:
- If `code` contains valid machine code (i.e., valid executable instructions), calling `ret()` will execute it.
- The `code` array is currently empty (`""`), so this would likely cause an error or unexpected behavior because `ret` is trying to execute code at a location that is empty (null byte). However, in real usage, `code` would typically contain some form of binary data (e.g., machine code of a function).
  
##### Example Use Case:
This technique is often used in **self-modifying code** or **dynamic code execution**, where a program dynamically generates code (such as a byte sequence representing machine code) and executes it at runtime. It's a low-level operation, and it's not commonly used in high-level programming because it is platform-dependent and can lead to security vulnerabilities (e.g., code injection).

##### A Realistic Example (with Code):

If you had a small piece of machine code stored in `code`, for example:

```c
unsigned char code[] = {
    0xC3  // This is the `RET` instruction in x86, which simply returns from a function.
};
```

You could then cast `code` to a function pointer and execute it:

```c
int (*ret)() = (int(*)())code;
ret();  // This will execute the RET instruction, which returns control to the caller.
```

In this case, `code` contains the machine code for a `RET` instruction (in x86 architecture). Calling `ret()` would effectively return from the current function.

##### Summary:

- `int (*ret)()`: Declares a function pointer `ret` that points to a function that takes no arguments and returns an `int`.
- `(int(*)())code`: Casts `code` (which is a `char[]`) to a function pointer type `int (*)()`, i.e., a function that returns `int` and takes no arguments.
- `ret()`: Calls the function pointed to by `ret`, which is the byte sequence in `code`, executing it as machine code.

This is a form of **dynamic function execution** using raw bytecode, which can be powerful but requires careful handling to avoid errors or security risks.


### Compiling the code without stack protection
The compiplation command would be
```bash
gcc -fno-stack-protector -z execstack source.c -o exit
```

### Deepin in assembly
In the instruction 48 31 c0, the 48 is a prefix byte, and 31 c0 is the actual opcode. Here's a breakdown:

    48: This is a Rex prefix, which is used in 64-bit mode to extend operand sizes or registers. In this case, it indicates that the instruction is operating on 64-bit registers.

    31 c0: This is the actual opcode for the xor instruction. In particular:
        31 represents the xor operation between two registers.
        c0 specifies that the xor is being performed between the rax register and itself (rax ^ rax).

So, 48 31 c0 corresponds to the instruction:

xor rax, rax

Which effectively clears the rax register (sets it to zero) because any value XORed with itself results in zero.

You said:
how is possible only c0 means that
ChatGPT said:
ChatGPT

Great question! The byte 0xC0 in the instruction 31 C0 is a specific encoding for the xor operation in x86-64 assembly. Let's break down why C0 represents xor rax, rax in this context:
The Instruction Format

The 31 opcode represents the XOR r/m32, r32 operation, which means that it performs a bitwise XOR between two operands: a register (r32) and a memory location or a register (r/m32).

The mod-reg-r/m byte structure in x86 instructions determines how operands are encoded. The breakdown is as follows:

    31 (opcode):
        31 is the XOR opcode for register to register operations (with 32-bit operands, but extended to 64-bit in this case due to the REX prefix 48).

    C0 (mod-reg-r/m byte):

        The byte C0 is actually a combination of the mod-reg-r/m encoding for the operands. Let's decode it step by step:
            C0 in binary is 1100 0000.

        Now let's break it into the relevant parts:
            mod (the first 2 bits): 11 → This indicates a direct register-to-register operation (i.e., no memory operand, both operands are registers).
            reg (the next 3 bits): 000 → This specifies the register to perform the operation on. In this case, it is the EAX register, which is extended to RAX in 64-bit mode.
            rm (the last 3 bits): 000 → This also specifies that the second operand is EAX, and in 64-bit mode, it is RAX.

        Together, mod-reg-r/m = 1100 0000 means that the operation is XOR rax, rax.

Why does C0 mean rax, rax?

    In 64-bit mode, when you see 31 C0, it corresponds to XOR rax, rax because:
        The 31 opcode specifies the XOR operation between two registers.
        The C0 byte specifies that the first operand is rax (since reg = 000) and the second operand is also rax (since rm = 000).

Recap:

    31: The opcode for the XOR operation between two registers.
    C0: The mod-reg-r/m byte that encodes the specific registers involved (in this case, both rax).

So, 48 31 C0 translates to the instruction xor rax, rax, which clears the rax register.

This is how it works under the hood in the x86-64 instruction set.
The information I provided comes from an understanding of the **x86-64 architecture**, the **x86 instruction set**, and **Intel/AMD assembly syntax**. These topics are covered in depth in a number of classic and modern texts that deal with computer architecture, assembly language, and low-level programming.

To further explore these concepts, I recommend the following books that provide comprehensive and reliable information about x86 assembly, instruction encoding, and the internal workings of CPUs like Intel and AMD:

### Recommended Books:

1. **"The Art of Assembly Language" by Randall Hyde**
   - **Focus**: This is a great book for learning assembly language, covering both x86 and x86-64 architectures. Hyde explains assembly syntax, opcodes, and how they map to machine instructions.
   - **Why it's good**: The book starts from the fundamentals and goes into detail about how instructions are encoded, what different prefixes mean, and how to write low-level code efficiently.
   - [Link to the book](https://www.amazon.com/Art-Assembly-Language-2nd/dp/1593272073)

2. **"Programming from the Ground Up" by Jonathan Bartlett**
   - **Focus**: This book is aimed at teaching how to program using assembly language. It's particularly good for understanding the relationship between assembly and high-level languages, and includes a solid section on x86 assembly and the Linux system.
   - **Why it's good**: The book provides both theoretical insights and practical examples, making it approachable for beginners while also being deep enough for more advanced programmers.
   - [Link to the book](https://www.amazon.com/Programming-Ground-Up-2nd-Edition/dp/0982102641)

3. **"Intel® 64 and IA-32 Architectures Software Developer’s Manual" (Volumes 1–3)**
   - **Focus**: This is the official manual published by Intel and is the most authoritative source on the Intel architecture. It provides detailed explanations of the instruction set, including opcodes, instruction formats, and internal processor details.
   - **Why it's good**: It's an exhaustive, reference-style resource directly from Intel, covering everything from the most basic instructions to the more advanced features of the x86 and x86-64 architectures.
   - [Intel's Documentation Portal](https://www.intel.com/content/www/us/en/developer/quick-links/software-development-manuals.html)

4. **"The x86-64 Architecture and Assembly Language Programming" by Richard E. Haskell**
   - **Focus**: This book provides an in-depth look at the x86-64 architecture and its instruction set. It covers key concepts like registers, the stack, calling conventions, and more. The text includes practical examples and exercises.
   - **Why it's good**: It focuses specifically on x86-64 and provides a well-rounded approach to assembly programming, with a good balance between theory and practice.
   - [Link to the book](https://www.amazon.com/x86-64-Architecture-Assembly-Language-Programming/dp/0132979349)

5. **"Computer Systems: A Programmer’s Perspective" by Randal E. Bryant and David R. O'Hallaron**
   - **Focus**: This is a widely recommended textbook for understanding low-level programming and computer systems, including assembly language. It introduces concepts like memory layout, machine-level representation of data, and the interaction between hardware and software.
   - **Why it's good**: The book is very detailed and helps readers understand how computer systems work from the ground up, with a focus on x86 and x86-64 assembly in the later chapters.
   - [Link to the book](https://www.amazon.com/Computer-Systems-Programmers-Perspective-3rd/dp/013409266X)

6. **"The Intel Microprocessors" by Barry B. Brey**
   - **Focus**: This book is focused on Intel processors and is very good for understanding the architecture, instruction set, and assembly programming at a deeper level. It also covers both 32-bit and 64-bit x86 architecture.
   - **Why it's good**: Brey's book is clear and detailed, making it an excellent resource for both learning assembly and getting an in-depth understanding of Intel microprocessor internals.
   - [Link to the book](https://www.amazon.com/Intel-Microprocessors-Architecture-Programming-Design/dp/0131453481)

7. **"PC Assembly Language" by Paul A. Carter**
   - **Focus**: This book is a comprehensive guide to x86 assembly programming and is available for free online. It includes explanations of opcodes, registers, and the x86-64 architecture. It's geared towards practical examples and real-world coding.
   - **Why it's good**: This book is freely available online and is a great entry point for anyone who wants to learn x86 assembly in an accessible way.
   - [Free version online](https://pacman128.github.io/pcasm/)

### For In-Depth Learning of x86-64 Encoding:

- **"The Art of Compiler Design" by Thomas Pittman and James Peters**
  - This book explores how compilers generate assembly code and works hand-in-hand with understanding machine-level instruction formats, including encoding schemes.
  - [Link to the book](https://www.amazon.com/Art-Compiler-Design-Programming-Languages/dp/0133780915)

- **"The CPU Architecture and Instruction Set" by Erich B. Sturgis**
  - This text explores how CPUs decode and execute instructions, providing more context on how encoding schemes like the "mod-reg-r/m" byte work.

### Online Resources:

- **Agner Fog's Optimization Manuals**: These manuals go into depth on how CPU instruction sets work, and the details of how instructions are encoded on the x86 architecture. Agner Fog is an expert in optimization and low-level CPU details.
  - [Agner Fog's site](https://www.agner.org/optimize/)

- **x86 Opcode Chart**: An invaluable resource to look up specific instructions and their encodings.
  - [x86 Opcode Chart](https://www.felixcloutier.com/x86/)

---

These books and resources should help you gain a deep understanding of assembly language and the internals of the x86-64 architecture, including instruction encoding like the `mod-reg-r/m` format I discussed earlier. Let me know if you want more recommendations or details on any of these!

### Obfuscating ShellCode Techniques
1. **Encoding the shellcode** (e.g., base64, URL encoding)
2. **Using multi-stage shellcode** (splitting the shellcode into parts and concatenating at runtime)
3. **Using `NOP` sleds (NOPs)** and custom padding techniques
4. **Polymorphism** (changing the shellcode’s appearance without altering its functionality)
5. **Shellcode obfuscation** (e.g., XOR encryption, AES encryption, etc.)
6. **Dynamic resolution of addresses** (via API calls or runtime analysis)
7. **Jumping over null bytes** (using conditional jumps, `jmp`, or `call` instructions)
8. **Using `POP` and `PUSH` instructions** (to load values or manipulate execution flow)
9. **ROP (Return-Oriented Programming)** (reusing existing code in the binary to execute payloads)
10. **Using indirect function calls or address loading** (e.g., using registers instead of direct addresses)
11. **Using custom shellcode formats** (e.g., custom encodings like `xor` encoding)
12. **Using non-null terminator characters** (replacing null with another byte or pattern during encoding)
13. **Combining multiple shellcodes** (splitting and reassembling using custom code)
14. **Shellcode compression** (e.g., using zlib or other compression methods)
15. **In-memory decryption and execution** (decrypting shellcode in memory before execution)
16. **API chaining** (calling multiple functions sequentially to bypass limitations)
17. **Stack pivoting** (redirecting the execution flow to shellcode in the stack or heap)
18. **Shellcode chaining** (linking multiple small payloads together with no null bytes)
19. **Heap spray** (allocating heap memory to execute shellcode)
20. **Using syscall wrappers** (avoiding direct syscalls that might be affected by null byte filters)
21. **Using function pointer tables or VTABLEs** (to execute shellcode indirectly through function pointers)
22. **Shellcode segmentation** (splitting shellcode into multiple segments to avoid null bytes in any one part)
23. **Memory mapping** (using techniques like `mmap` to load shellcode from a file or memory segment)
24. **Hexadecimal or ASCII encoding** (using hexadecimal escape sequences or ASCII values instead of null bytes)
25. **Self-modifying code** (altering the shellcode at runtime to eliminate null bytes)
26. **Using custom memory regions** (e.g., changing execution location to avoid null-byte-sensitive regions)
27. **Anti-null byte filtering bypass** (creating shellcode specifically designed to avoid detection)
28. **Function address randomization** (bypassing address randomization that could affect shellcode)
29. **Using memory subregions or sections** (dividing payload across different memory locations)
30. **Crafting shellcode with alternative instruction sets** (using different instruction encoding schemes to avoid null bytes in shellcode)

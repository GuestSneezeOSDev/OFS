
[bits 32]
[extern kernel_main]

section .text
global start

start:
    cli
    cld
    mov ax, 0x10       
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000   

    call kernel_main   

.halt:
    hlt               
    jmp .halt         

# OFS Project

# 1.0 Minimal OS
The first thing we need is a Cross-Compiler for our operating system set up a Cross-Compiler for `i686-elf`(64 bit)[1](https://wiki.osdev.org/Bare_Bones#Building_a_Cross-Compiler)
### 1.1 Minimal OS : Bootstrap
we will use `NASM`[2](https://www.nasm.us/) as the main compiler for our os create a file called `boot.s`  with the following code
```assembly
.set ALIGN,    1<<0
.set MEMINFO,  1<<1
.set FLAGS,    ALIGN | MEMINFO
.set MAGIC,    0x1BADB002
.set CHECKSUM, -(MAGIC + FLAGS)

.section .multiboot
.align 4
.long MAGIC
.long FLAGS
.long CHECKSUM

.section .bss
.align 16
stack_bottom:
.skip 16384
stack_top:

.section .text
.global _start
.type _start, @function
_start:
	mov $stack_top, %esp
	call kernel_main
	cli
1:	hlt
	jmp 1b

.size _start, . - _start
```
now assemble it using the following command
```
nasm -f elf32 boot.s -o boot.o
```
Now we have finished configuring our bootloader from scratch now we will work on our kernel
## 1.2 Minimal OS : Kernel
Write a **basic** kernel in C (not unix-like)
here is a basic code snippet for linux build process
```C
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#if defined(__linux__)
#error "Use a cross-compiler"
#endif
#if !defined(__i386__)
#error "THIS ONLY WORKS WITH i686-based machines ONLY NOT WITH 32 BIT"
#endif

enum vga_color {
	VGA_COLOR_BLACK = 0,
	VGA_COLOR_BLUE = 1,
	VGA_COLOR_GREEN = 2,
	VGA_COLOR_CYAN = 3,
	VGA_COLOR_RED = 4,
	VGA_COLOR_MAGENTA = 5,
	VGA_COLOR_BROWN = 6,
	VGA_COLOR_LIGHT_GREY = 7,
	VGA_COLOR_DARK_GREY = 8,
	VGA_COLOR_LIGHT_BLUE = 9,
	VGA_COLOR_LIGHT_GREEN = 10,
	VGA_COLOR_LIGHT_CYAN = 11,
	VGA_COLOR_LIGHT_RED = 12,
	VGA_COLOR_LIGHT_MAGENTA = 13,
	VGA_COLOR_LIGHT_BROWN = 14,
	VGA_COLOR_WHITE = 15,
};

static inline uint8_t vga_entry_color(enum vga_color fg, enum vga_color bg) 
{
	return fg | bg << 4;
}

static inline uint16_t vga_entry(unsigned char uc, uint8_t color) 
{
	return (uint16_t) uc | (uint16_t) color << 8;
}

size_t strlen(const char* str) 
{
	size_t len = 0;
	while (str[len])
		len++;
	return len;
}

static const size_t VGA_WIDTH = 80;
static const size_t VGA_HEIGHT = 25;

size_t terminal_row;
size_t terminal_column;
uint8_t terminal_color;
uint16_t* terminal_buffer;

void terminal_initialize(void) 
{
	terminal_row = 0;
	terminal_column = 0;
	terminal_color = vga_entry_color(VGA_COLOR_LIGHT_GREY, VGA_COLOR_BLACK);
	terminal_buffer = (uint16_t*) 0xB8000;
	for (size_t y = 0; y < VGA_HEIGHT; y++) {
		for (size_t x = 0; x < VGA_WIDTH; x++) {
			const size_t index = y * VGA_WIDTH + x;
			terminal_buffer[index] = vga_entry(' ', terminal_color);
		}
	}
}

void terminal_setcolor(uint8_t color) 
{
	terminal_color = color;
}

void terminal_putentryat(char c, uint8_t color, size_t x, size_t y) 
{
	const size_t index = y * VGA_WIDTH + x;
	terminal_buffer[index] = vga_entry(c, color);
}

void terminal_putchar(char c) 
{
	terminal_putentryat(c, terminal_color, terminal_column, terminal_row);
	if (++terminal_column == VGA_WIDTH) {
		terminal_column = 0;
		if (++terminal_row == VGA_HEIGHT)
			terminal_row = 0;
	}
}

void terminal_write(const char* data, size_t size) 
{
	for (size_t i = 0; i < size; i++)
		terminal_putchar(data[i]);
}

void terminal_writestring(const char* data) 
{
	terminal_write(data, strlen(data));
}

void kernel_main(void) 
{
	terminal_initialize();

	terminal_writestring("Welcome to my OFS based OS!\n");
}
```
save it as kernel.c and compile it using the following command
```
i686-elf-gcc -c kernel.c -o kernel.o -std=gnu99 -ffreestanding -O2 -Wall -Wextra
```
you can write it in C++ aswell but i am too lazy to code an example and if you did create a kernel using C++ please use the following command
```
i686-elf-g++ -c kernel.c++ -o kernel.o -ffreestanding -O2 -Wall -Wextra -fno-exceptions -fno-rtti
```
now we need to link the kernel so create a file with the following code named `linker.ld` and put the following code in that file
```
ENTRY(_start)

SECTIONS
{
	. = 2M;

	.text BLOCK(4K) : ALIGN(4K)
	{
		*(.multiboot)
		*(.text)
	}

	.rodata BLOCK(4K) : ALIGN(4K)
	{
		*(.rodata)
	}

	.data BLOCK(4K) : ALIGN(4K)
	{
		*(.data)
	}

	.bss BLOCK(4K) : ALIGN(4K)
	{
		*(COMMON)
		*(.bss)
	}
}
```
we can compile it using the following command
```
i686-elf-gcc -T linker.ld -o os.bin -ffreestanding -O2 -nostdlib boot.o kernel.o -lgcc
```
## 1.3 Minimal OS : Multiboot
Verify that multiboot is installed in your OS
```
if grub-file --is-x86-multiboot os.bin; then
  echo multiboot confirmed
else
  echo the file is not multiboot
fi
```
## Minimal OS : Booting into the Operating System
We will build a bootable image (ISO) you can easily create it by using [`xorriso`](https://www.gnu.org/software/xorriso/) but first create a `grub.cfg` with the following code
```
menuentry "os" {
	multiboot /boot/os.bin
}
```
create a buildable version of your OS by using the following commands
```
mkdir -p iso/boot/grub
cp os.bin iso/boot/os.bin
cp grub.cfg iso/boot/grub/grub.cfg
grub-mkrescue -o os.iso iso/
```
Congrats! You have created an iso containg your `Welcome to my OFS-based OS` motd
you can boot your OS by using QEMU
```
qemu-system-i386 -cdrom os.iso
```
you can also boot the kernel from QEMU
```
qemu-system-i386 -kernel os.bin
```
## 2.0 Building a simple UNIX-like Operating System
Here is an overview of the directory structure of the source code the code here is based off my own kernel [neutrox](https://github.com/GuestSneezeOSDev/Neutrox-Kernel)
**IMPORTANT** This is a 32-bit OS not a 64-bit OS
```
src/
    makefile
    kernel.c
    kernel_entry.asm
boot/grub
    grub.cfg
build.sh
```
## 2.1 Building a simple UNIX-like Operating System : Kernel Development
create a new Makefile in the kernel directory and in the Makefile paste the following code
```makefile
TARGET = ../boot/kernel.bin

ASM_SOURCES = kernel_entry.asm
C_SOURCES = kernel.c

ASM_OBJECTS = $(ASM_SOURCES:.asm=.o)
C_OBJECTS = $(C_SOURCES:.c=.o)

CC = gcc
LD = ld
ASM = nasm
CFLAGS = -m32 -ffreestanding -nostdlib -nostartfiles -nodefaultlibs -Wall -Wextra
LDFLAGS = -m elf_i386 -Ttext 0x1000 --oformat binary

all: $(TARGET)

$(TARGET): $(ASM_OBJECTS) $(C_OBJECTS)
	$(LD) $(LDFLAGS) -o $(TARGET) $(ASM_OBJECTS) $(C_OBJECTS)

%.o: %.asm
	$(ASM) -f elf32 $< -o $@

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f *.o $(TARGET)

.PHONY: all clean
```
Now create a file called `kernel.c` with the following contents
```C
#include <stdint.h>
#include <stddef.h>

#define KERNEL_STACK_SIZE 8192

extern void load_initramfs(void);
extern int execve(const char *filename, char *const argv[], char *const envp[]);
extern void switch_to_user_mode(void);
extern void panic(const char *message);
extern void printf(const char *format, ...);

void vga_puts(const char *str) {
    volatile char *video = (volatile char*)0xB8000;
    while (*str) {
        *video++ = *str++;
        *video++ = 0x07; 
    }
}

void kernel_main() {
    vga_puts("Kernel started...\n");

    load_initramfs();

    const char *argv[] = {"/sbin/init", NULL};
    const char *envp[] = {"HOME=/", "PATH=/bin:/sbin", NULL};

    int ret = execve("/sbin/init", (char *const *)argv, (char *const *)envp);
    if (ret < 0) {
        panic("Failed to exec /sbin/init");
    }

    while (1) {
        __asm__ __volatile__("hlt");
    }
}


void panic(const char *message) {
    vga_puts("PANIC: ");
    vga_puts(message);
    while (1) {
        __asm__ __volatile__("hlt");
    }
}

int execve(const char *filename, char *const argv[], char *const envp[]) {
    switch_to_user_mode();  
    return -1; 
}

void load_initramfs() {
    vga_puts("Initramfs loaded...\n");
}

void switch_to_user_mode() {
    __asm__ __volatile__(
        "cli;"
        "mov $0x23, %ax;"
        "mov %ax, %ds;"
        "mov %ax, %es;"
        "mov %ax, %fs;"
        "mov %ax, %gs;"
        "mov %esp, %eax;"
        "pushl $0x23;"  
        "pushl %eax;"   
        "pushf;"        
        "pop %eax;"
        "or $0x200, %eax;" 
        "push %eax;"
        "pushl $0x1B;"  
        "push $1f;"     
        "iret;"
        "1:"  
    );
}
```
Now in `kernel_entry.asm` paste the following code
```
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
```

## 2.2 Building a simple UNIX-like Operating System : Bootloader
now go back a directory (the directory before src/) create two directories with the following command
```
mkdir -p boot/grub
cd boot/grub
```
now create a `grub.cfg`
```
menuentry "OS" {
    multiboot /boot/kernel.bin
    module /boot/initramfs.cpio.gz
}
```
## 2.3 Building a simple UNIX-like Operating System : Compilimation
now go back two directories by using `cd .../...` and create a file called `build.sh`
<br>
now in the build.sh we need a user-space a popular one is busybox[3](https://busybox.net/) paste the following code in the build.sh file
```shell
echo "Installing User-space..."
cd ~/
wget https://busybox.net/downloads/busybox-1.36.1.tar.bz2
tar xjf busybox-1.36.1.tar.bz2
cd busybox-1.36.1
mkdir -p ~/rootfs/{bin,sbin,etc,proc,sys}
cp ~/busybox ~/rootfs/bin/
cd rootfs/bin && ln -s busybox sh && ln -s busybox init
echo "Installing Userspace... Completed
Creating Initial Ramdisk..."
cd ..
find . | cpio -o --format=newc | gzip > ../initramfs.cpio.gz
echo "Creating Initial Ramdisk... Completed"
cd ..
cp -r initramfs.cpio.gz ~/boot/
echo "Compiling Kernel..."
cd ~/src/
make -j $(nproc)
echo "Compiling Kernel... Completed"
mkdir iso
mv boot/ src/ iso/
grub-mkrescue -o os.iso iso/
```
now run the build.sh and watch the magic happen

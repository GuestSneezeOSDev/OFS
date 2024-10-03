# OFS Project

# Minimal OS
The first thing we need is a Cross-Compiler for our operating system set up a Cross-Compiler for `i686-elf`(64 bit)[1](https://wiki.osdev.org/Bare_Bones#Building_a_Cross-Compiler)
### Minimal OS : Bootstrap
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
## Minimal OS : Kernel
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
## Minimal OS : Multiboot
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
## Full OS
Coming soon

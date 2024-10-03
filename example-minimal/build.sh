#!/bin/bash
nasm -f elf32 boot.s -o boot.o
i686-elf-gcc -c kernel.c -o kernel.o -std=gnu99 -ffreestanding -O2 -Wall -Wextra
i686-elf-gcc -T linker.ld -o os.bin -ffreestanding -O2 -nostdlib boot.o kernel.o -lgcc
if grub-file --is-x86-multiboot os.bin; then
  echo multiboot confirmed
else
  echo the file is not multiboot
fi
mkdir -p iso/boot/grub
cp os.bin iso/boot/os.bin
cp grub.cfg iso/boot/grub/grub.cfg
grub-mkrescue -o os.iso iso/
qemu-system-i386 -cdrom os.iso

if [[ "${osbuilder}" == "unix"]] then
  echo "building Unix-like OS"
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
  echo "Unix-like OS has been compiled"

elif [["${osbuilder}" == "minimal"]] then
  nasm -f elf32 minimal/boot.s -o boot.o
  i686-elf-gcc -c minimal/kernel.c -o kernel.o -std=gnu99 -ffreestanding -O2 -Wall -Wextra
  i686-elf-gcc -T minimal/linker.ld -o os.bin -ffreestanding -O2 -nostdlib boot.o kernel.o -lgcc
  if grub-file --is-x86-multiboot os.bin; then
    echo "multiboot confirmed"
  else
    echo "the file is not multiboot"
  fi
  mkdir -p iso/boot/grub
  cp os.bin iso/boot/os.bin
  cp minimal/grub.cfg iso/boot/grub/grub.cfg
  grub-mkrescue -o os.iso iso/
  qemu-system-i386 -cdrom os.iso
  echo "MinimalOS Completed"

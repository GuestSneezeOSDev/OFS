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

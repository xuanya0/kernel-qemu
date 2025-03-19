# fedora-custom-kernel-qemu (kinda broken with mismatching kernel and initramfs)

# prep
* download and install fedora with libvirt like you normally do
* get your kernel build version: uname -a
* get your kernel cmdline from /proc/cmdline
* copy out to the host /boot/config-$(uname -r) and /boot/initramfs-$(uname -r).img


## kernel config
copy your config from the VM to your workspace/.config
set this version to match release version like this, in order for kernel to find modules from initramfs
* CONFIG_LOCALVERSION="-200.fc36.x86_64"

adjust the following in order not to prevent loading modules
* CONFIG_SECURITY_LOCKDOWN_LSM=n
* CONFIG_MODULE_SIG=n
* CONFIG_MODULE_ALLOW_BTF_MISMATCH=y

## libvirt boot option for direct kernel boot
```
<domain>
  <os>
    <kernel>$PATH_TO_KERNEL/vmlinux</kernel>
    <initrd>$PATH_TO_INITRAMFS/initramfs-5.18.18-200.fc36.x86_64.img</initrd>
    <cmdline>console=ttyS0 root=/dev/mapper/fedora_fedora-root ro rd.lvm.lv=fedora_fedora/root</cmdline>
  </os>
</domain>
```

# gdb extra
set gdb server and disable KASLR
```
<domain type='kvm' xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'>
  <qemu:commandline>
    <qemu:arg value='-gdb'/>
    <qemu:arg value='tcp::1235'/>
  </qemu:commandline>
  <os>
    <cmdline>$CMD nokaslr</cmdline>
  </os>
</domain>
```

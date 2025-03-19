# Archlinux QEMU-GDB guide

## prerequisite

An archlinux VM managed by libvirt

## Shared the source between host and guest

create a shared directory on the host for the source then share it with the guest using virtiofs
```xml
...
    <filesystem type='mount' accessmode='passthrough'>
      <driver type='virtiofs'/>
      <source dir='<kernel source tree>'/>
      <target dir='<kernel-build>'/>
      <address type='pci' domain='...' bus='...' slot='...' function='...'/>
    </filesystem>
...
```
mount on guest by adding to `/etc/fstab`:
`<kernel-build>            /root/linux-gdb virtiofs rw,relatime`

## Compile the kernel

Although doing all of the following on the guest should also work, however, it makes sense to use the host if not all CPUs are allocated to the guest.


Prefix: H=host G=guest.  
generally follow https://wiki.archlinux.org/title/Kernel/Traditional_compilation
* H: obtain kernel source
* G: copy out `/proc/config.gz`  (zcat to `<source>/.config`)
* H: `make nconfig (or menuconfig)` and make necessary changes.  
  suggestions below:
  * General setup -> Local version: `CONFIG_LOCALVERSION=-gdb`  
    **(you should do this to avoid making a kernel with the same <uname -r>)**
  * Kernel hacking
    * Compile-time checks and compiler options
      * Provide GDB scripts for kernel debugging: `CONFIG_GDB_SCRIPTS=y`
      * Generate readable assembler code: `CONFIG_READABLE_ASM=y`
* H/G: make sure to use `lsmod` or `modprobed-db` to reduce unnecessary compilation
  * G: `lsmod` or `modprobed-db list > <source>/needed_mods`
  * H: `make LSMOD=needed_mods localmodconfig` or `make LSMOD=needed_mods localyesconfig`
* H: `make` or `make -j<number of threads>`
* G: `cp arch/x86/boot/bzImage /boot/vmlinuz_linux_gdb`  
  (suggest not to use dash but instead underscore so grub doens't automatically pick up your kernel)  
  (skip if you want to use direct kernel boot. It seems grub does not support `vmlinux`, wtf???)
  * **you can stop here if you used `localyesconfig`**
* G: `make modules_install`
* G: `mkinitcpio -k <new uname -r> -g /boot/initramfs_linux_gdb.img`  
  (use the `-k` option matching your new kernel's `uname -r`, this has to match the module directory `/lib/modules/<uname -r>`)
* G: `rm -rf /lib/modules/<old uname -r>` as needed

some helpers
* H: `make compile_commands.json`
* H: `make cscope`
* G: `systemctl enable serial-getty@ttyS0.service`
* A builder script can be found [here](kernel_maker.sh)


## Add a boot entry on guest

Skip this part if you are doing direct kernel boot.

* open `/boot/grub/grub.cfg` and find your default boot menuentry, copy to `/etc/grub.d/40_custom`, and then modify the `linux` and `initrd` accordingly.  
  * if you used `localyesconfig` you can leave `initrd` unchanged.  
    (it seems you cannot leave out `initrd` if cmdline contains `root=UUID=...`. If you so insist, use something like `root=/dev/vda2`)
  * suggest `linux` be added with `console=ttyS0,115200 nokaslr`
  * optionally add `GRUB_TERMINAL_OUTPUT="console vga_text"` in `/etc/default/grub` so that grub menu also works on tty
  * Finally `grub-mkconfig -o /boot/grub/grub.cfg`
* shutdown and launch with `virsh start <vm> --console`

## direct kernel boot 

Create a copy of the VM definition.

```shell
virsh dumpxml <vm> > <vm.xml>
# rename <name> to <new_vm> and remove <uuid> from the xml
virsh define <vm.xml>
```


Adjust xml as follows, make sure to include `nokaslr` if you want gdb to work. `initrd` optional depending on boot `cmdline`.  
`virsh edit <new_vm>`
```xml
...
  <os>
    ...
    <kernel>/path/to/kernel/vmlinux</kernel>
    <initrd>/path/to/your/initramfs</initrd>
    <cmdline>root=<...> rw loglevel=3 console=ttyS0,115200 nokaslr</cmdline>
    ...
  </os>
...
```

## GDB

Add to xml the following:
```xml
<domain type='kvm' xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'>
...
<qemu:commandline>        
  <qemu:arg value='-s'/>  
</qemu:commandline>
```

start GDB:
* `gdb <source>/vmlinux`
* `target remote :1234`

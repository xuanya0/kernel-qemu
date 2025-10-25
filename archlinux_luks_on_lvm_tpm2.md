# LUKS on LVM with TPM2

### After arch-chroot
`arch-chroot -S /mnt`

### Set in `/etc/mkinitcpio.conf`
`HOOKS=(... systemd ... block lvm2 sd-encrypt filesystems ...)`
[See LUKS on LVM](https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#Configuring_mkinitcpio_4)

### Add to `/boot/loader/entries/arch.conf`
`bootctl install`
```
title      Arch Linux                                                                             
linux      /vmlinuz-linux                                                                         
initrd     initramfs-linux.img                                                                   
options    rd.luks.name=763d787e-c071-4368-9baf-54641a67bafd=rootfs root=/dev/mapper/rootfs rw
```
`systemctl enable --now systemd-boot-update.service`

### Install necessary utils
`pacman -S vim efibootmgr sbctl lvm2 tpm2-tools systemd-ukify`

### Enable network 
Remember to https://wiki.archlinux.org/title/Systemd-networkd
```
systemctl enable --now systemd-networkd
systemctl enable --now systemd-resolved
```

### Configure secure boot in firmware
```
sbctl create-keys
sbctl enroll-keys
```

### Configure UKIFY
add the following to `/etc/kernel/uki.conf`
```
[UKI]
Linux=/boot/vmlinuz-linux
Initrd=/boot/initramfs-linux.img
Cmdline=rd.luks.name=763d787e-c071-4368-9baf-54641a67bafd=rootfs root=/dev/mapper/rootfs rw
[PCRSignature:NAME]
PCRPrivateKey=/etc/systemd/tpm2-pcr-private-key.pem
PCRPublicKey=/etc/systemd/tpm2-pcr-public-key.pem
```
Run 
`ukify genkey --config /etc/kernel/uki.conf`

### Repeatedly run after pacman update or add to pacman's hook
```
set -e

TMP="/tmp/unsigned.efi"
EFI_PATH="/EFI/Linux/ARCH_UKI.SIGNED.EFI"
SIGNED="/boot/$EFI_PATH"
LABEL='Arch UKI Signed'
UKICONF="/etc/kernel/uki.conf"
ukify build --measure -c "$UKICONF" -o "$TMP"
sbctl sign -s "$TMP" -o "$SIGNED"
systemd-cryptenroll --wipe-slot tpm2 --tpm2-device auto --tpm2-pcrs="7" --tpm2-public-key-pcrs="11" /dev/mapper/arch-root
set +e; efibootmgr -q -B -L "$LABEL"; set -e;
efibootmgr --create --disk /dev/sda --part 1 --loader "$EFI_PATH" --label "$LABEL" --unicode
ukify inspect "$SIGNED"
sbctl verify
```

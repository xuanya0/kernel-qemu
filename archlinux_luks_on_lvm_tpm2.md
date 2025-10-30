# LUKS on LVM with TPM2 Secure Boot

### After arch-chroot
`arch-chroot -S /mnt`

### enable trim for ssd
```
cryptsetup --allow-discards --persistent refresh root
# Check enabled 
lsblk --discard
systemctl enable --now fstrim.timer
```

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

## ukify + sbctl
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

### run everytime after kernel update or add to pacman's hook
```
set -e

EFI_PATH="/EFI/Linux/ARCH_UKI.SIGNED.EFI"
SIGNED="/boot/$EFI_PATH"
LABEL='Arch UKI Signed'
UKICONF="/etc/kernel/uki.conf"
ukify build --measure -c "$UKICONF" -o "$SIGNED"
sbctl sign -s "$SIGNED"
systemd-cryptenroll --wipe-slot tpm2 --tpm2-device auto --tpm2-pcrs="7" --tpm2-public-key-pcrs="11" /dev/mapper/arch-root
set +e; efibootmgr -q -B -L "$LABEL"; set -e;
efibootmgr --create --disk /dev/sda --part 1 --loader "$EFI_PATH" --label "$LABEL" --unicode
ukify inspect "$SIGNED"
sbctl verify
```



## Simplified with ukify only

Enable Secure Boot and clear SB keys. This puts the SB into Setup Mode.

add the following to `/etc/kernel/uki.conf`
```
[UKI]
Linux=/boot/vmlinuz-linux
Initrd=/boot/initramfs-linux.img
Microcode=/boot/intel-ucode.img
Cmdline=rd.luks.name=763d787e-c071-4368-9baf-54641a67bafd=rootfs root=/dev/mapper/rootfs rw console=ttyS0,115200 intel_iommu=on
Splash=/usr/share/systemd/bootctl/splash-arch.bmp
#PCRPKey=
#PCRBanks=
SecureBootSigningTool=systemd-sbsign
SecureBootPrivateKey=/etc/kernel/secure-boot-private-key.pem
SecureBootCertificate=/etc/kernel/secure-boot-certificate.pem
#SecureBootCertificateDir=
#SecureBootCertificateName=
#SecureBootCertificateValidity=
#SigningEngine=
SignKernel=true

[PCRSignature:NAME]
PCRPrivateKey=/etc/systemd/tpm2-pcr-private-key.pem
PCRPublicKey=/etc/systemd/tpm2-pcr-public-key.pem
#Phases=
```

## first launch
```
EFI_PATH="/EFI/Linux/ARCH_UKI.SIGNED.EFI"
SIGNED="/boot/$EFI_PATH"
LABEL='Arch UKI Signed'
UKICONF="/etc/kernel/uki.conf"

# generate secure boot and tpm2 public keys
ukify genkey -c /etc/kernel/uki.conf
# install systemd-boot with SB keys enrollment option
bootctl install --secure-boot-auto-enroll yes --certificate /etc/kernel/secure-boot-certificate.pem --private-key /etc/kernel/secure-boot-private-key.pem `
# generate UKI 
ukify build --measure -c "$UKICONF" -o "$SIGNED"
# add the UKI to EFI boot option
set +e; efibootmgr -q -B -L "$LABEL"; set -e;
efibootmgr --create --disk /dev/sda --part 1 --loader "$EFI_PATH" --label "$LABEL" --unicode
```

* Reboot system
* boot into systemd-boot (likely named `Linux Boot Manager`)
* choose `Enroll Secure Boot keys: auto`
* It should automatically reboot into UKI and ask for LUKS password
* Once logged in, run the following to seal LUKS to TPM
  * `systemd-cryptenroll --wipe-slot tpm2 --tpm2-device auto --tpm2-pcrs="7" --tpm2-public-key-pcrs="11" /dev/mapper/arch-root`
* Reboot, now the UKI should boot directly into login

## subsequent updates

* If you do it manually, just run `ukify build --measure -c "$UKICONF" -o "$SIGNED"` after pacman update.
* To enable automatic update with pacman-mkinitcpio
  * add [install.conf](https://wiki.archlinux.org/title/Unified_kernel_image#kernel-install).
  * Add the following line `default_uki="<your $SIGNED path>"` to `/etc/mkinitcpio.d/linux.preset`
  * Run `mkinitcpio -P` to verify that a new UKI is generated at `<your $SIGNED path>`




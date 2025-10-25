# Setting up OpenWRT in a systemd-spawn container

### download openwrt rootfs
```
mkdir openwrt
cd openwrt
wget https://downloads.openwrt.org/releases/24.10.4/targets/x86/64/openwrt-24.10.4-x86-64-rootfs.tar.gz
tar -xvf openwrt-24.10.4-x86-64-rootfs.tar.gz 
rm openwrt-24.10.4-x86-64-rootfs.tar.gz
# unjail dnsmasq
sed -i 's/procd_add_jail/: \0/g' ./etc/init.d/dnsmasq
cd ..
```
[Note: cannot have ujail (nested namespace) in the container](https://github.com/lxc/lxc-ci/blob/main/images/openwrt.yaml#L284C5-L284C57)

### test the contained machine
`systemd-nspawn -b -D openwrt --private-network --network-interface=eth2 --network-interface=eth3`


### add config and start automatically
Add to `/etc/systemd/nspawn/openwrt.nspawn`
```
[Exec]
Boot=yes
KillSignal=SIGUSR2 # ya, this is the signal for shutdown


[Network]
Private=yes
Interface=eth2
Interface=eth3
```
Check your pool path `machinectl show`
```
mv openwrt /var/lib/machines/
systemctl enable --now machines.target 
machinectl enable openwrt
```

# replace your kernel with custom build that works with gdb

* [archlinux](archlinux-gdb.md)

## TTY root auto login
https://unix.stackexchange.com/a/552642

```shell
systemctl edit serial-getty@ttyS0.service
# ExecStart=-/sbin/agetty -o '-p -- \\u' --keep-baud 115200,38400,9600 --noclear --autologin root ttyS0 $TERM
# /etc/pam.d/login:
# auth sufficient pam_listfile.so item=tty sense=allow file=/etc/securetty onerr=fail apply=root
echo ttyS0 > /etc/securetty
```

Auto resize tmux: .bash_profile
```
resize
tmux a || tmux
```

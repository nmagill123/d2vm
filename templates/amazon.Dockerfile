FROM {{ .Image }}

USER root

RUN dnf update -y

RUN dnf install -y \
    kernel \
    systemd \
    systemd-networkd \
    systemd-resolved \
{{- if .GrubBIOS }}
    grub2-pc \
{{- end }}
{{- if .GrubEFI }}
    grub2-efi-x64 grub2-efi-x64-modules \
{{- end }}
    e2fsprogs \
    sudo && \
    systemctl enable systemd-networkd && \
    systemctl enable systemd-resolved && \
    systemctl unmask systemd-remount-fs.service && \
    systemctl unmask getty.target && \
    mkdir -p /boot && \
    (find /boot -type l -exec rm {} \; 2>/dev/null || true)

# Generate initramfs - omit fsck modules to avoid boot issues
RUN KVER=$(ls /lib/modules/ | head -1) && \
    dracut --no-hostonly --no-hostonly-cmdline --omit "fsck systemd-fsck" --force /boot/initramfs-${KVER}.img ${KVER}

{{ if .Password }}RUN echo "root:{{ .Password }}" | chpasswd {{ end }}

RUN mkdir -p /etc/systemd/network && printf '\
[Match]\n\
Name=eth0\n\
\n\
[Network]\n\
DHCP=yes\n\
' > /etc/systemd/network/20-wired.network

{{- if not .Grub }}
# Amazon Linux puts vmlinuz in /lib/modules/*/vmlinuz, not /boot
RUN cp $(find /lib/modules -name 'vmlinuz' | head -1) /boot/vmlinuz && \
    mv $(find /boot -name 'initramfs-*.img' | head -1) /boot/initrd.img
{{- end }}

RUN dnf clean all && \
    rm -rf /var/cache/dnf

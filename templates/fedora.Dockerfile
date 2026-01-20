FROM {{ .Image }}

USER root

RUN dnf update -y

RUN dnf install -y \
    kernel \
    systemd \
    NetworkManager \
{{- if .GrubBIOS }}
    grub2-pc \
{{- end }}
{{- if .GrubEFI }}
    grub2-efi-x64 grub2-efi-x64-modules \
{{- end }}
    e2fsprogs \
    sudo && \
    systemctl enable NetworkManager && \
    systemctl unmask systemd-remount-fs.service && \
    systemctl unmask getty.target && \
    mkdir -p /boot && \
    (find /boot -type l -exec rm {} \; 2>/dev/null || true)

# Generate initramfs - some distros need /boot created first
# Use --no-hostonly-cmdline to prevent baking in container-specific root device  
# Omit fsck modules entirely from initramfs - fsck will run from main system if needed
RUN KVER=$(ls /lib/modules/ | head -1) && \
    dracut --no-hostonly --no-hostonly-cmdline --omit "fsck systemd-fsck" --force /boot/initramfs-${KVER}.img ${KVER}

{{ if .Password }}RUN echo "root:{{ .Password }}" | chpasswd {{ end }}

{{- if not .Grub }}
# Fedora/RHEL-based distros may store vmlinuz in /lib/modules/*/vmlinuz or /boot
RUN VMLINUZ=$(find /lib/modules -name 'vmlinuz' 2>/dev/null | head -1); \
    if [ -z "$VMLINUZ" ]; then VMLINUZ=$(find /boot -name 'vmlinuz-*' 2>/dev/null | head -1); fi; \
    cp "$VMLINUZ" /boot/vmlinuz && \
    mv $(find /boot -name 'initramfs-*.img' | head -1) /boot/initrd.img
{{- end }}

RUN dnf clean all && \
    rm -rf /var/cache/dnf

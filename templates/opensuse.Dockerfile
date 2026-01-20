FROM {{ .Image }}

USER root

RUN zypper refresh

RUN zypper install -y \
    kernel-default \
    systemd \
    wicked \
    dracut \
{{- if .GrubBIOS }}
    grub2 \
{{- end }}
{{- if .GrubEFI }}
    grub2-x86_64-efi \
{{- end }}
    e2fsprogs \
    sudo && \
    systemctl enable wicked && \
    find /boot -type l -exec rm {} \;

RUN dracut --no-hostonly --regenerate-all --force

{{ if .Password }}RUN echo "root:{{ .Password }}" | chpasswd {{ end }}

RUN mkdir -p /etc/wicked/ifconfig && printf '\
<interface>\n\
  <name>eth0</name>\n\
  <control>\n\
    <mode>boot</mode>\n\
  </control>\n\
  <ipv4:dhcp>\n\
    <enabled>true</enabled>\n\
  </ipv4:dhcp>\n\
</interface>\n\
' > /etc/wicked/ifconfig/eth0.xml

{{- if not .Grub }}
RUN mv $(ls -t /boot/vmlinuz-* | head -n 1) /boot/vmlinuz && \
    mv $(ls -t /boot/initrd-* | head -n 1) /boot/initrd
{{- end }}

RUN zypper clean -a

FROM {{ .Image }}

USER root

{{- if eq .Release.VersionID "9" }}
RUN echo "deb http://archive.debian.org/debian stretch main" > /etc/apt/sources.list && \
    echo "deb-src http://archive.debian.org/debian stretch main" >> /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian stretch-backports main" >> /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security stretch/updates main" >> /etc/apt/sources.list && \
    echo "deb-src http://archive.debian.org/debian-security stretch/updates main" >> /etc/apt/sources.list
{{- end }}

{{- if eq .Release.ID "deepin" }}
# Deepin uses different kernel package names
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends \
      $(apt-cache search 'linux-image-.*-amd64-desktop' | grep -v dbg | sort -V | tail -1 | cut -d' ' -f1) \
      initramfs-tools && \
      (find /boot -type l -exec rm {} \; 2>/dev/null || true) && \
      update-initramfs -c -k all
{{- else }}
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends \
      linux-image-amd64 && \
      find /boot -type l -exec rm {} \;
{{- end }}

RUN ARCH="$([ "$(uname -m)" = "x86_64" ] && echo amd64 || echo arm64)"; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      systemd-sysv \
      systemd \
    {{- if .Grub }}
      grub-common \
      grub2-common \
    {{- end }}
    {{- if .GrubBIOS }}
      grub-pc-bin \
    {{- end }}
    {{- if .GrubEFI }}
      grub-efi-${ARCH}-bin \
    {{- end }}
      dbus \
      iproute2 \
      isc-dhcp-client \
      iputils-ping

RUN systemctl preset-all

{{ if .Password }}RUN echo "root:{{ .Password }}" | chpasswd {{ end }}

{{ if eq .NetworkManager "netplan" }}
RUN apt install -y netplan.io
RUN mkdir -p /etc/netplan && printf '\
network:\n\
  version: 2\n\
  renderer: networkd\n\
  ethernets:\n\
    eth0:\n\
      dhcp4: true\n\
      dhcp-identifier: mac\n\
      nameservers:\n\
        addresses:\n\
        - 8.8.8.8\n\
        - 8.8.4.4\n\
' > /etc/netplan/00-netcfg.yaml
{{ else if eq .NetworkManager "ifupdown"}}
{{- if eq .Release.ID "deepin" }}
# Deepin uses systemd-networkd instead of ifupdown
RUN mkdir -p /etc/systemd/network && printf '\
[Match]\n\
Name=eth0\n\
\n\
[Network]\n\
DHCP=yes\n\
' > /etc/systemd/network/20-wired.network && \
    systemctl enable systemd-networkd
{{- else }}
RUN if [ -z "$(apt-cache madison ifupdown2 2> /dev/nul)" ]; then apt install -y ifupdown; else apt install -y ifupdown2; fi
RUN mkdir -p /etc/network && printf '\
auto eth0\n\
allow-hotplug eth0\n\
iface eth0 inet dhcp\n\
' > /etc/network/interfaces
{{- end }}
{{ end }}


{{- if .Luks }}
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends cryptsetup-initramfs && \
    echo "CRYPTSETUP=y" >> /etc/cryptsetup-initramfs/conf-hook && \
    update-initramfs -u -v
{{- end }}

# needs to be after update-initramfs
{{- if not .Grub }}
RUN mv $(ls -t /boot/vmlinuz-* | head -n 1) /boot/vmlinuz && \
      mv $(ls -t /boot/initrd.img-* | head -n 1) /boot/initrd.img
{{- end }}

RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/*

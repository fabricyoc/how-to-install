# 🌐 Servidor FOG Project

Guia para implantação de um servidor **FOG Project** destinado à
clonagem e implantação de imagens de sistemas operacionais via rede PXE.

## 🖥️ Ambiente utilizado

| Software | Versão |
|---|---|
| Ubuntu | 24.04.4 |
| VirtualBox | 7.2.14 |
| Debian | 13.6 |
| FOG Project | Latest Stable |

---

## 🏗️ Topologia

```text
                       Internet
                          │
                          │
                     ┌────┴────┐
                     │  Ubuntu │
                     │   Host  │
                     └────┬────┘
                          │
                    VirtualBox
                          │
               ┌──────────┴──────────┐
               │                     │
            enp0s8                enp0s3
            Bridge               fog-lab
               │                     │
           Internet              192.168.0.1
                                     │
                                     │ DHCP/TFTP
                                     │
                         ┌───────────┴───────────┐
                         │                       │
                       PC 01                   PC 02
                     PXE Boot                 PXE Boot
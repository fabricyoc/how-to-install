#!/usr/bin/env bash

# ============================================================
# FOG LAB - Instalação e configuração automatizada
# Debian 13 + FOG Project + Kea + iPXE + NFS + TFTP + FTP
#
# Ambiente:
#   Interface LAN/PXE : enp0s3
#   IP FOG            : 192.168.0.1
#   Rede              : 192.168.0.0/24
#   DHCP Pool         : 192.168.0.100 - 192.168.0.200
#   Interface Internet: enp0s8
#
# Execute:
#   chmod +x install-fog-lab.sh
#   sudo ./install-fog-lab.sh
# ============================================================

set -Eeuo pipefail

# ============================================================
# VARIÁVEIS
# ============================================================

FOG_IP="192.168.0.1"

FOG_INTERFACE="enp0s3"
INTERNET_INTERFACE="enp0s8"

NETWORK="192.168.0.0/24"
NETMASK="255.255.255.0"

DHCP_START="192.168.0.100"
DHCP_END="192.168.0.200"

FOG_DIR="/opt/fogproject"
IPXE_DIR="/opt/ipxe"
TFTP_DIR="/srv/tftp"

IMAGES_DIR="/images"

FOG_REPO="https://github.com/FOGProject/fogproject.git"
IPXE_REPO="https://github.com/ipxe/ipxe.git"

BACKUP_DIR="/root/fog-backup-$(date +%Y%m%d-%H%M%S)"

LOG_FILE="/var/log/fog-lab-install.log"

# ============================================================
# CORES
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================
# FUNÇÕES
# ============================================================

info() {
    echo -e "\n${BLUE}[INFO]${NC} $*"
}

ok() {
    echo -e "${GREEN}[OK]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[AVISO]${NC} $*"
}

error() {
    echo -e "${RED}[ERRO]${NC} $*" >&2
}

die() {
    error "$*"
    exit 1
}

backup_file() {

    local file="$1"

    if [[ -f "$file" ]]; then

        mkdir -p "$BACKUP_DIR"

        cp -a "$file" "$BACKUP_DIR/"

        ok "Backup realizado: $file"
    fi
}

service_exists() {
    systemctl list-unit-files \
        --type=service \
        --no-legend \
        2>/dev/null |
        awk '{print $1}' |
        grep -qx "$1.service"
}

restart_if_exists() {

    local service="$1"

    if service_exists "$service"; then

        systemctl restart "$service"

        if systemctl is-active --quiet "$service"; then
            ok "$service ativo"
        else
            warn "$service não ficou ativo"
        fi

    else
        warn "Serviço $service não encontrado"
    fi
}

# ============================================================
# TRATAMENTO DE ERRO
# ============================================================

trap 'error "Erro na linha $LINENO. Consulte $LOG_FILE"' ERR

# Duplica saída no terminal e no log.
exec > >(tee -a "$LOG_FILE") 2>&1

# ============================================================
# CABEÇALHO
# ============================================================

clear

echo "============================================================"
echo "             INSTALADOR AUTOMÁTICO FOG LAB"
echo "============================================================"
echo
echo "IP FOG .............: $FOG_IP"
echo "Interface PXE .......: $FOG_INTERFACE"
echo "Interface Internet ..: $INTERNET_INTERFACE"
echo "Rede ................: $NETWORK"
echo "DHCP ................: $DHCP_START - $DHCP_END"
echo
echo "============================================================"

# ============================================================
# 1. VERIFICAÇÕES INICIAIS
# ============================================================

info "Verificando privilégios..."

if [[ "$EUID" -ne 0 ]]; then
    die "Execute este script com sudo ou como root."
fi

ok "Executando como root."

# ------------------------------------------------------------

info "Verificando sistema operacional..."

if [[ ! -f /etc/os-release ]]; then
    die "Não foi possível identificar o sistema operacional."
fi

source /etc/os-release

echo "Sistema detectado: $PRETTY_NAME"

# ------------------------------------------------------------

info "Verificando interfaces..."

if ! ip link show "$FOG_INTERFACE" >/dev/null 2>&1; then
    die "Interface $FOG_INTERFACE não encontrada."
fi

if ! ip link show "$INTERNET_INTERFACE" >/dev/null 2>&1; then
    die "Interface $INTERNET_INTERFACE não encontrada."
fi

ok "Interfaces encontradas."

# ============================================================
# 2. BACKUPS
# ============================================================

info "Criando backups..."

mkdir -p "$BACKUP_DIR"

backup_file /etc/network/interfaces
backup_file /etc/kea/kea-dhcp4.conf
backup_file /etc/exports
backup_file /etc/vsftpd.conf
backup_file /etc/default/tftpd-hpa

ok "Backups armazenados em: $BACKUP_DIR"

# ============================================================
# 3. CONFIGURAÇÃO DA REDE
# ============================================================

info "Configurando /etc/network/interfaces..."

cat > /etc/network/interfaces <<EOF
source /etc/network/interfaces.d/*

# Loopback
auto lo
iface lo inet loopback


# ============================================================
# Rede interna utilizada pelo FOG / PXE
# ============================================================

allow-hotplug ${FOG_INTERFACE}
iface ${FOG_INTERFACE} inet static
    address ${FOG_IP}
    netmask ${NETMASK}


# ============================================================
# Interface com acesso à Internet
# ============================================================

auto ${INTERNET_INTERFACE}
iface ${INTERNET_INTERFACE} inet dhcp
EOF

ok "Arquivo de rede configurado."

# Aplicar IP imediatamente sem depender apenas de restart
ip addr flush dev "$FOG_INTERFACE" || true
ip addr add "${FOG_IP}/24" dev "$FOG_INTERFACE"
ip link set "$FOG_INTERFACE" up

ok "$FOG_INTERFACE configurada como $FOG_IP/24"

# ============================================================
# 4. REPOSITÓRIOS
# ============================================================

info "Atualizando repositórios..."

apt-get update

# ============================================================
# 5. DEPENDÊNCIAS
# ============================================================

info "Instalando dependências..."

DEBIAN_FRONTEND=noninteractive apt-get install -y \
    sudo \
    git \
    wget \
    curl \
    openssh-server \
    tcpdump \
    make \
    gcc \
    binutils \
    build-essential \
    liblzma-dev \
    nfs-kernel-server \
    vsftpd \
    tftpd-hpa \
    kea-dhcp4-server \
    ca-certificates

ok "Dependências instaladas."

# ============================================================
# 6. SSH
# ============================================================

info "Habilitando SSH..."

systemctl enable --now ssh

ok "SSH habilitado."

# ============================================================
# 7. DOWNLOAD DO FOG
# ============================================================

info "Preparando FOG Project..."

if [[ -d "$FOG_DIR/.git" ]]; then

    warn "FOG já existe em $FOG_DIR."

    cd "$FOG_DIR"

    git pull || warn "Não foi possível atualizar o repositório."

else

    rm -rf "$FOG_DIR"

    git clone "$FOG_REPO" "$FOG_DIR"

fi

ok "FOG disponível em $FOG_DIR"

# ============================================================
# 8. INSTALADOR OFICIAL DO FOG
# ============================================================

echo
echo "============================================================"
echo "            INSTALAÇÃO OFICIAL DO FOG"
echo "============================================================"
echo
echo "Agora será aberto o installfog.sh."
echo
echo "Para este laboratório, utilize aproximadamente:"
echo
echo "  Sistema operacional ............. Debian"
echo "  Instalação ...................... Normal"
echo "  Interface ....................... $FOG_INTERFACE"
echo "  Router .......................... $FOG_IP"
echo "  FOG como DHCP ................... Sim"
echo "  DNS via DHCP .................... Não"
echo "  HTTPS ........................... Não"
echo
echo "Se ocorrer:"
echo
echo "    Kea base configuration failed validation"
echo
echo "não há problema."
echo
echo "Este script substituirá a configuração do Kea depois."
echo
echo "============================================================"
echo

cd "$FOG_DIR/bin"

# Não usamos set -e nessa etapa porque versões do instalador
# podem retornar erro justamente na validação do Kea.
set +e

./installfog.sh

FOG_INSTALL_RESULT=$?

set -e

if [[ "$FOG_INSTALL_RESULT" -ne 0 ]]; then
    warn "O instalador FOG retornou código $FOG_INSTALL_RESULT."
    warn "Continuando com as configurações do laboratório."
else
    ok "Instalador FOG concluído."
fi

# ============================================================
# 9. CONFIGURAÇÃO DO KEA DHCP
# ============================================================

info "Configurando Kea DHCP..."

mkdir -p /etc/kea

backup_file /etc/kea/kea-dhcp4.conf

cat > /etc/kea/kea-dhcp4.conf <<EOF
{
    "Dhcp4": {

        "interfaces-config": {
            "interfaces": [
                "${FOG_INTERFACE}"
            ]
        },

        "lease-database": {
            "type": "memfile",
            "lfc-interval": 3600
        },

        "valid-lifetime": 21600,

        "max-valid-lifetime": 43200,

        "next-server": "${FOG_IP}",

        "option-data": [

            {
                "name": "tftp-server-name",
                "data": "${FOG_IP}"
            }

        ],

        "subnet4": [

            {

                "id": 1,

                "subnet": "${NETWORK}",

                "pools": [

                    {
                        "pool": "${DHCP_START} - ${DHCP_END}"
                    }

                ],

                "option-data": [

                    {
                        "name": "subnet-mask",
                        "data": "${NETMASK}"
                    },

                    {
                        "name": "routers",
                        "data": "${FOG_IP}"
                    }

                ]

            }

        ],

        "client-classes": [

            {

                "name": "FOG-Legacy-BIOS",

                "test": "option[93].hex == 0x0000",

                "boot-file-name": "undionly.kpxe"

            },

            {

                "name": "FOG-UEFI-32",

                "test": "option[93].hex == 0x0006",

                "boot-file-name": "i386-efi/snponly.efi"

            },

            {

                "name": "FOG-UEFI-64",

                "test": "option[93].hex == 0x0007",

                "boot-file-name": "snponly.efi"

            },

            {

                "name": "FOG-UEFI-64-2",

                "test": "option[93].hex == 0x0008",

                "boot-file-name": "snponly.efi"

            },

            {

                "name": "FOG-UEFI-64-3",

                "test": "option[93].hex == 0x0009",

                "boot-file-name": "snponly.efi"

            },

            {

                "name": "FOG-UEFI-ARM64",

                "test": "option[93].hex == 0x000b",

                "boot-file-name": "arm64-efi/snponly.efi"

            }

        ]

    }
}
EOF

# ============================================================
# 10. VALIDAR KEA
# ============================================================

info "Validando configuração do Kea..."

if kea-dhcp4 -t /etc/kea/kea-dhcp4.conf; then

    ok "Configuração do Kea válida."

else

    die "Configuração do Kea inválida."
fi

# ============================================================
# 11. PREPARAR TFTP
# ============================================================

info "Preparando diretório TFTP..."

mkdir -p "$TFTP_DIR"

chmod 755 "$TFTP_DIR"

# ============================================================
# 12. DOWNLOAD DO iPXE
# ============================================================

info "Preparando código-fonte do iPXE..."

if [[ -d "$IPXE_DIR/.git" ]]; then

    cd "$IPXE_DIR"

    git pull || warn "Não foi possível atualizar iPXE."

else

    rm -rf "$IPXE_DIR"

    git clone "$IPXE_REPO" "$IPXE_DIR"

fi

ok "iPXE disponível em $IPXE_DIR"

# ============================================================
# 13. SCRIPT EMBUTIDO DO iPXE
# ============================================================

info "Criando fog-embed.ipxe..."

cd "$IPXE_DIR/src"

cat > fog-embed.ipxe <<'EOF'
#!ipxe

set arch ${buildarch}

iseq ${arch} i386 && cpuid --ext 29 && set arch x86_64 ||

params

param mac0 ${net0/mac}
param arch ${arch}
param platform ${platform}
param product ${product}
param manufacturer ${manufacturer}
param ipxever ${version}
param filename ${filename}
param sysuuid ${uuid}

chain http://192.168.0.1/fog/service/ipxe/boot.php##params
EOF

ok "fog-embed.ipxe criado."

# ============================================================
# 14. HABILITAR PARAM_CMD
# ============================================================

info "Habilitando PARAM_CMD..."

mkdir -p config/local

cat > config/local/general.h <<EOF
#define PARAM_CMD
EOF

ok "PARAM_CMD habilitado."

# ============================================================
# 15. COMPILAR UNDIONLY.KPXE
# ============================================================

info "Compilando undionly.kpxe..."

make clean

make bin/undionly.kpxe EMBED=fog-embed.ipxe

if [[ ! -f bin/undionly.kpxe ]]; then
    die "undionly.kpxe não foi gerado."
fi

ok "undionly.kpxe compilado."

# ============================================================
# 16. COPIAR UNDIONLY PARA TFTP
# ============================================================

info "Instalando undionly.kpxe..."

cp -f bin/undionly.kpxe "$TFTP_DIR/undionly.kpxe"

chmod 644 "$TFTP_DIR/undionly.kpxe"

ok "undionly.kpxe instalado."

# ============================================================
# 17. VERIFICAR UEFI
# ============================================================

info "Verificando arquivos UEFI..."

if [[ -f "$TFTP_DIR/snponly.efi" ]]; then

    ok "snponly.efi encontrado."

else

    warn "snponly.efi não encontrado em $TFTP_DIR"
fi


if [[ -f "$TFTP_DIR/i386-efi/snponly.efi" ]]; then

    ok "i386-efi/snponly.efi encontrado."

else

    warn "i386-efi/snponly.efi não encontrado."
fi


if [[ -f "$TFTP_DIR/arm64-efi/snponly.efi" ]]; then

    ok "arm64-efi/snponly.efi encontrado."

else

    warn "arm64-efi/snponly.efi não encontrado."
fi

# ============================================================
# 18. CONFIGURAR TFTP
# ============================================================

info "Configurando tftpd-hpa..."

backup_file /etc/default/tftpd-hpa

cat > /etc/default/tftpd-hpa <<EOF
TFTP_USERNAME="tftp"
TFTP_DIRECTORY="${TFTP_DIR}"
TFTP_ADDRESS=":69"
TFTP_OPTIONS="--secure"
EOF

ok "TFTP configurado."

# ============================================================
# 19. CONFIGURAR DIRETÓRIO /images
# ============================================================

info "Preparando $IMAGES_DIR..."

mkdir -p "$IMAGES_DIR/dev"
mkdir -p "$IMAGES_DIR/postdownloadscripts"

touch "$IMAGES_DIR/.mntcheck"

# O usuário/grupo é criado normalmente pelo instalador FOG.
if id fogproject >/dev/null 2>&1; then

    chown -R fogproject:fogproject "$IMAGES_DIR"

else

    warn "Usuário fogproject ainda não existe."
    warn "Mantendo proprietário atual de /images."
fi

chmod -R 775 "$IMAGES_DIR"

ok "Permissões de $IMAGES_DIR configuradas."

# ============================================================
# 20. CONFIGURAR NFS
# ============================================================

info "Configurando NFS..."

backup_file /etc/exports

cat > /etc/exports <<EOF
/images *(ro,sync,no_wdelay,insecure_locks,no_root_squash,insecure)

/images/dev *(rw,async,no_wdelay,no_root_squash,insecure)
EOF

exportfs -ra

ok "NFS configurado."

# ============================================================
# 21. CONFIGURAR VSFTPD
# ============================================================

info "Configurando vsftpd..."

backup_file /etc/vsftpd.conf

# Garante local_enable
if grep -qE '^[#[:space:]]*local_enable=' /etc/vsftpd.conf; then

    sed -i \
        's/^[#[:space:]]*local_enable=.*/local_enable=YES/' \
        /etc/vsftpd.conf

else

    echo "local_enable=YES" >> /etc/vsftpd.conf
fi

# Garante write_enable
if grep -qE '^[#[:space:]]*write_enable=' /etc/vsftpd.conf; then

    sed -i \
        's/^[#[:space:]]*write_enable=.*/write_enable=YES/' \
        /etc/vsftpd.conf

else

    echo "write_enable=YES" >> /etc/vsftpd.conf
fi

ok "vsftpd configurado."

# ============================================================
# 22. REINICIAR SERVIÇOS
# ============================================================

info "Reiniciando serviços..."

systemctl daemon-reload

restart_if_exists "kea-dhcp4-server"
restart_if_exists "tftpd-hpa"
restart_if_exists "nfs-kernel-server"
restart_if_exists "vsftpd"
restart_if_exists "apache2"
restart_if_exists "mariadb"

# ============================================================
# 23. HABILITAR SERVIÇOS
# ============================================================

info "Habilitando serviços na inicialização..."

for SERVICE in \
    kea-dhcp4-server \
    tftpd-hpa \
    nfs-kernel-server \
    vsftpd
do

    if service_exists "$SERVICE"; then

        systemctl enable "$SERVICE" >/dev/null 2>&1 || true

    fi

done

# ============================================================
# 24. DIAGNÓSTICO
# ============================================================

echo
echo
echo "============================================================"
echo "                 DIAGNÓSTICO FINAL"
echo "============================================================"

# ------------------------------------------------------------
# REDE
# ------------------------------------------------------------

echo
echo "-------------------- REDE --------------------"
echo

ip -br addr

# ------------------------------------------------------------
# KEA
# ------------------------------------------------------------

echo
echo "-------------------- KEA ---------------------"
echo

if systemctl is-active --quiet kea-dhcp4-server; then

    echo -e "${GREEN}[OK]${NC} Kea DHCP ativo"

else

    echo -e "${RED}[ERRO]${NC} Kea DHCP não está ativo"

fi

# ------------------------------------------------------------
# TFTP
# ------------------------------------------------------------

echo
echo "-------------------- TFTP --------------------"
echo

if systemctl is-active --quiet tftpd-hpa; then

    echo -e "${GREEN}[OK]${NC} TFTP ativo"

else

    echo -e "${RED}[ERRO]${NC} TFTP não está ativo"

fi

# ------------------------------------------------------------
# NFS
# ------------------------------------------------------------

echo
echo "-------------------- NFS ---------------------"
echo

if systemctl is-active --quiet nfs-kernel-server; then

    echo -e "${GREEN}[OK]${NC} NFS ativo"

else

    echo -e "${RED}[ERRO]${NC} NFS não está ativo"

fi

# ------------------------------------------------------------
# FTP
# ------------------------------------------------------------

echo
echo "-------------------- FTP ---------------------"
echo

if systemctl is-active --quiet vsftpd; then

    echo -e "${GREEN}[OK]${NC} vsftpd ativo"

else

    echo -e "${RED}[ERRO]${NC} vsftpd não está ativo"

fi

# ------------------------------------------------------------
# PXE
# ------------------------------------------------------------

echo
echo "---------------- ARQUIVOS PXE ----------------"
echo

FILES=(

    "$TFTP_DIR/undionly.kpxe"

    "$TFTP_DIR/snponly.efi"

    "$TFTP_DIR/i386-efi/snponly.efi"

    "$TFTP_DIR/arm64-efi/snponly.efi"

)

for FILE in "${FILES[@]}"; do

    if [[ -f "$FILE" ]]; then

        SIZE=$(stat -c%s "$FILE")

        if [[ "$SIZE" -gt 0 ]]; then

            echo -e "${GREEN}[OK]${NC} $FILE ($SIZE bytes)"

        else

            echo -e "${RED}[ERRO]${NC} $FILE está vazio"

        fi

    else

        echo -e "${YELLOW}[AVISO]${NC} $FILE não encontrado"

    fi

done

# ------------------------------------------------------------
# FOG KERNEL
# ------------------------------------------------------------

echo
echo "---------------- FOG KERNEL ------------------"
echo

FOG_WEB_IPXE="/var/www/fog/service/ipxe"

if [[ ! -d "$FOG_WEB_IPXE" ]]; then
    FOG_WEB_IPXE="/var/www/html/fog/service/ipxe"
fi

for FILE in \
    "$FOG_WEB_IPXE/bzImage" \
    "$FOG_WEB_IPXE/init.xz"
do

    if [[ -f "$FILE" ]]; then

        echo -e "${GREEN}[OK]${NC} $FILE"

    else

        echo -e "${YELLOW}[AVISO]${NC} $FILE não encontrado"

    fi

done

# ------------------------------------------------------------
# IMAGES
# ------------------------------------------------------------

echo
echo "----------------- /images --------------------"
echo

ls -ld /images 2>/dev/null || true
ls -ld /images/dev 2>/dev/null || true

# ------------------------------------------------------------
# NFS EXPORTS
# ------------------------------------------------------------

echo
echo "--------------- EXPORTS NFS ------------------"
echo

exportfs -v || true

# ------------------------------------------------------------
# PORTAS
# ------------------------------------------------------------

echo
echo "------------------ PORTAS --------------------"
echo

echo
echo "UDP:"
ss -lunp | grep -E ':67|:69' || true

echo
echo "TCP:"
ss -ltnp | grep -E ':21|:80|:443' || true

# ------------------------------------------------------------
# HTTP
# ------------------------------------------------------------

echo
echo "------------------- HTTP ---------------------"
echo

if curl -fsS \
    --connect-timeout 5 \
    "http://${FOG_IP}/fog/" \
    >/dev/null 2>&1
then

    echo -e "${GREEN}[OK]${NC} Interface Web FOG respondendo."

else

    echo -e "${YELLOW}[AVISO]${NC} Interface Web FOG ainda não respondeu."

fi

# ------------------------------------------------------------
# BOOT.PHP
# ------------------------------------------------------------

echo
echo "---------------- BOOT.PHP --------------------"
echo

if curl -fsS \
    --connect-timeout 5 \
    "http://${FOG_IP}/fog/service/ipxe/boot.php" \
    >/dev/null 2>&1
then

    echo -e "${GREEN}[OK]${NC} boot.php respondendo."

else

    echo -e "${YELLOW}[AVISO]${NC} boot.php não respondeu."

fi

# ============================================================
# RESULTADO
# ============================================================

echo
echo
echo "============================================================"
echo "          CONFIGURAÇÃO DO FOG LAB CONCLUÍDA"
echo "============================================================"
echo
echo "Servidor FOG:"
echo
echo "    http://${FOG_IP}/fog/"
echo
echo "Interface PXE:"
echo
echo "    ${FOG_INTERFACE}"
echo
echo "Rede:"
echo
echo "    ${NETWORK}"
echo
echo "DHCP:"
echo
echo "    ${DHCP_START}"
echo "       até"
echo "    ${DHCP_END}"
echo
echo "TFTP:"
echo
echo "    ${TFTP_DIR}"
echo
echo "Imagens:"
echo
echo "    ${IMAGES_DIR}"
echo
echo "Backup:"
echo
echo "    ${BACKUP_DIR}"
echo
echo "Log:"
echo
echo "    ${LOG_FILE}"
echo
echo "============================================================"
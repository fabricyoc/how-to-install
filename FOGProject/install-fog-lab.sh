#!/usr/bin/env bash

# ============================================================
# FOG LAB - Instalação e configuração automatizada
#
# Debian 13 + FOG Project + Kea + iPXE + NFS + TFTP + FTP
#
# Ambiente esperado:
#
#   Interface LAN/PXE  : enp0s3
#   IP FOG             : 192.168.0.1
#   Rede               : 192.168.0.0/24
#   DHCP               : 192.168.0.100 - 192.168.0.200
#
#   Interface Internet : enp0s8
#
# Uso:
#
#   chmod +x install-fog-lab.sh
#   sudo ./install-fog-lab.sh
#
# ============================================================


# ============================================================
# CONFIGURAÇÃO DO BASH
# ============================================================

# Não utilizamos "set -e".
#
# Isso é proposital para evitar que o script inteiro pare
# devido a um erro intermediário do instalador do FOG
# ou de algum serviço.
#
# -u        = erro ao usar variável não definida
# pipefail  = detecta erro dentro de pipelines
#
set -uo pipefail


# ============================================================
# VARIÁVEIS PRINCIPAIS
# ============================================================

FOG_IP="192.168.0.1"

FOG_INTERFACE="enp0s3"

INTERNET_INTERFACE="enp0s8"

NETWORK="192.168.0.0/24"

PREFIX="24"

NETMASK="255.255.255.0"

DHCP_START="192.168.0.100"

DHCP_END="192.168.0.200"


# ============================================================
# DIRETÓRIOS
# ============================================================

FOG_DIR="/opt/fogproject"

IPXE_DIR="/opt/ipxe"

TFTP_DIR="/srv/tftp"

IMAGES_DIR="/images"


# ============================================================
# REPOSITÓRIOS
# ============================================================

FOG_REPO="https://github.com/FOGProject/fogproject.git"

IPXE_REPO="https://github.com/ipxe/ipxe.git"


# ============================================================
# BACKUP E LOG
# ============================================================

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

    echo
    echo -e "${BLUE}[INFO]${NC} $*"

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


# ============================================================
# FUNÇÃO DE BACKUP
# ============================================================

backup_file() {

    local file="$1"

    if [[ -f "$file" || -L "$file" ]]; then

        mkdir -p "$BACKUP_DIR"

        local name

        name="$(basename "$file")"

        cp -a "$file" \
            "$BACKUP_DIR/${name}.$(date +%H%M%S).bak" \
            2>/dev/null || true

        ok "Backup realizado: $file"

    fi

}


# ============================================================
# VERIFICAR SE SERVIÇO EXISTE
# ============================================================

service_exists() {

    systemctl list-unit-files \
        --type=service \
        --no-legend \
        2>/dev/null |
        awk '{print $1}' |
        grep -qx "$1.service"

}


# ============================================================
# REINICIAR SERVIÇO SEM PARAR O SCRIPT
# ============================================================

restart_service() {

    local service="$1"

    if service_exists "$service"; then

        info "Reiniciando $service..."

        systemctl restart "$service" 2>/dev/null

        if systemctl is-active --quiet "$service"; then

            ok "$service ativo."

        else

            warn "$service não ficou ativo."

        fi

    else

        warn "Serviço $service não encontrado."

    fi

}


# ============================================================
# HABILITAR SERVIÇO
# ============================================================

enable_service() {

    local service="$1"

    if service_exists "$service"; then

        systemctl enable "$service" >/dev/null 2>&1 || true

    fi

}


# ============================================================
# LOG
# ============================================================

mkdir -p "$(dirname "$LOG_FILE")"

touch "$LOG_FILE"

exec > >(tee -a "$LOG_FILE") 2>&1


# ============================================================
# CABEÇALHO
# ============================================================

clear

echo "============================================================"
echo "             INSTALADOR AUTOMÁTICO FOG LAB"
echo "============================================================"
echo
echo "Servidor FOG"
echo "  IP................: $FOG_IP"
echo "  Interface PXE.....: $FOG_INTERFACE"
echo
echo "Rede"
echo "  Rede..............: $NETWORK"
echo "  Máscara...........: $NETMASK"
echo
echo "DHCP"
echo "  Inicial...........: $DHCP_START"
echo "  Final.............: $DHCP_END"
echo
echo "Internet"
echo "  Interface.........: $INTERNET_INTERFACE"
echo
echo "============================================================"


# ============================================================
# 1. VERIFICAR ROOT
# ============================================================

info "Verificando privilégios..."

if [[ "$EUID" -ne 0 ]]; then

    die "Execute com sudo ou diretamente como root."

fi

ok "Executando como root."


# ============================================================
# 2. IDENTIFICAR SISTEMA
# ============================================================

info "Identificando sistema operacional..."

if [[ ! -f /etc/os-release ]]; then

    die "Não foi possível identificar o sistema operacional."

fi

source /etc/os-release

echo "Sistema detectado: $PRETTY_NAME"


# ============================================================
# 3. VERIFICAR INTERFACES
# ============================================================

info "Verificando interfaces de rede..."

if ! ip link show "$FOG_INTERFACE" >/dev/null 2>&1; then

    die "Interface $FOG_INTERFACE não encontrada."

fi

ok "$FOG_INTERFACE encontrada."


if ! ip link show "$INTERNET_INTERFACE" >/dev/null 2>&1; then

    die "Interface $INTERNET_INTERFACE não encontrada."

fi

ok "$INTERNET_INTERFACE encontrada."


# ============================================================
# 4. CRIAR DIRETÓRIO DE BACKUP
# ============================================================

info "Criando diretório de backup..."

mkdir -p "$BACKUP_DIR"

ok "$BACKUP_DIR"


# ============================================================
# 5. BACKUPS INICIAIS
# ============================================================

backup_file "/etc/network/interfaces"

backup_file "/etc/kea/kea-dhcp4.conf"

backup_file "/etc/exports"

backup_file "/etc/vsftpd.conf"

backup_file "/etc/default/tftpd-hpa"


# ============================================================
# 6. CONFIGURAR REDE
# ============================================================

info "Configurando /etc/network/interfaces..."

cat > /etc/network/interfaces <<EOF
source /etc/network/interfaces.d/*

# ============================================================
# Loopback
# ============================================================

auto lo
iface lo inet loopback


# ============================================================
# Interface interna FOG / PXE
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

ok "/etc/network/interfaces configurado."


# ============================================================
# 7. CONFIGURAR IP IMEDIATAMENTE
# ============================================================

info "Aplicando IP $FOG_IP em $FOG_INTERFACE..."

ip link set "$FOG_INTERFACE" up || true

ip addr flush dev "$FOG_INTERFACE" || true

ip addr add "${FOG_IP}/${PREFIX}" dev "$FOG_INTERFACE" || true

ok "Interface PXE configurada."


# ============================================================
# 8. ATUALIZAR REPOSITÓRIOS
# ============================================================

info "Atualizando repositórios..."

apt-get update || warn "apt update retornou erro."


# ============================================================
# 9. ATUALIZAR SISTEMA
# ============================================================

info "Atualizando pacotes instalados..."

DEBIAN_FRONTEND=noninteractive \
apt-get upgrade -y || warn "apt upgrade retornou erro."


# ============================================================
# 10. INSTALAR DEPENDÊNCIAS
# ============================================================

info "Instalando dependências..."

DEBIAN_FRONTEND=noninteractive \
apt-get install -y \
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
    ca-certificates \
    iproute2 \
    net-tools \
    nfs-common \
    || warn "Algumas dependências podem não ter sido instaladas."

ok "Etapa de dependências concluída."


# ============================================================
# 11. SSH
# ============================================================

info "Configurando SSH..."

systemctl enable ssh >/dev/null 2>&1 || true

systemctl restart ssh 2>/dev/null || true

if systemctl is-active --quiet ssh; then

    ok "SSH ativo."

else

    warn "SSH não está ativo."

fi


# ============================================================
# 12. CLONAR FOG
# ============================================================

info "Preparando FOG Project..."

if [[ -d "$FOG_DIR/.git" ]]; then

    warn "FOG já existe em $FOG_DIR."

    cd "$FOG_DIR" || die "Não foi possível acessar $FOG_DIR"

    git pull || warn "Não foi possível atualizar o FOG."

else

    rm -rf "$FOG_DIR"

    git clone "$FOG_REPO" "$FOG_DIR" \
        || die "Não foi possível baixar o FOG."

fi

ok "FOG disponível em $FOG_DIR."


# ============================================================
# 13. EXECUTAR INSTALADOR DO FOG
# ============================================================

echo
echo "============================================================"
echo "              INSTALADOR OFICIAL DO FOG"
echo "============================================================"
echo
echo "Respostas recomendadas:"
echo
echo "Sistema:"
echo "    Debian"
echo
echo "Modo:"
echo "    Normal"
echo
echo "Interface:"
echo "    $FOG_INTERFACE"
echo
echo "Router:"
echo "    $FOG_IP"
echo
echo "FOG como DHCP:"
echo "    Sim"
echo
echo "DHCP controlando DNS:"
echo "    Não"
echo
echo "HTTPS:"
echo "    Não"
echo
echo "IMPORTANTE:"
echo
echo "Se aparecer erro relacionado ao Kea no final da instalação,"
echo "não há problema."
echo
echo "O script continuará e substituirá a configuração do Kea."
echo
echo "============================================================"
echo


cd "$FOG_DIR/bin" || die "Diretório bin do FOG não encontrado."


# ------------------------------------------------------------
# Desabilitar comportamento de aborto para o instalador
# ------------------------------------------------------------

./installfog.sh

FOG_INSTALL_RESULT=$?


echo
echo "============================================================"

if [[ "$FOG_INSTALL_RESULT" -ne 0 ]]; then

    warn "O instalador FOG retornou código $FOG_INSTALL_RESULT."

    warn "O erro será ignorado."

    warn "Continuando a configuração automática do laboratório."

else

    ok "Instalador FOG concluído."

fi

echo "============================================================"


# ============================================================
# 14. CONFIGURAR KEA
# ============================================================

info "Configurando Kea DHCP..."

mkdir -p /etc/kea

chmod 755 /etc/kea || true

backup_file "/etc/kea/kea-dhcp4.conf"


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


chown root:root /etc/kea/kea-dhcp4.conf || true

chmod 644 /etc/kea/kea-dhcp4.conf || true

chmod 755 /etc/kea || true


if [[ -f /etc/kea/kea-dhcp4.conf ]]; then

    ok "/etc/kea/kea-dhcp4.conf criado."

else

    warn "Não foi possível confirmar a criação do arquivo do Kea."

fi


# ============================================================
# 15. PREPARAR TFTP
# ============================================================

info "Preparando TFTP..."

mkdir -p "$TFTP_DIR"

chmod 755 "$TFTP_DIR" || true

ok "$TFTP_DIR preparado."


# ============================================================
# 16. CONFIGURAR TFTPD-HPA
# ============================================================

info "Configurando tftpd-hpa..."

backup_file "/etc/default/tftpd-hpa"


cat > /etc/default/tftpd-hpa <<EOF
TFTP_USERNAME="tftp"

TFTP_DIRECTORY="${TFTP_DIR}"

TFTP_ADDRESS=":69"

TFTP_OPTIONS="--secure"
EOF


ok "tftpd-hpa configurado."


# ============================================================
# 17. CLONAR iPXE
# ============================================================

info "Preparando iPXE..."

if [[ -d "$IPXE_DIR/.git" ]]; then

    warn "iPXE já existe em $IPXE_DIR."

    cd "$IPXE_DIR" || die "Não foi possível acessar $IPXE_DIR"

    git pull || warn "Não foi possível atualizar iPXE."

else

    rm -rf "$IPXE_DIR"

    git clone "$IPXE_REPO" "$IPXE_DIR" \
        || warn "Não foi possível clonar o iPXE."

fi


# ============================================================
# 18. VERIFICAR DIRETÓRIO DO iPXE
# ============================================================

if [[ ! -d "$IPXE_DIR/src" ]]; then

    warn "Diretório $IPXE_DIR/src não encontrado."

else

    ok "Código-fonte do iPXE encontrado."

fi


# ============================================================
# 19. CRIAR SCRIPT EMBUTIDO DO iPXE
# ============================================================

if [[ -d "$IPXE_DIR/src" ]]; then

    info "Criando fog-embed.ipxe..."

    cd "$IPXE_DIR/src" || true


    cat > fog-embed.ipxe <<EOF
#!ipxe

set arch \${buildarch}

iseq \${arch} i386 && cpuid --ext 29 && set arch x86_64 ||

params

param mac0 \${net0/mac}

param arch \${arch}

param platform \${platform}

param product \${product}

param manufacturer \${manufacturer}

param ipxever \${version}

param filename \${filename}

param sysuuid \${uuid}

chain http://${FOG_IP}/fog/service/ipxe/boot.php##params
EOF


    ok "fog-embed.ipxe criado."

fi


# ============================================================
# 20. HABILITAR PARAM_CMD
# ============================================================

if [[ -d "$IPXE_DIR/src" ]]; then

    info "Habilitando PARAM_CMD..."

    cd "$IPXE_DIR/src" || true

    mkdir -p config/local


    cat > config/local/general.h <<EOF
#define PARAM_CMD
EOF


    ok "PARAM_CMD habilitado."

fi


# ============================================================
# 21. COMPILAR UNDIONLY.KPXE
# ============================================================

if [[ -d "$IPXE_DIR/src" ]]; then

    info "Compilando undionly.kpxe..."

    cd "$IPXE_DIR/src" || true


    make clean || warn "make clean retornou erro."


    make bin/undionly.kpxe \
        EMBED=fog-embed.ipxe


    MAKE_RESULT=$?


    if [[ "$MAKE_RESULT" -eq 0 && -s bin/undionly.kpxe ]]; then

        ok "undionly.kpxe compilado."

    else

        warn "Falha ao compilar undionly.kpxe."

    fi

fi


# ============================================================
# 22. COPIAR UNDIONLY.KPXE
# ============================================================

if [[ -s "$IPXE_DIR/src/bin/undionly.kpxe" ]]; then

    info "Copiando undionly.kpxe para TFTP..."

    cp -f \
        "$IPXE_DIR/src/bin/undionly.kpxe" \
        "$TFTP_DIR/undionly.kpxe"


    chmod 644 "$TFTP_DIR/undionly.kpxe" || true


    ok "$TFTP_DIR/undionly.kpxe instalado."

else

    warn "undionly.kpxe não está disponível para cópia."

fi


# ============================================================
# 23. CONFIGURAR /images
# ============================================================

info "Preparando diretório de imagens..."

mkdir -p "$IMAGES_DIR"

mkdir -p "$IMAGES_DIR/dev"

mkdir -p "$IMAGES_DIR/postdownloadscripts"

touch "$IMAGES_DIR/.mntcheck"


if id fogproject >/dev/null 2>&1; then

    chown -R fogproject:fogproject "$IMAGES_DIR" || true

    ok "Proprietário de /images definido como fogproject."

else

    warn "Usuário fogproject não foi encontrado."

fi


chmod -R 775 "$IMAGES_DIR" || true

ok "$IMAGES_DIR preparado."


# ============================================================
# 24. CONFIGURAR NFS
# ============================================================

info "Configurando NFS..."

backup_file "/etc/exports"


cat > /etc/exports <<EOF
/images *(ro,sync,no_wdelay,insecure_locks,no_root_squash,insecure)

/images/dev *(rw,async,no_wdelay,no_root_squash,insecure)
EOF


exportfs -ra || warn "exportfs retornou erro."

ok "/etc/exports configurado."


# ============================================================
# 25. CONFIGURAR VSFTPD
# ============================================================

info "Configurando vsftpd..."

backup_file "/etc/vsftpd.conf"


if [[ ! -f /etc/vsftpd.conf ]]; then

    touch /etc/vsftpd.conf

fi


# ------------------------------------------------------------
# local_enable
# ------------------------------------------------------------

if grep -qE '^[#[:space:]]*local_enable=' \
    /etc/vsftpd.conf
then

    sed -i \
        's/^[#[:space:]]*local_enable=.*/local_enable=YES/' \
        /etc/vsftpd.conf

else

    echo "local_enable=YES" >> /etc/vsftpd.conf

fi


# ------------------------------------------------------------
# write_enable
# ------------------------------------------------------------

if grep -qE '^[#[:space:]]*write_enable=' \
    /etc/vsftpd.conf
then

    sed -i \
        's/^[#[:space:]]*write_enable=.*/write_enable=YES/' \
        /etc/vsftpd.conf

else

    echo "write_enable=YES" >> /etc/vsftpd.conf

fi


ok "vsftpd configurado."


# ============================================================
# 26. RECARREGAR SYSTEMD
# ============================================================

info "Recarregando systemd..."

systemctl daemon-reload || true


# ============================================================
# 27. HABILITAR SERVIÇOS
# ============================================================

info "Habilitando serviços..."

enable_service "kea-dhcp4-server"

enable_service "tftpd-hpa"

enable_service "nfs-kernel-server"

enable_service "vsftpd"

enable_service "apache2"

enable_service "mariadb"


# ============================================================
# 28. REINICIAR SERVIÇOS
# ============================================================

restart_service "kea-dhcp4-server"

restart_service "tftpd-hpa"

restart_service "nfs-kernel-server"

restart_service "vsftpd"

restart_service "apache2"

restart_service "mariadb"


# ============================================================
# 29. DIAGNÓSTICO FINAL
# ============================================================

echo
echo
echo "============================================================"
echo "                   DIAGNÓSTICO FINAL"
echo "============================================================"


# ============================================================
# REDE
# ============================================================

echo
echo "-------------------- REDE --------------------"
echo

ip -br addr || true


# ============================================================
# IP ESPERADO
# ============================================================

echo
echo "----------------- IP DO FOG ------------------"
echo

if ip addr show "$FOG_INTERFACE" |
    grep -q "${FOG_IP}/${PREFIX}"
then

    echo -e "${GREEN}[OK]${NC} $FOG_INTERFACE = $FOG_IP"

else

    echo -e "${YELLOW}[AVISO]${NC} IP $FOG_IP não encontrado em $FOG_INTERFACE"

fi


# ============================================================
# SERVIÇOS
# ============================================================

echo
echo "------------------ SERVIÇOS ------------------"
echo


for SERVICE in \
    kea-dhcp4-server \
    tftpd-hpa \
    nfs-kernel-server \
    vsftpd \
    apache2 \
    mariadb
do

    if service_exists "$SERVICE"; then

        if systemctl is-active --quiet "$SERVICE"; then

            echo -e "${GREEN}[OK]${NC} $SERVICE"

        else

            echo -e "${YELLOW}[AVISO]${NC} $SERVICE não está ativo"

        fi

    else

        echo -e "${YELLOW}[AVISO]${NC} $SERVICE não encontrado"

    fi

done


# ============================================================
# ARQUIVOS PXE
# ============================================================

echo
echo "---------------- ARQUIVOS PXE ----------------"
echo


PXE_FILES=(

    "$TFTP_DIR/undionly.kpxe"

    "$TFTP_DIR/snponly.efi"

    "$TFTP_DIR/i386-efi/snponly.efi"

    "$TFTP_DIR/arm64-efi/snponly.efi"

)


for FILE in "${PXE_FILES[@]}"; do

    if [[ -f "$FILE" ]]; then

        SIZE=$(stat -c%s "$FILE" 2>/dev/null || echo 0)


        if [[ "$SIZE" -gt 0 ]]; then

            echo -e \
                "${GREEN}[OK]${NC} $FILE ($SIZE bytes)"

        else

            echo -e \
                "${YELLOW}[AVISO]${NC} $FILE está vazio"

        fi

    else

        echo -e \
            "${YELLOW}[AVISO]${NC} $FILE não encontrado"

    fi

done


# ============================================================
# DIRETÓRIO /images
# ============================================================

echo
echo "------------------ /images -------------------"
echo


ls -ld "$IMAGES_DIR" 2>/dev/null || true

ls -ld "$IMAGES_DIR/dev" 2>/dev/null || true

ls -lah "$IMAGES_DIR" 2>/dev/null || true


# ============================================================
# NFS EXPORTS
# ============================================================

echo
echo "---------------- EXPORTS NFS -----------------"
echo

exportfs -v 2>/dev/null || true


# ============================================================
# PORTAS UDP
# ============================================================

echo
echo "---------------- PORTAS UDP ------------------"
echo

ss -lunp |
    grep -E ':67|:69' \
    || warn "Portas DHCP/TFTP não encontradas."


# ============================================================
# PORTAS TCP
# ============================================================

echo
echo "---------------- PORTAS TCP ------------------"
echo

ss -ltnp |
    grep -E ':21|:80|:443' \
    || warn "Portas FTP/HTTP não encontradas."


# ============================================================
# TESTAR INTERFACE WEB
# ============================================================

echo
echo "------------------ HTTP FOG ------------------"
echo


if curl \
    -fsS \
    --connect-timeout 5 \
    "http://${FOG_IP}/fog/" \
    >/dev/null 2>&1
then

    echo -e \
        "${GREEN}[OK]${NC} Interface Web FOG respondendo."

else

    echo -e \
        "${YELLOW}[AVISO]${NC} Interface Web FOG não respondeu."

fi


# ============================================================
# TESTAR BOOT.PHP
# ============================================================

echo
echo "------------------ BOOT.PHP ------------------"
echo


if curl \
    -fsS \
    --connect-timeout 5 \
    "http://${FOG_IP}/fog/service/ipxe/boot.php" \
    >/dev/null 2>&1
then

    echo -e \
        "${GREEN}[OK]${NC} boot.php respondendo."

else

    echo -e \
        "${YELLOW}[AVISO]${NC} boot.php não respondeu."

fi


# ============================================================
# MOSTRAR CONFIGURAÇÃO DO KEA
# ============================================================

echo
echo "-------------------- KEA ---------------------"
echo


if [[ -f /etc/kea/kea-dhcp4.conf ]]; then

    echo "Arquivo:"
    echo

    ls -lh /etc/kea/kea-dhcp4.conf

    echo

    echo "Interface configurada:"
    echo

    grep -n "$FOG_INTERFACE" \
        /etc/kea/kea-dhcp4.conf \
        || true


    echo

    echo "Boot files:"
    echo

    grep -n "boot-file-name" \
        /etc/kea/kea-dhcp4.conf \
        || true

else

    warn "/etc/kea/kea-dhcp4.conf não encontrado."

fi


# ============================================================
# MOSTRAR UNDIONLY
# ============================================================

echo
echo "--------------- UNDIONLY.KPXE ----------------"
echo


if [[ -f "$TFTP_DIR/undionly.kpxe" ]]; then

    ls -lh "$TFTP_DIR/undionly.kpxe"

else

    warn "undionly.kpxe não encontrado."

fi


# ============================================================
# RESULTADO
# ============================================================

echo
echo
echo "============================================================"
echo "             CONFIGURAÇÃO FOG LAB FINALIZADA"
echo "============================================================"
echo
echo "Servidor FOG:"
echo
echo "    http://${FOG_IP}/fog/"
echo
echo
echo "Interface PXE:"
echo
echo "    ${FOG_INTERFACE}"
echo
echo
echo "IP:"
echo
echo "    ${FOG_IP}"
echo
echo
echo "Rede:"
echo
echo "    ${NETWORK}"
echo
echo
echo "DHCP:"
echo
echo "    ${DHCP_START}"
echo "          até"
echo "    ${DHCP_END}"
echo
echo
echo "TFTP:"
echo
echo "    ${TFTP_DIR}"
echo
echo
echo "Imagens:"
echo
echo "    ${IMAGES_DIR}"
echo
echo
echo "Backup:"
echo
echo "    ${BACKUP_DIR}"
echo
echo
echo "Log:"
echo
echo "    ${LOG_FILE}"
echo
echo
echo "Próximo passo:"
echo
echo "    Configure uma máquina cliente para iniciar via PXE."
echo
echo "============================================================"
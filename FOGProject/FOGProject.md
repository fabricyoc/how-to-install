## Configuração do Ambiente

#### Softwares utilizados
* Ubuntu 24.04.4
* VirtualBox v7.2.14
* Debian 13.6.0
* [Fog Project](https://fogproject.org/)

---

#### Configurações da Máquina Virtual
- [x] VM Name: **server-fog**
- [x] ISO imagem: **debian-13.6.0-adm64-DVD-1.iso**
- [x] Desmarque: **Proceed with Unattended Installation**
- [x] Base Memory: **1024MB**
- [x] Number of CPUs: **2**

#### Configurações de Rede da Máquina Virtual
Adaptador de rede 01
> Ligado a: **Rede Interna**
> Nome: **fog-lab**
> Tipo de placa: **Intel PRO/1000 MT Desktop (82540EM)**
> Promiscuous Mode: **Permitir Tudo**

Adaptador de rede 02
> Ligado a: **Bridge**
> Nome: **wlp1s0**
> Tipo de placa: **Intel PRO/1000 MT Desktop (82540EM)**
> Promiscuous Mode: **Permitir Tudo**

---

#### Configurações básicas do servidor
Entrar como root
```bash
$ su -
```

Comentar 1ª linha do arquivo `sources.list`
```c
# nano /etc/apt/sources.list
```

Atualizar repositórios 
```c
# apt update -y; apt upgrade -y
```

Instalar utilitários
```c
# apt install openssh-server tcpdump git -y
```

Colocar usuário no grupo `sudo`, abra o arquivo `sudoers`
```c
# nano /etc/sudoers
```

Adicione a seguinte linha no arquivo `sudoers`
```bash 
usuario ALL=(ALL:ALL) ALL
```

Clone o repositório do FOG
```bash
$ git clone https://github.com/FOGProject/fogproject.git
```

Baixe o `ipxeboot.tar.gz`
```bash
$ wget https://boot.ipxe.org/ipxeboot.tar.gz
```

Abra o arquivo de configurações de rede
```bash
$ sudo nano /etc/network/interfaces
```

Adicione as configurações abaixo
```bash
source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
allow-hotplug enp0s3
iface enp0s3 inet static
	address 192.168.0.1
	netmask 255.255.255.0

# The secondary network interface
auto enp0s8
iface enp0s8 inet dhcp
```

Reinicie a placa de rede
```bash
$ sudo systemctl restart networking.service
```

---

#### Instalação do FOG Project

Mova o diretório do FOG para `/opt`
```bash
$ sudo mv fogproject/ /opt
```

Entre no diretório `bin`
```bash
$ cd /opt/fogproject/bin
```

Execute o instalador `installfog.sh`
```bash
$ sudo ./installfog.sh
```

Configurando o instalador do FOG
> What version of Linux would yout like to run the installation for? 
- [x] Choice: [2] (basta apertar em `Enter`, porque meu sistema é Debian e o FOG já o reconheceu)

> FOG Server installation modes. What type of installation would yout like to do? [N/s (Normal/Storage)]
- [x] N (basta apertar em `Enter`)

> We found the following interfaces on your system: 
> * enp0s8 - 192.168.3.91/24
> * enp0s3 - 192.168.0.1/24
> Would you like to change the default network interface from enp0s8?
- [x] Digitar `y` e clicar em `Enter` (quero alterar a interface de rede padrão)

> What network interface would you like to use?
- [x] Digitar `enp0s3` e clicar em `Enter`

> Would you like to setup a router address for the DHCP server?
- [x] Bastar apertar em `Enter`

> What is the IP address to be used for the router on?
- [x] Digitar `192.168.0.1` e clicar em `Enter`

> Would yout like DHCP to handle DNS? [Y/n]
- [x] Digitar `n` e clicar em `Enter`

> Would you like to use the FOG server for DHCP service? [y/N]
- [x] Digitar `y` e clicar em `Enter`

> This version of FOG has internationalization support, would you like to install the additional language packs? [y/N]
- [x] Digitar `y` e clicar em `Enter`

> Would you like to enable secure HTTPS on your FOG server? [y/N]
- [x] Bastar apertar em `Enter`

> Which hostname would you like to use? [...] Would you like to change it? If you are not sure, select No. [y/N]
- [x] Bastar apertar em `Enter`

> We would like to collect the following information:
> 1. OS Name
> 2. OS Version
> 3. FOG Version
> What is this information used for? We would like to simply track the common types of OS being used, along with the OS Version, and the various version of FOG being used. 
> Are you ok with sending this information? [Y/n]
- [x] Bastar apertar em `Enter`

> **Neste momento aparecerá um resumo das configurações selecionadas, verifique-as!**
> Are you sure you wish to continue (Y/N)?
- [x] Digitar `Y` e clicar em `Enter`
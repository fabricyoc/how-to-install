## Instalação do Raspberry Pi Pico W

Verifique se a versão das dependências é igual ou superior a 2.32
```bash
$ ldd --version
```

Atualize o sistema
```bash
$ sudo apt update
```

Realize as instalações abaixo
```bash
$ sudo apt install cmake gcc-arm-none-eabi libnewlib-arm-none-eabi build-essential git
```

Crie o diretório pico e o acesse
```bash
$ mkdir -p ~/pico; cd ~/pico;
```

Clone o repositório do Raspberry Pi Pico W
```bash
$ git clone -b master https://github.com/raspberrypi/pico-sdk.git
```

Acesse o diretório clonado
```bash
$ cd pico-sdk
```

Atualize e inicie os submódulos
```bash
$ git submodule update --init
```

Adicione o pico-sdk ao path do sistema
```bash
$ echo "export PICO_SDK_PATH=~/pico/pico-sdk" >> ~/.bashrc
```

Atualize o bashrc
```bash
$ source ~/.bashrc
```

## Configuração no VS Code
* Instale a extensão C/C++
* Instale a extensão Raspberry Pi Pico
* Utilize o código abaixo para **testar** a instalação:
```c
#include <stdio.h>
#include "pico/stdlib.h"
#include "hardware/pio.h"

int main()
{
    uint led = 13;
    stdio_init_all();
    gpio_init(led);
    gpio_set_dir(led, GPIO_OUT);
    while (true)
    {
        gpio_put(led, true);
        sleep_ms(2000);
        gpio_put(led, false);
        sleep_ms(2000);
    }
}
```

## Possíveis erros
* Picotool não conseguiu se conectar (_RP2040 device at bus 1, address 7 appears to be in BOOTSEL mode, but picotool was unable to connect. Maybe try 'sudo' or check your permissions_)
Conecte a Raspberry e configure o **bootsel**
Verifique se o dispositivo RPI-RP2 está disponível
~~~bash
$ lsblk
~~~
Adicione uma regraao **udev** para permitir acesso ao dispositivo sem **sudo**
~~~bash
$ sudo nano /etc/udev/rules.d/99-rp2040.rules
~~~
Adicione o conteúdo
~~~bash
SUBSYSTEM=="usb", ATTR{idVendor}=="2e8a", ATTR{idProduct}=="0003", MODE="0666", GROUP="plugdev"
~~~
Salve e saia do **nano**
~~~bash
CTRL + O
ENTER
CTRL + X
~~~
Recarregue as regras do **udev**
~~~bash
$ sudo udevadm control --reload-rules
~~~
Aplique as regras do **udev**
~~~bash
$ sudo udevadm trigger
~~~
Adicione o usuário ao grupo **plugdev**
~~~bash
$ sudo usermod -aG plugdev $USER
~~~
Reinicie o sistema ou faça logout/login

## Autores

- [@fabricyoc](https://www.github.com/fabricyoc)

## Referências
- [@BitDogLab](https://github.com/BitDogLab)

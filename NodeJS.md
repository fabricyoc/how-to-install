## Instalação do NodeJS

Realize o _download_ da versão LTS do NodeJS
- [Baixe o NodeJS](https://nodejs.org)

Descompacte o arquivo **tar.xz**
```bash
$ tar -xvf node-vX.tar.xz
```

Mova o diretório extraído para o /opt
```bash
$ sudo mv node-vX/ /opt/
```

Edite o arquivo bashrc
```bash
$ nano ~/.bashrc
```

Adicione a linha abaixo no bashrc
```bash
export PATH=/opt/node-vX/bin:$PATH
```

Saia do editor nano
```bash
CTRL + O
ENTER
CTRL + X
```

Aplique as alterações no bashrc
```bash
$ source ~/.bashrc
```

Verifique se foi instalado
```bash
$ node -v
```
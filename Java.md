## Instalação do Java

Instale o OpenJDK (21 é a versão instalada)
```bash
$ sudo apt install openjdk-21-jdk
```

## Ambientes de desenvolvimento

### Eclipse IDE
Baixe  Eclipse IDE para desenvolvedores Java
* [Clique para baixar](https://www.eclipse.org/downloads/packages/)

Descompacte o arquivo baixado
```bash
$ tar -xvfz eclipse.tar.gz
```

Mova o diretório extraído para /opt/
```bash
$ sudo /opt/eclipse
```

Crie o arquivo eclipse.desktop
```bash
$ sudo nano /usr/share/applications/eclipse.desktop
```

Adicione a configuração dentro do arquivo
```bash
[Desktop Entry]
Name=Eclipse
Comment=IDE para desenvolvedores
Exec=/caminho/para/eclipse/eclipse
Icon=/caminho/para/eclipse/icon.xpm
Terminal=false
Type=Application
Categories=Development;IDE;
```

Para sair do editor nano
```bash
CTRL + O
ENTER
CTRL + X
```

Dê permissão de execução para o Eclipse
```bash
$ sudo chmod +x /opt/eclipse/eclipse
```

### VS Code
Instale a extensão _Extension Pack for Java_ da Microsoft

* [Extensão](https://code.visualstudio.com/docs/java/extensions)

Para executar os arquivos Java
```bash
F5
```

Limpe a tela de saída colocando o código no método main()
```bash
System.out.print("\033[H\033[2J");
```
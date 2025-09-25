## Instalação do MongoDB Server
> O MongoDB Server é o serviço (em linha de comando) do Mongo que permite a manipulação dos documentos.

Baixe o MongoDB Server Community
* [Clique para baixar](https://www.mongodb.com/products/self-managed/community-edition)

Vá até o diretório do arquivo baixado e rode:
```bash
$ sudo dpkg -i mongodb-org-server.deb
```

Execute o comando:
```bash
$ sudo systemctl status mongod.service
```

Se o serviço estiver **desativado**, execute:
```bash
$ sudo systemctl start mongod.service
```

## Instação do MongoDB Compass (GUI)
> O MongoDB Compass GUI é uma interface gráfica para o MongoDB que traz consigo o **mongosh**, o shell do MongoDB.

Baixe o MongoDB Compass
* [Clique para baixar](https://www.mongodb.com/products/tools/compass)


Vá até o diretório do arquivo baixado e rode:
```bash
$ sudo dpkg -i mongodb-compass.deb 
```
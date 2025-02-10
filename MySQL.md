## Instalação do MySQL no Ubuntu

Instale o MySQL
```bash
$ sudo apt install mysql-server
```

Entre como root
```bash
$ sudo -i
```

Acesse o MySQL como root
```bash
# mysql
```

Crie um novo usuário no MySQL
```bash
CREATE USER 'usuario'@'localhost' IDENTIFIED BY 'senha';
```

Atribua as permissões ao novo usuário
```bash
GRANT ALL PRIVILEGES ON *.* TO 'usuario'@'localhost';
```

Caso não queira o serviço iniciando com o boot da máquina
```bash
sudo systemctl disable mysql.service
```

Ativar/desativar o serviço
```bash
sudo /etc/init.d/mysql start|stop
```

Se houver retorno, está instalado corretamente
```bash
$ mysql --version
```

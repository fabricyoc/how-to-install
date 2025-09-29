## Usuários
> Gestão de usuários no sistema operacional Linux

Verificar se o usuário tem permissão de *root*:
```bash
$ sudo whoami
```

Cria um novo usuário:
```bash
$ sudo adduser novo_usuario
```

Adiciona o usuário ao grupo **sudoers**:
```bash
$ sudo usermod -aG sudo novo_usuario
```

Altera a senha do usuário:
```bash
$ sudo passwd nome_usuario
```

Remove o usuário do grupo **sudo**:
```bash
$ sudo deluser nome_usuario sudo
```
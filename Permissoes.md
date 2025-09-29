# Permissões no Linux
> Permissões são um mecanismo de segurança que controla o acesso a arquivos e diretórios, definindo quais usuários e grupos podem realizar ações como leitura (r), gravação (w) ou execução (x)
>> No Linux, as permissões são representadas por **números** (em octal) ou por **letras** (r, w, x).

## Permissões em valores:
* **1** refere-se a execução (**x**)
    * O usuário pode **executar** o arquivo ou **entrar** em um diretório

* **2** refere-se a escrita (**w**)
    * O usuário pode **modificar** o arquivo dentro de um diretório.

* **4** refere-se a leitura (**r**)
    * O usuário pode **ler** o conteúdo de um arquivo ou **listar** arquivos dentro de um diretório.

## Combinações possíveis:
> As permissões podem se somar
* 3 (2+1) → escrita + execução (w+x)
* 5 (4+1) → leitura + execução (r+x)
* 6 (4+2) → leitura + escrita (r+w)
* 7 (4+2+1) → leitura + escrita + execução (r+w+x)

## Estrutura de permissões

Um arquivo no Linux tem permissões para três categorias:

1. **Usuário (u)** → dono do arquivo
2. **Grupo (g)** → membros do grupo do arquivo
3. **Outros (o)** → todos os demais usuários

Exemplo 01:
```bash
$ chmod 754 arquivo.txt
```

* `7 (rwx)` → dono pode tudo
* `5 (r-x)` → grupo pode ler e executar
* `4 (r--)` → outros podem apenas ler

Exemplo 02:
![Esta imagem não foi carregada!](https://blog.ironlinux.com.br/images/blog-posts/uploads/2022/04/permissions-linux.png)
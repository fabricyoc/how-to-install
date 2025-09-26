## GCC
> Instação do GCC para compilar códigos em C no Windows **sem ter acesso ao administrador**

Baixe o arquivo *.zip de acordo com sua arquitetura (Win32 ou Win64)
* [Clique aqui](https://winlibs.com/)
* [Clique aqui para *download* direto com Win64](https://github.com/brechtsanders/winlibs_mingw/releases/download/15.2.0posix-13.0.0-ucrt-r1/winlibs-x86_64-posix-seh-gcc-15.2.0-mingw-w64ucrt-13.0.0-r1.7z)

Extraia os diretórios/arquivos
* Utilize [7-Zip](https://www.7-zip.org/) ou [WinRAR](https://www.win-rar.com/start.html?&L=9.)

Dentro do diretório extraído haverá o **mingw64**
* Mova esse diretório para `C:`

## Configuração do Windows
> Esta é a parte mais complexa do processo, portanto é necessário seguir o passo a passo, de forma rigorosa, para o êxito da instalação.

1. Clique no botão com a `Bandeira do Windows`
2. Busque por `Editar as variáveis de ambiente para sua conta`
3. Vá em `Variáveis de Ambiente...`
4. No campo de `Variáveis de usuário para XXXXX` 
    1. Clique em `Novo...`
5. Na `Nova Variável do Usuário`
    1. Coloque o valor **gcc** para `Nome da variável`
    2. Coloque o caminho (`c:\mingw64\bin`) do binário para `Valor da variável`
    3. Clique em **OK**
6. Ainda em `Variáveis de usuário para XXXXX`
    1. Dê duplo clique em `Path`
    2. Clique em `Novo`
    3. Adicione `%gcc%`
    4. Clique em **OK**
    5. Clique em **OK** novamente
    6. Clique em **OK** novamente


## Para testar o GCC do Windows
1. Abra o CMD (*Prompt de Comando*) do Windows
2. Digite `gcc` e clique em **Enter**
3. Se aparecer `gcc: fatal error`, o GCC foi instalado corretamente

## Configuração do VSCode
1. Baixe e instale extensão **C/C++ Compile Run** do usuário danielpinto8zz6 para compilar os códigos com apenas um clique.
## Instalação do Composer

Crie o arquivo
```bash
$ php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
```

Verifique a integridade
```bash
$ php -r "if (hash_file('sha384', 'composer-setup.php') === 'dac665fdc30fdd8ec78b38b9800061b4150413ff2e3b6f88543c636f7cd84f6db9189d43a81e5503cda447da73c7e5b6') { echo 'Installer verified'.PHP_EOL; } else { echo 'Installer corrupt'.PHP_EOL; unlink('composer-setup.php'); exit(1); }"
```

Execute o instalador
```bash
$ php composer-setup.php

```

Finalize a instalação
```bash
$ php -r "unlink('composer-setup.php');"
```

Configure o Composer para as variáveis de ambiente
```bash
# mv composer.phar /usr/local/bin/composer
```

Dê a permissão de execução
```bash
# chmod +x /usr/local/bin/composer
```
## Documentação

[Documentação](https://getcomposer.org/)
# Script de Sincronização e Validação de Acesso

## Objetivo:

Este script foi desenvolvido para realizar a sincronização de listas de domínios com o servidor Unbound a partir de uma API externa. Além disso, ele realiza uma validação de acesso antes de prosseguir com a sincronização, garantindo que a execução só ocorra quando o IP do servidor tiver permissão.

## Funcionalidades:

### Validação de Acesso:
Antes de realizar o download da lista de domínios, o script faz uma validação de acesso consultando a API ACL (https://anablock.net.br/acl.php). O retorno da API indica se o IP do servidor tem permissão de acesso. Se o retorno for ACCESS-DENIED, o script gera um log detalhado e interrompe a execução. O conteúdo completo da resposta da API é registrado no log quando o modo de debug está ativado.

### Download de Lista de Domínios:
Se o acesso for permitido, o script faz o download da lista de domínios da URL fornecida (https://api.anablock.net.br/api/domains/all?) e salva o conteúdo em um arquivo de configuração (/etc/unbound/local.d/dns-block.conf). O script também constrói dinamicamente a URL com base nos parâmetros como APP, MODE, IPv4, e IPv6.

### Backup e Atualização:
Antes de remover o arquivo de configuração antigo, o script cria um backup do arquivo (/etc/unbound/local.d/dns-block.conf.bak). Após o download, o arquivo de configuração é atualizado, e o backup é mantido como contingência.

### Validação da Configuração do Unbound:
O script usa o comando unbound-checkconf para verificar se a nova configuração não possui erros. Se houver erros, o script registra o problema nos logs e interrompe a execução.

### Recarregamento do Unbound:
Após uma configuração válida, o script recarrega o Unbound utilizando unbound-control reload, aplicando as novas configurações.

### Notificação de Erros por E-mail:
Se ocorrerem erros durante a execução, o script envia uma notificação por e-mail para um endereço configurado no próprio script. O envio de e-mail pode ser ativado ou desativado através da variável EMAIL_ENABLED.

### Logs Detalhados e Rotação de Logs:
Todos os eventos importantes são registrados em um arquivo de log (/var/log/synAnablock.log). O log é rotacionado automaticamente quando atinge 10MB, criando um arquivo antigo e um novo log para evitar problemas de armazenamento. Quando o modo DEBUG está ativado, o script exibe detalhes adicionais no console, como o conteúdo completo das respostas das APIs.

## Variáveis Configuráveis:

APP: Define o nome da aplicação que será incluída na URL da API. MODE: Define o modo de sincronização (ex: redirect). IPv4: Endereço IPv4 do servidor alvo. IPv6: Endereço IPv6 do servidor alvo (opcional). EMAIL_ENABLED: Ativa ou desativa o envio de notificações de erro por e-mail (true ou false). EMAIL_RECIPIENT: Endereço de e-mail que receberá as notificações de erro. DEBUG: Ativa ou desativa o modo de debug em tempo real (true ou false).

Como Utilizar:

Pré-requisitos:
O script deve ser executado em um ambiente onde os comandos curl, unbound-checkconf, e unbound-control estejam disponíveis. Certifique-se de que o script tenha permissão para escrever no arquivo de configuração (/etc/unbound/block.d/dns-block.conf) e nos logs (/var/log/synAnablock.log).

Execução:
Para executar o script, simplesmente execute o arquivo em um terminal de linha de comando:
./nome_do_script.sh
Se o modo DEBUG estiver ativado, informações detalhadas serão exibidas diretamente no console.

Monitoramento e Logs:
Verifique o arquivo de log (/var/log/synAnablock.log) para informações detalhadas sobre a execução. O log registrará todos os eventos importantes, incluindo a validação de acesso, o download da lista de domínios, a atualização do arquivo de configuração e quaisquer erros encontrados.

Notificação por E-mail:
Se configurado, o script enviará um e-mail para o endereço especificado em caso de erro, detalhando o problema ocorrido.

Exemplo de Configuração:
Aqui está um exemplo de como configurar o script com as variáveis apropriadas:

APP="unbound"
MODE="redirect"
IPv4="127.0.0.1"
IPv6=""
EMAIL_ENABLED=true
EMAIL_RECIPIENT="admin@dominio.com"
DEBUG=true

Neste exemplo, o modo de depuração está ativado (DEBUG=true), o que permitirá que todas as informações sejam exibidas no console, e as notificações de erro por e-mail serão enviadas para admin@dominio.com.

Possíveis Erros e Soluções:

Acesso Negado:
Se a API de ACL retornar "ACCESS-DENIED", o script interromperá a execução. Verifique se o IP do servidor está devidamente autorizado. Entrar em contato: https://anablock.net.br/

Falha no Download:
Se o arquivo de configuração não puder ser baixado ou estiver vazio, o script gerará um log com detalhes e interromperá a execução.

Erro na Configuração do Unbound:
Caso a verificação da configuração do Unbound falhe, será gerado um log com detalhes, e o Unbound não será recarregado até que o problema seja resolvido.

Permissão de Execução:
chmod +x /caminho/completo/para/o/script.sh

Passos para Agendamento com crontab:

Abra o arquivo de configuração do crontab:
No terminal, digite o seguinte comando:
crontab -e

Adicione a seguinte linha ao crontab:
Esta linha agendará a execução do script todos os dias às 3h da manhã:
0 3 * * * /caminho/completo/para/o/script.sh >> /var/log/synAnablock_cron.log 2>&1

Explicação:

0 3 * * *: Define a hora e a frequência da execução:
0: Minuto (no caso, minuto "0", ou seja, no início da hora).
3: Hora (executará às 3h da manhã).
*: Todos os dias do mês.
*: Todos os meses.
*: Todos os dias da semana.
/caminho/completo/para/o/script.sh: Substitua pelo caminho absoluto do seu script. Por exemplo: /home/user/scripts/syncronizacao.sh.

/var/log/synAnablock_cron.log 2>&1: Este comando redireciona a saída (logs) do script para o arquivo /var/log/synAnablock_cron.log, registrando tanto a saída padrão quanto erros. Isso ajuda no monitoramento e solução de problemas.

Exemplo Completo:

Se o seu script estiver localizado em /etc/unbound/scripts/syncronizacao.sh, a entrada no crontab seria:

0 3 * * * /etc/unbound/scripts/syncronizacao.sh >> /var/log/synAnablock_cron.log 2>&1

Monitoramento:

Você pode verificar o arquivo /var/log/synAnablock_cron.log para conferir os logs de execução automática do script via cron.

# -----------------------------------------------
#                   BasicDNS
#               www.basicdns.com.br
# -----------------------------------------------
#!/bin/bash

CFG="/etc/unbound/local.d/dns-block.conf"
URL="https://api.anablock.net.br/api/domains/all?"
ACL_URL="https://anablock.net.br/acl.php"  # URL de validação de acesso
APP="unbound"
MODE="redirect"
IPv4="127.0.0.1"
IPv6=""
LOGFILE="/var/log/synAnablock.log"
ERROR=0

# Variáveis configuráveis
EMAIL_ENABLED=false                     # Ativar envio de e-mail (true/false)
EMAIL_RECIPIENT="admin@dominio.com"     # Endereço de e-mail para notificação de erro
DEBUG=false                             # Ativar modo debug (true/false)

# -----------------------------------------------
# Função para registrar logs
# -----------------------------------------------
log_message() {
    local MESSAGE="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $MESSAGE" >> $LOGFILE
    if [ "$DEBUG" = true ]; then
        echo "$MESSAGE"
    fi
}

# -----------------------------------------------
# Verificar se o comando existe
# -----------------------------------------------
check_command() {
    local CMD="$1"
    if ! command -v $CMD &> /dev/null; then
        log_message "Comando $CMD não encontrado"
        echo "Erro: Comando $CMD não encontrado"
        exit 1
    fi
}

# Verificar comandos necessários
check_command "curl"
check_command "unbound-checkconf"
check_command "unbound-control"

# -----------------------------------------------
# Verificar se o diretório e arquivo CFG existem
# -----------------------------------------------
if [ ! -d "$(dirname "$CFG")" ]; then
    mkdir -p "$(dirname "$CFG")"
    log_message "Diretório $(dirname "$CFG") criado"
fi

if [ ! -f "$CFG" ]; then
    touch "$CFG"
    log_message "Arquivo $CFG criado"
fi

# -----------------------------------------------
# Rotação de logs se o arquivo for maior que 10MB
# -----------------------------------------------
if [ $(du -k "$LOGFILE" | cut -f1) -ge 10240 ]; then
    mv $LOGFILE "$LOGFILE.old"
    touch $LOGFILE
    log_message "Arquivo de log rotacionado"
fi

# -----------------------------------------------
# Validar Acesso
# -----------------------------------------------
validate_access() {
    ACCESS_RESPONSE=$(curl -s $ACL_URL)
    CHECK_RETURN=$(echo "$ACCESS_RESPONSE" | grep -oP '(?<=Check return: )[^<]+')

    if [ "$CHECK_RETURN" = "ACCESS-DENIED" ]; then
        log_message "Acesso negado: $CHECK_RETURN. Execução interrompida."
        #log_message "Resposta completa da validação de acesso: $ACCESS_RESPONSE"
        exit 1
    else
        log_message "Acesso permitido"
    fi

    if [ "$DEBUG" = true ]; then
        log_message "Resposta da validação de acesso:"
        echo "$ACCESS_RESPONSE"
    fi
}

# -----------------------------------------------
# Construir URL
# -----------------------------------------------
if [ -n "$APP" ]; then
    URL="$URL&output=$APP"
fi

if [ -n "$MODE" ]; then
    URL="$URL&mode=$MODE"
fi

if [ -n "$IPv4" ]; then
    URL="$URL&ipv4_target=$IPv4"
fi

if [ -n "$IPv6" ]; then
    URL="$URL&ipv6_target=$IPv6"
fi

# -----------------------------------------------
# Baixar o arquivo e verificar se o download foi bem-sucedido
# -----------------------------------------------
download_file() {
    curl -m 30 -s $URL -o temp_file
    if [ $? -ne 0 ]; then
        log_message "Erro ao baixar o arquivo de $URL. Timeout ou problema de rede."
        echo "Erro: Falha ao baixar o arquivo."
        exit 1
    elif [ ! -s temp_file ]; then
        log_message "Falha ao baixar conteúdo válido de $URL"
        rm -f temp_file
        exit 1
    else
        log_message "Arquivo baixado com sucesso de $URL"
        mv temp_file $CFG
        chown unbound:unbound $CFG
        log_message "Arquivo $CFG atualizado com sucesso"

        # Mostrar conteúdo JSON no modo debug
        if [ "$DEBUG" = true ]; then
            log_message "Conteúdo baixado (JSON):"
            cat $CFG
        fi
    fi
}

# Fazer backup do arquivo antes de remover
if [ -f "$CFG" ]; then
    cp $CFG "$CFG.bak"
    log_message "Backup do arquivo de configuração criado: $CFG.bak"
fi

# Validar o acesso antes de baixar o arquivo
validate_access

# Executar o download
download_file

# -----------------------------------------------
# Verificar configuração do Unbound
# -----------------------------------------------
unbound-checkconf > /dev/null 2>&1
if [ $? -eq 0 ]; then
    log_message "Configuração do Unbound está correta"
else
    log_message "Erro na configuração do Unbound"
    unbound-checkconf >> $LOGFILE
    ERROR=1
fi

# -----------------------------------------------
# Recarregar Unbound se não houver erros
# -----------------------------------------------
if [ $ERROR -eq 0 ]; then
    unbound-control reload > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        log_message "Unbound recarregado com sucesso"
        echo "Sucesso..."
    else
        log_message "Erro ao recarregar o Unbound"
        echo "Erro ao recarregar o Unbound"
        ERROR=1
    fi
fi

# -----------------------------------------------
# Enviar notificação de erro por e-mail se ativado
# -----------------------------------------------
if [ $ERROR -ne 0 ] && [ "$EMAIL_ENABLED" = true ]; then
    echo "Erro no script de sincronização" | mail -s "Erro no Script Unbound" $EMAIL_RECIPIENT
    log_message "Notificação de erro enviada para $EMAIL_RECIPIENT"
fi

log_message "Script executado com sucesso"
exit $ERROR

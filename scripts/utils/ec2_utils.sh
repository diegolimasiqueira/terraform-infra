#!/bin/bash

# Função para escapar caracteres especiais no comando
escape_command() {
    local cmd="$1"
    # Escapar aspas duplas e preservar a estrutura do script
    echo "$cmd" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g'
}

# Função para executar comandos em uma instância EC2
execute_on_instance() {
    local instance_id=$1
    local command=$2
    local instance_name=$(aws ec2 describe-instances \
        --instance-ids "$instance_id" \
        --query "Reservations[].Instances[].Tags[?Key=='Name'].Value" \
        --output text)

    echo "Executando comando na instância $instance_name ($instance_id)..." >&2

    # Criar array de comandos
    local commands=(
        "#!/bin/bash"
        "set -e"
    )

    # Adicionar cada linha do comando ao array
    while IFS= read -r line; do
        if [ ! -z "$line" ]; then
            commands+=("$line")
        fi
    done <<<"$command"

    # Converter array para JSON usando jq
    local param_json
    param_json=$(printf '%s\n' "${commands[@]}" | jq -R . | jq -s '{ "commands": . }')

    # Executar o comando diretamente na instância
    local command_id
    command_id=$(aws ssm send-command \
        --instance-ids "$instance_id" \
        --document-name "AWS-RunShellScript" \
        --parameters "$param_json" \
        --query "Command.CommandId" \
        --output text)

    if [ -z "$command_id" ]; then
        echo "Erro: Falha ao enviar comando para a instância $instance_name ($instance_id)" >&2
        return 1
    fi

    echo "Comando enviado com ID: $command_id" >&2
    echo "$command_id"
}

# Função para aguardar a conclusão de um comando SSM
wait_for_command() {
    local command_id=$1
    local instance_id=$2
    local ignore_exit=$3 # Parâmetro para ignorar exit status

    # Verificar se o command_id é um UUID válido
    if ! [[ $command_id =~ ^[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}$ ]]; then
        echo "Erro: ID de comando inválido: $command_id"
        return 1
    fi

    if [ -z "$instance_id" ]; then
        echo "Erro: instance_id não fornecido"
        return 1
    fi

    local instance_name=$(aws ec2 describe-instances \
        --instance-ids "$instance_id" \
        --query "Reservations[].Instances[].Tags[?Key=='Name'].Value" \
        --output text)

    echo "Aguardando conclusão do comando $command_id na instância $instance_name..."

    # Adicionar timeout
    local timeout=600 # 10 minutos
    local start_time=$(date +%s)

    while true; do
        local current_time=$(date +%s)
        local elapsed_time=$((current_time - start_time))

        if [ $elapsed_time -gt $timeout ]; then
            echo "Timeout: Comando excedeu o tempo limite de $timeout segundos"
            return 1
        fi

        # Tentar obter o status do comando
        local status_output=$(aws ssm get-command-invocation \
            --command-id "$command_id" \
            --instance-id "$instance_id" \
            --query "Status" \
            --output text 2>&1)

        local status=$?

        if [ $status -ne 0 ]; then
            echo "Erro ao obter status do comando: $status_output"
            echo "Tentando novamente em 5 segundos..."
            sleep 5
            continue
        fi

        if [ -z "$status_output" ]; then
            echo "Status vazio. Tentando novamente em 5 segundos..."
            sleep 5
            continue
        fi

        echo "Status atual: $status_output"

        case "$status_output" in
        "Success")
            echo "✅ Comando executado com sucesso"
            # Mostrar saída do comando
            aws ssm get-command-invocation \
                --command-id "$command_id" \
                --instance-id "$instance_id" \
                --query "StandardOutputContent" \
                --output text
            return 0
            ;;
        "Failed")
            echo "❌ Comando falhou na instância $instance_name ($instance_id)"
            # Mostrar erro do comando e saída padrão para diagnóstico
            echo "ERRO:"
            aws ssm get-command-invocation \
                --command-id "$command_id" \
                --instance-id "$instance_id" \
                --query "StandardErrorContent" \
                --output text
            echo "SAÍDA:"
            aws ssm get-command-invocation \
                --command-id "$command_id" \
                --instance-id "$instance_id" \
                --query "StandardOutputContent" \
                --output text
            # Se ignore_exit for true, retorna 0 mesmo em caso de falha
            [ "$ignore_exit" = "true" ] && return 0 || return 1
            ;;
        "TimedOut")
            echo "⏱️ Comando excedeu o tempo limite na instância $instance_name ($instance_id)"
            return 1
            ;;
        "Cancelled")
            echo "🛑 Comando foi cancelado na instância $instance_name ($instance_id)"
            return 1
            ;;
        *)
            echo "Status desconhecido: $status_output"
            sleep 5
            ;;
        esac
    done
}

# Função para configurar Keycloak
configure_keycloak() {
    local keycloak_id=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=keycloak" \
        --query "Reservations[].Instances[].InstanceId" \
        --output text)

    # Verificar se o Keycloak já está instalado
    echo "Verificando se o Keycloak já está instalado..."
    local keycloak_check_cmd='set -e
                                echo "Verificando diretório do Keycloak..."
                                ls -la /home/ubuntu/keycloak-22.0.5/bin/kc.sh 2>/dev/null || echo "kc.sh não encontrado"
                                echo "Verificando processo do Keycloak..."
                                if lsof -i :8443 >/dev/null 2>&1 || ss -tuln | grep -q ":8443" || ps aux | grep -v grep | grep -E "keycloak|kc.sh" > /dev/null; then
                                    echo "[KEYCLOAK_STATUS] INSTALLED_RUNNING"
                                elif [ -f "/home/ubuntu/keycloak-22.0.5/bin/kc.sh" ]; then
                                    echo "[KEYCLOAK_STATUS] INSTALLED_NOT_RUNNING"
                                else
                                    echo "[KEYCLOAK_STATUS] NOT_INSTALLED"
                                fi
                                exit 0'
    local command_id=$(execute_on_instance "$keycloak_id" "$keycloak_check_cmd")
    wait_for_command "$command_id" "$keycloak_id"

    local keycloak_status=$(aws ssm get-command-invocation \
        --command-id "$command_id" \
        --instance-id "$keycloak_id" \
        --query "StandardOutputContent" \
        --output text)

    if [[ $keycloak_status == *"INSTALLED_RUNNING"* ]]; then
        echo "Keycloak já está configurado e funcionando. Pulando instalação..."
        return 0
    elif [[ $keycloak_status == *"INSTALLED_NOT_RUNNING"* ]]; then
        echo "Keycloak está instalado mas não está rodando. Iniciando serviço..."
        local keycloak_start_cmd='cd /home/ubuntu/keycloak-22.0.5/bin && sudo nohup ./kc.sh start-dev --https-port=8443 --http-relative-path=/auth --hostname-strict=false --hostname=0.0.0.0 --http-enabled=false > /tmp/keycloak.log 2>&1 &
                                    sleep 15  # Dar mais tempo para o Keycloak iniciar
                                    if ps aux | grep -v grep | grep -E "keycloak|kc.sh" > /dev/null; then
                                        echo "Keycloak iniciado com sucesso"
                                    else
                                        echo "Erro ao iniciar Keycloak. Verifique /tmp/keycloak.log"
                                        exit 1
                                    fi'
        local command_id=$(execute_on_instance "$keycloak_id" "$keycloak_start_cmd")
        wait_for_command "$command_id" "$keycloak_id"
        return $?
    else
        echo "Instalando Keycloak..."
        local keycloak_cmd='set -e
                            export DEBIAN_FRONTEND=noninteractive
                            echo "Atualizando pacotes..."
                            sudo apt-get update
                            echo "Instalando OpenJDK 17..."
                            echo "openjdk-17-jdk openjdk-17-jdk/start-on-boot boolean true" | sudo debconf-set-selections
                            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" openjdk-17-jdk
                            echo "Baixando Keycloak..."
                            wget -q https://github.com/keycloak/keycloak/releases/download/22.0.5/keycloak-22.0.5.tar.gz
                            echo "Extraindo Keycloak..."
                            mkdir -p /home/ubuntu/keycloak-22.0.5
                            tar xzf keycloak-22.0.5.tar.gz --strip-components=1 -C /home/ubuntu/keycloak-22.0.5
                            echo "Configurando Keycloak..."
                            cd /home/ubuntu/keycloak-22.0.5/bin
                            sudo chmod +x kc.sh
                            echo "Iniciando Keycloak..."
                            nohup ./kc.sh start-dev --https-port=8443 --http-relative-path=/auth > /tmp/keycloak.log 2>&1 &
                            echo "Verificando se o Keycloak iniciou..."
                            sleep 15
                            if ps aux | grep -v grep | grep -E "keycloak|kc.sh" > /dev/null; then
                                echo "Keycloak iniciado com sucesso"
                                exit 0
                            else
                                echo "Erro ao iniciar Keycloak. Verifique /tmp/keycloak.log"
                                exit 1
                            fi'
        local command_id=$(execute_on_instance "$keycloak_id" "$keycloak_cmd")
        wait_for_command "$command_id" "$keycloak_id"
        return $?
    fi
}

# Função para configurar Redis
configure_redis() {
    local redis_id=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=redis" \
        --query "Reservations[].Instances[].InstanceId" \
        --output text)

    # Verificar se o Redis já está instalado
    echo "Verificando se o Redis já está instalado..."
    local redis_check_cmd='set -e
                           if systemctl is-active --quiet redis-server && redis-cli ping | grep -q "PONG"; then 
                             echo "Redis já está instalado e rodando"
                             exit 0
                           elif dpkg -l | grep -q redis-server; then 
                             echo "Redis está instalado mas não está rodando"
                             exit 1
                           else 
                             echo "Redis não está instalado"
                             exit 2
                           fi'
    local command_id=$(execute_on_instance "$redis_id" "$redis_check_cmd")
    wait_for_command "$command_id" "$redis_id" "true"

    local redis_status=$(aws ssm get-command-invocation \
        --command-id "$command_id" \
        --instance-id "$redis_id" \
        --query "StandardOutputContent" \
        --output text)

    if [[ $redis_status == *"Redis já está instalado e rodando"* ]]; then
        echo "Redis já está configurado e funcionando. Pulando instalação..."
        return 0
    elif [[ $redis_status == *"Redis está instalado mas não está rodando"* ]]; then
        echo "Redis está instalado mas não está rodando. Iniciando serviço..."
        local redis_start_cmd='sudo systemctl start redis-server && sudo systemctl enable redis-server'
        local command_id=$(execute_on_instance "$redis_id" "$redis_start_cmd")
        wait_for_command "$command_id" "$redis_id"
        return $?
    else
        echo "Instalando Redis..."
        local redis_cmd='export DEBIAN_FRONTEND=noninteractive && \
            sudo apt-get update && \
            echo "redis-server redis-server/start_on_boot boolean true" | sudo debconf-set-selections && \
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" redis-server && \
            sudo sed -i "s/bind 127.0.0.1/bind 0.0.0.0/" /etc/redis/redis.conf && \
            sudo systemctl restart redis-server && \
            sudo systemctl enable redis-server && \
            sleep 5 && \
            redis-cli ping'
        local command_id=$(execute_on_instance "$redis_id" "$redis_cmd")
        wait_for_command "$command_id" "$redis_id"
        return $?
    fi
}

# Função para configurar MongoDB
configure_mongodb() {
    local mongodb_id=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=mongodb" \
        --query "Reservations[].Instances[].InstanceId" \
        --output text)

    # Verificar se o MongoDB já está instalado
    echo "Verificando se o MongoDB já está instalado..."
    local mongodb_check_cmd='set -e
                             if systemctl is-active --quiet mongod; then 
                               echo "MongoDB já está instalado e rodando"
                               exit 0
                             elif dpkg -l | grep -q mongodb-org; then 
                               echo "MongoDB está instalado mas não está rodando"
                               exit 1
                             else 
                               echo "MongoDB não está instalado"
                               exit 2
                             fi'
    local command_id=$(execute_on_instance "$mongodb_id" "$mongodb_check_cmd")
    wait_for_command "$command_id" "$mongodb_id" "true"

    # Obter o status do comando anterior
    local mongodb_status=$(aws ssm get-command-invocation \
        --command-id "$command_id" \
        --instance-id "$mongodb_id" \
        --query "StandardOutputContent" \
        --output text)

    if [[ $mongodb_status == *"MongoDB já está instalado e rodando"* ]]; then
        echo "MongoDB já está configurado e funcionando. Pulando instalação..."
        return 0
    elif [[ $mongodb_status == *"MongoDB está instalado mas não está rodando"* ]]; then
        echo "MongoDB está instalado mas não está rodando. Iniciando serviço..."
        local mongodb_start_cmd='sudo systemctl start mongod && sudo systemctl enable mongod'
        local command_id=$(execute_on_instance "$mongodb_id" "$mongodb_start_cmd")
        wait_for_command "$command_id" "$mongodb_id"
        return $?
    else
        echo "Instalando MongoDB..."
        # Instalação do MongoDB (resumida para brevidade)
        local mongodb_cmd='export DEBIAN_FRONTEND=noninteractive && \
            sudo apt-get update && \
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" gnupg curl && \
            curl -fsSL https://pgp.mongodb.com/server-7.0.asc | sudo gpg --batch --yes -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor && \
            echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list && \
            sudo apt-get update && \
            echo "mongodb-org mongodb-org/7.0 boolean true" | sudo debconf-set-selections && \
            echo "mongodb-org/7.0 mongodb-org/7.0 boolean true" | sudo debconf-set-selections && \
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" mongodb-org && \
            sudo systemctl start mongod && \
            sudo systemctl enable mongod'
        local command_id=$(execute_on_instance "$mongodb_id" "$mongodb_cmd")
        wait_for_command "$command_id" "$mongodb_id"
        return $?
    fi
}

# Função para configurar PostgreSQL
configure_postgres() {
    local postgres_id=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=postgres" \
        --query "Reservations[].Instances[].InstanceId" \
        --output text)

    # Verificar se o PostgreSQL já está instalado
    echo "Verificando se o PostgreSQL já está instalado..."
    local postgres_check_cmd='set -e
                              if systemctl is-active --quiet postgresql; then 
                                echo "PostgreSQL já está instalado e rodando"
                                exit 0
                              elif dpkg -l | grep -q postgresql; then 
                                echo "PostgreSQL está instalado mas não está rodando"
                                exit 1
                              else 
                                echo "PostgreSQL não está instalado"
                                exit 2
                              fi'
    local command_id=$(execute_on_instance "$postgres_id" "$postgres_check_cmd")
    wait_for_command "$command_id" "$postgres_id" "true"

    # Obter o status do comando anterior, mesmo se falhou
    local postgres_status=$(aws ssm get-command-invocation \
        --command-id "$command_id" \
        --instance-id "$postgres_id" \
        --query "StandardOutputContent" \
        --output text 2>/dev/null || echo "PostgreSQL não está instalado")

    if [[ $postgres_status == *"PostgreSQL já está instalado e rodando"* ]]; then
        echo "PostgreSQL já está configurado e funcionando. Pulando instalação..."
        return 0
    elif [[ $postgres_status == *"PostgreSQL está instalado mas não está rodando"* ]]; then
        echo "PostgreSQL está instalado mas não está rodando. Iniciando serviço..."
        local postgres_start_cmd='sudo systemctl start postgresql && sudo systemctl enable postgresql'
        local command_id=$(execute_on_instance "$postgres_id" "$postgres_start_cmd")
        wait_for_command "$command_id" "$postgres_id"
        return $?
    else
        echo "Instalando PostgreSQL..."
        local postgres_cmd='set -e
            export DEBIAN_FRONTEND=noninteractive
            echo "Atualizando pacotes..."
            sudo apt-get update
            
            echo "Configurando respostas automáticas para PostgreSQL..."
            echo "postgresql-common postgresql-common/createcluster boolean true" | sudo debconf-set-selections
            echo "postgresql-common postgresql-common/ssl boolean true" | sudo debconf-set-selections
            echo "postgresql-14 postgresql-14/start-on-boot boolean true" | sudo debconf-set-selections
            
            echo "Instalando PostgreSQL..."
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" postgresql postgresql-contrib
            
            echo "Configurando PostgreSQL para aceitar conexões remotas..."
            sudo sed -i "s/#listen_addresses = '\''localhost'\''/listen_addresses = '\''*'\''/" /etc/postgresql/14/main/postgresql.conf
            echo "host    all             all             0.0.0.0/0               md5" | sudo tee -a /etc/postgresql/14/main/pg_hba.conf
            
            echo "Reiniciando PostgreSQL..."
            sudo systemctl restart postgresql
            sudo systemctl enable postgresql
            
            echo "Verificando status do PostgreSQL..."
            sudo systemctl status postgresql --no-pager || true
            echo "PostgreSQL instalado e configurado com sucesso"'
        local command_id=$(execute_on_instance "$postgres_id" "$postgres_cmd")
        wait_for_command "$command_id" "$postgres_id"
        return $?
    fi
}

# Função para configurar Monitoring
# Função para configurar Nominatim
configure_nominatim() {
    local nominatim_id=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=nominatim" \
        --query "Reservations[].Instances[].InstanceId" \
        --output text)

    echo "Pulando configuração do Nominatim por enquanto..."
    echo "Nominatim será configurado manualmente ou em uma etapa posterior."
    return 0
}

configure_monitoring() {
    local monitoring_id=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=monitoring" \
        --query "Reservations[].Instances[].InstanceId" \
        --output text)

    # Verificar se o Monitoring já está instalado
    echo "Verificando se o Monitoring já está instalado..."
    local monitoring_check_cmd='set -e
                                grafana_installed=false
                                prometheus_installed=false
                                
                                # Verificar Grafana
                                if dpkg -l | grep -q grafana; then
                                  if systemctl is-active --quiet grafana-server 2>/dev/null; then
                                    echo "Grafana está instalado e rodando"
                                    grafana_installed=true
                                  else
                                    echo "Grafana está instalado mas não está rodando"
                                    sudo systemctl start grafana-server || true
                                    sudo systemctl enable grafana-server || true
                                    if systemctl is-active --quiet grafana-server 2>/dev/null; then
                                      echo "Grafana iniciado com sucesso"
                                      grafana_installed=true
                                    fi
                                  fi
                                else
                                  echo "Grafana não está instalado"
                                fi
                                
                                # Verificar Prometheus
                                if dpkg -l | grep -q prometheus; then
                                  if systemctl is-active --quiet prometheus 2>/dev/null; then
                                    echo "Prometheus está instalado e rodando"
                                    prometheus_installed=true
                                  else
                                    echo "Prometheus está instalado mas não está rodando"
                                    sudo systemctl start prometheus || true
                                    sudo systemctl enable prometheus || true
                                    if systemctl is-active --quiet prometheus 2>/dev/null; then
                                      echo "Prometheus iniciado com sucesso"
                                      prometheus_installed=true
                                    fi
                                  fi
                                else
                                  echo "Prometheus não está instalado"
                                fi
                                
                                # Verificar status geral
                                if $grafana_installed && $prometheus_installed; then
                                  echo "Monitoring completo está instalado e rodando"
                                  exit 0
                                elif $grafana_installed || $prometheus_installed; then
                                  echo "Monitoring está parcialmente instalado"
                                  exit 1
                                else
                                  echo "Monitoring não está instalado"
                                  exit 2
                                fi'
    local command_id=$(execute_on_instance "$monitoring_id" "$monitoring_check_cmd")
    wait_for_command "$command_id" "$monitoring_id" "true"

    local monitoring_status=$(aws ssm get-command-invocation \
        --command-id "$command_id" \
        --instance-id "$monitoring_id" \
        --query "StandardOutputContent" \
        --output text 2>/dev/null || echo "Grafana não está instalado")

    if [[ $monitoring_status == *"Monitoring completo está instalado e rodando"* ]]; then
        echo "Monitoring completo já está configurado e funcionando. Pulando instalação..."
        return 0
    elif [[ $monitoring_status == *"Monitoring está parcialmente instalado"* ]]; then
        echo "Monitoring está parcialmente instalado. Completando instalação..."
        # Iniciar serviços existentes e instalar os que faltam
        local monitoring_fix_cmd='set -e
export DEBIAN_FRONTEND=noninteractive

# Iniciar Grafana se instalado
if dpkg -l | grep -q grafana; then
    echo "Iniciando Grafana..."
    sudo systemctl start grafana-server
    sudo systemctl enable grafana-server
fi

# Instalar/iniciar Prometheus se necessário
if ! dpkg -l | grep -q prometheus; then
    echo "Instalando Prometheus..."
    sudo apt-get update
    
    # Pré-configurar todas as possíveis perguntas
    sudo debconf-set-selections <<EOF
prometheus prometheus/restart-services boolean true
prometheus prometheus/restart-without-asking boolean true
prometheus-node-exporter prometheus-node-exporter/restart-services boolean true
prometheus-node-exporter prometheus-node-exporter/restart-without-asking boolean true
smartmontools smartmontools/start_smartd boolean true
EOF
    
    # Instalar com opções não interativas
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" prometheus
fi

sudo systemctl start prometheus
sudo systemctl enable prometheus

echo "Monitoring completo configurado e iniciado"'
        local command_id=$(execute_on_instance "$monitoring_id" "$monitoring_fix_cmd")
        wait_for_command "$command_id" "$monitoring_id"
        return $?
    else
        echo "Instalando Monitoring..."
        # Script para instalação do Grafana (Prometheus será instalado separadamente)
        local monitoring_cmd='set -e
export DEBIAN_FRONTEND=noninteractive
echo "Instalando Grafana..."
sudo apt-get update
sudo apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" apt-transport-https software-properties-common wget curl gnupg

# Instalar Grafana
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add --batch --yes -
echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
sudo apt-get update
echo "grafana-server grafana-server/start-on-boot boolean true" | sudo debconf-set-selections
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" grafana
sudo systemctl start grafana-server
sudo systemctl enable grafana-server

echo "Grafana instalado com sucesso"'
        local command_id=$(execute_on_instance "$monitoring_id" "$monitoring_cmd")
        wait_for_command "$command_id" "$monitoring_id"
        return $?
    fi
}

# Função para configurar API Gateway
configure_api_gateway() {
    # Verificar se o certificado já existe
    echo "Verificando certificado SSL/TLS..."
    local acm_certificate_arn=$(aws acm list-certificates \
        --query "CertificateSummaryList[?DomainName=='api.easyprofind.com'].CertificateArn" \
        --output text)

    if [ -z "$acm_certificate_arn" ]; then
        echo "⚠️ Certificado não encontrado. Criando novo certificado..."
        acm_certificate_arn=$(aws acm request-certificate \
            --domain-name api.easyprofind.com \
            --validation-method DNS \
            --query "CertificateArn" \
            --output text)

        echo "⚠️ Aguardando validação do certificado..."
        echo "Por favor, valide o certificado no console da AWS antes de continuar."
        echo "ARN do certificado: $acm_certificate_arn"
        echo "Continuando com outras configurações..."
    else
        echo "✅ Certificado encontrado: $acm_certificate_arn"
    fi

    # Configurar CORS no API Gateway
    echo "Configurando CORS no API Gateway..."
    local api_id=$(aws apigateway get-rest-apis --query "items[?name=='easyprofind-api'].id" --output text)

    if [ -z "$api_id" ]; then
        echo "⚠️ API Gateway não encontrado. Será criado pelo Terraform."
        return 0
    fi

    # Configurar CORS
    echo "Configurando CORS..."
    local resource_id=$(aws apigateway get-resources --rest-api-id "$api_id" --query "items[?path=='/'].id" --output text)

    # Verificar se o método OPTIONS já existe
    echo "Verificando se o método OPTIONS já existe..."
    local options_exists=$(aws apigateway get-method \
        --rest-api-id "$api_id" \
        --resource-id "$resource_id" \
        --http-method OPTIONS 2>/dev/null || echo "NOT_FOUND")

    if [[ $options_exists == "NOT_FOUND" ]]; then
        echo "Criando método OPTIONS para CORS..."
        aws apigateway put-method \
            --rest-api-id "$api_id" \
            --resource-id "$resource_id" \
            --http-method OPTIONS \
            --authorization-type "NONE"

        # Configurar integração MOCK
        echo "Configurando integração MOCK..."
        aws apigateway put-integration \
            --rest-api-id "$api_id" \
            --resource-id "$resource_id" \
            --http-method OPTIONS \
            --type MOCK \
            --request-templates '{"application/json": "{\"statusCode\": 200}"}'

        # Configurar resposta do método
        echo "Configurando resposta do método..."
        aws apigateway put-method-response \
            --rest-api-id "$api_id" \
            --resource-id "$resource_id" \
            --http-method OPTIONS \
            --status-code 200 \
            --response-parameters '{"method.response.header.Access-Control-Allow-Headers": true, "method.response.header.Access-Control-Allow-Methods": true, "method.response.header.Access-Control-Allow-Origin": true}' \
            --response-models '{"application/json": "Empty"}'

        # Configurar resposta da integração
        echo "Configurando resposta da integração..."
        aws apigateway put-integration-response \
            --rest-api-id "$api_id" \
            --resource-id "$resource_id" \
            --http-method OPTIONS \
            --status-code 200 \
            --response-parameters '{
                "method.response.header.Access-Control-Allow-Headers": "'\''*'\''",
                "method.response.header.Access-Control-Allow-Methods": "'\''GET,POST,PUT,DELETE,OPTIONS'\''",
                "method.response.header.Access-Control-Allow-Origin": "'\''*'\''"
            }'
    else
        echo "Método OPTIONS já existe. Pulando criação..."
    fi

    return 0
}
# Scripts de Configuração da Infraestrutura

Este diretório contém scripts para configurar a infraestrutura do EasyProFind.

## Fluxo de Execução

1. `check_ssm_availability.sh` - Verifica se as instâncias EC2 estão prontas para receber comandos via SSM
2. `configure_infra.sh` - Script principal que configura todos os serviços básicos
3. `install_prometheus.sh` - Script opcional para instalar o Prometheus após a configuração básica

## Instruções de Uso

Para configurar a infraestrutura básica:

```bash
./configure_infra.sh
```

Para instalar o Prometheus após a configuração básica:

```bash
./install_prometheus.sh
```

## Resolução de Problemas

Se a instalação do Monitoring falhar, tente executar apenas o Grafana primeiro com `configure_infra.sh` e depois instale o Prometheus separadamente com `install_prometheus.sh`.

Isso evita problemas de timeout durante o download de arquivos grandes.
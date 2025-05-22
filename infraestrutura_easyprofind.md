# Infraestrutura Provisionada - EasyProFind

Este documento descreve toda a infraestrutura provisionada automaticamente via Terraform para o projeto **EasyProFind**, incluindo a ordem de criação, recursos utilizados e arquitetura de comunicação.

---

## 📦 Infraestrutura Completa

### 🛠️ 1. VPC (rede principal)

- **Nome**: `easyprofind-vpc`
- **CIDR**: `10.0.0.0/16`
- **Subnets**:
  - Públicas: `10.0.101.0/24`, `10.0.102.0/24`
  - Privadas: `10.0.1.0/24`, `10.0.2.0/24`
- **Recursos**:
  - Internet Gateway
  - NAT Gateway (1 unidade)
  - Route Tables + associações automáticas

---

### 🧠 2. EKS (Kubernetes gerenciado)

- **Nome**: `easyprofind-eks`
- **Versão**: 1.32
- **NodeGroup**:
  - Tipo: `t3.small`
  - Capacidade inicial: 1 nó
- **Subnets**: privadas (isoladas)
- **Segurança**: IAM roles e Security Groups dedicados

---

### 🌐 3. Ingress Controller (ALB)

- Instalado via **Helm** no EKS
- Cria um **Application Load Balancer (ALB)** para os serviços
- **Ingress configurado para rotas**:
  - `/bff`
  - `/ms-geo`
  - `/ms-consumers`
  - `/ms-professionals`
  - `/ms-rates`

---

### 🚀 4. API Gateway

- **Nome**: `easyprofind-api`
- **Domínio**: `https://api.easyprofind.com`
- **SSL**: certificado ACM integrado
- **Rotas configuradas**:
  - `/monitoring`
  - `/redis`
  - `/nominatim`
  - `/bff`, etc.
- **Integração**:
  - IPs públicos de EC2s
  - DNS do ALB (Ingress Controller)

---

### 🖥️ 5. Instâncias EC2 auxiliares

| Nome         | Tipo       | Disco | Elastic IP | Finalidade                         |
|--------------|------------|-------|------------|-------------------------------------|
| `keycloak`   | t3.micro   | 8 GB  | ✅          | Autenticação                        |
| `nominatim`  | t3.small   | 55 GB | ✅          | Geocodificação reversa              |
| `monitoring` | t3.micro   | 8 GB  | ✅          | Grafana, Prometheus, Loki           |
| `redis`      | t3.micro   | 4 GB  | ❌          | Cache interno                       |
| `postgres`   | t3.micro   | 8 GB  | ❌          | Banco de dados dos microserviços    |
| `mongodb`    | t3.micro   | 8 GB  | ❌          | Comentários, avaliações, etc.       |

---

### 💬 6. SQS (fila para comunicação assíncrona)

- **Nome da fila**: `geo-queue`
- **Permissões**:
  - `ms_bff` publica e consome
  - `ms_geo` publica e consome

---

## 🔁 Ordem de Provisionamento (Terraform)

1. VPC e rede (subnets, NAT, IGW)
2. EC2s auxiliares (com EIP para 3 instâncias)
3. EKS com Node Group
4. Instalação do ALB Ingress Controller (via Helm)
5. Ingress para os microserviços no EKS
6. Criação do API Gateway com SSL e rotas
7. Fila SQS com permissões para `bff` e `geo`

---

- **Autor**: Diego Lima Siqueira
- **Data**: Maio 2025
- **Ambiente**: Desenvolvimento (AWS - `us-east-1`)

---

## Diagrama Front-End

![Texto alternativo](/images/arch-fron-end.jpg)

## Diagrama Back-End

![Texto alternativo](/images/arch-back-end.jpg)
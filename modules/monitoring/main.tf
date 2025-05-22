variable "vpc_id" {
  type        = string
  description = "ID da VPC onde os recursos de monitoramento serão criados"
}

variable "subnet_ids" {
  type        = list(string)
  description = "IDs das subnets onde os recursos de monitoramento serão criados"
}

# Security Group para Prometheus e Grafana
resource "aws_security_group" "monitoring" {
  name        = "monitoring-sg"
  description = "Security Group para Prometheus e Grafana"
  vpc_id      = var.vpc_id

  # Grafana Web UI
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Grafana Web UI - Apenas VPC interna"
  }

  # Prometheus Web UI
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Prometheus Web UI - Apenas VPC interna"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# CloudWatch Alarm para CPU alta
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "high-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Alarme para alta utilização de CPU"
  
  dimensions = {
    InstanceId = "i-placeholder"
  }
}

# Outputs
output "monitoring_sg_id" {
  description = "ID do Security Group de monitoramento"
  value       = aws_security_group.monitoring.id
}
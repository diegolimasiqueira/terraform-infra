variable "queue_name" {
  type        = string
  description = "Nome da fila SQS"
  default     = "geo-queue"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags a serem aplicadas aos recursos"
}

# Fila SQS para comunicação assíncrona
resource "aws_sqs_queue" "geo_queue" {
  name                      = var.queue_name
  delay_seconds             = 0
  max_message_size          = 262144  # 256 KB
  message_retention_seconds = 86400   # 1 dia
  receive_wait_time_seconds = 10
  
  tags = var.tags
}

# Política para permitir que ms_bff e ms_geo publiquem e consumam
resource "aws_sqs_queue_policy" "geo_queue_policy" {
  queue_url = aws_sqs_queue.geo_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.geo_queue.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn": [
              "arn:aws:eks:*:*:cluster/*/ms-bff",
              "arn:aws:eks:*:*:cluster/*/ms-geo"
            ]
          }
        }
      }
    ]
  })
}

# Outputs
output "queue_url" {
  description = "URL da fila SQS"
  value       = aws_sqs_queue.geo_queue.id
}

output "queue_arn" {
  description = "ARN da fila SQS"
  value       = aws_sqs_queue.geo_queue.arn
}
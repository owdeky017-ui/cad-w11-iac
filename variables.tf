# Region: 和你 AWS Academy Lab 控制台右上角显示的一致
variable "aws_region" {
  default = "us-west-2"
}

# 应用监听端口（80 是 HTTP 默认端口，浏览器不用带端口号）
variable "app_port" {
  description = "Port the FastAPI app listens on"
  type        = number
  default     = 80
}

# RDS root user password
# 注意：真实项目里这个值应该放 AWS Secrets Manager 或 GitHub Secrets，
# 写在这里是为了让 terraform apply 能无人值守跑通
variable "db_pwd" {
  description = "RDS root user password"
  type        = string
  default     = "CadW11Lab2026!"
}

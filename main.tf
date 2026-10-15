terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # 2nd version：把 state 和执行都交给 HCP Terraform（原 Terraform Cloud）托管，
  # 不再需要 S3 bucket，也不用在 runner 上留 state。
  #
  # 注意：用之前你必须先做完这三步：
  #   1. 注册 HCP Terraform 账号（免费）：https://app.terraform.io/signup
  #   2. 建一个 organization，把下面 organization 的值换成你的
  #   3. 建一个名为 cad-w11 的 workspace，选 CLI-driven workflow，
  #      并把 AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_SESSION_TOKEN
  #      加进 workspace 变量
  #
  # 课件在这里提的顾虑是 vendor lock-in：state 和执行都进了 HashiCorp 的云，
  # 想再换回 S3 backend 就得做一次 state 迁移。
  cloud {
    organization = "REPLACE_WITH_YOUR_ORG"

    workspaces {
      name = "cad-w11"
    }
  }
}

# Region: 和你 AWS Academy Lab 控制台右上角显示的一致
variable "aws_region" {
  default = "us-west-2"
}

provider "aws" {
  region = var.aws_region
}

# 1) Fetch a recent Ubuntu image (Canonical 发布的公共 SSM 参数)
data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

# 2) Set up inbound connections: 80 (HTTP) + 22 (SSH, 给 EC2 Instance Connect 用)
resource "aws_security_group" "server_allow_http" {
  name        = "server-allow-http"
  description = "Allow HTTP and SSH inbound"

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "server-allow-http"
  }
}

# 3) Create a VM
resource "aws_instance" "sandbox" {
  ami                    = data.aws_ssm_parameter.ubuntu.value
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.server_allow_http.id]

  # Inject startup scripts
  user_data = file("user_data.tpl")

  tags = {
    Name = "sandbox"
  }
}

output "public_ip" {
  value = aws_instance.sandbox.public_ip
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # 远程 state：GitHub Actions 的 runner 每次都是新机器，
  # 没有这个的话每次 apply 都以为是从零开始，会重复创建资源
  backend "s3" {
    bucket = "cad-w11-tfstate-482183176805"
    key    = "cad-w11/terraform.tfstate"
    region = "us-west-2"
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

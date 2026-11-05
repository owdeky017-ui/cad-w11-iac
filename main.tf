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

  # user_data 改了要让实例重建一次，否则新脚本永远不会执行
  user_data_replace_on_change = true

  tags = {
    Name = "sandbox"
  }
}

# 4) 弹性 IP：在控制台手工分配，并打上 tag name=my_eip
#    Terraform 只负责“按标签查到它 + 绑定到实例”，不负责创建和释放
data "aws_eip" "server_eip" {
  filter {
    name   = "tag:name"
    values = ["my_eip"]
  }
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.sandbox.id
  allocation_id = data.aws_eip.server_eip.id
}

output "public_ip" {
  value       = "http://${aws_eip_association.eip_assoc.public_ip}:80/"
  description = "The public IP of your application"
}

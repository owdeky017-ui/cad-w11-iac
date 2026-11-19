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

provider "aws" {
  region = var.aws_region
}

# 1) Fetch a recent Ubuntu image (Canonical 发布的公共 SSM 参数)
data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

# 2) Set up inbound connections: app port (HTTP) + 22 (SSH, 给 EC2 Instance Connect 用)
resource "aws_security_group" "server_allow_http" {
  name        = "server-allow-http"
  description = "Allow HTTP and SSH inbound"

  ingress {
    description = "HTTP from anywhere"
    from_port   = var.app_port
    to_port     = var.app_port
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

# 3) 数据库在控制台手工建好（RDS PostgreSQL），Terraform 只读它的连接信息
data "aws_db_instance" "rds_database" {
  db_instance_identifier = "database-1"
}

# 4) Create a VM
resource "aws_instance" "sandbox" {
  ami = data.aws_ssm_parameter.ubuntu.value

  instance_type = "t3.micro"

  # Add security group: 自己的 + RDS 的那个（RDS 的 SG 允许同组成员访问 5432）
  vpc_security_group_ids = [
    aws_security_group.server_allow_http.id,
    data.aws_db_instance.rds_database.vpc_security_groups[0]
  ]

  # Inject startup scripts
  user_data = templatefile("user_data.tpl", {
    app_port = var.app_port
    db_user  = data.aws_db_instance.rds_database.master_username
    db_pwd   = var.db_pwd
    db_host  = data.aws_db_instance.rds_database.address
    db_port  = data.aws_db_instance.rds_database.port
  })

  # user_data 改了要让实例重建一次，否则新脚本永远不会执行
  user_data_replace_on_change = true

  tags = {
    Name = "sandbox"
  }
}

# 5) 弹性 IP：在控制台手工分配，并打上 tag name=my_eip
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
  value       = "http://${aws_eip_association.eip_assoc.public_ip}:${var.app_port}/"
  description = "The public IP of your application"
}

output "db_endpoint" {
  value       = data.aws_db_instance.rds_database.address
  description = "RDS PostgreSQL endpoint"
}

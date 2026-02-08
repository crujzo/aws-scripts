terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# ------------------------------------------------------------
# AMI – Amazon Linux 2023 (ARM64)
# ------------------------------------------------------------
data "aws_ami" "al2023_arm" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-6.*-arm64"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}

# ------------------------------------------------------------
# Security Group – NAT Instance
# ------------------------------------------------------------
resource "aws_security_group" "nat_sg" {
  name        = "${var.name}-nat-sg"
  description = "Security group for NAT instance"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow all traffic from VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-nat-sg"
  }
}

# ------------------------------------------------------------
# NAT Instance
# ------------------------------------------------------------
resource "aws_instance" "nat" {
  ami                         = data.aws_ami.al2023_arm.id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  associate_public_ip_address = true
  source_dest_check            = false

  vpc_security_group_ids = [
    aws_security_group.nat_sg.id
  ]

  iam_instance_profile = var.iam_instance_profile

  user_data = file("${path.module}/userdata-nat.sh")

  tags = {
    Name = "${var.name}-nat-instance"
    Role = "nat"
  }
}

# ------------------------------------------------------------
# Private Subnet Route → NAT ENI
# ------------------------------------------------------------
resource "aws_route" "private_nat_route" {
  route_table_id         = var.private_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id  = aws_instance.nat.primary_network_interface_id
}

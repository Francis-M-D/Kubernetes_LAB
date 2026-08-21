terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# --------------------------------------------------
# VPC
# --------------------------------------------------

resource "aws_vpc" "k8s_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "k8s-lab-vpc"
  }
}

# --------------------------------------------------
# Public Subnet
# --------------------------------------------------

resource "aws_subnet" "k8s_public_subnet" {
  vpc_id                  = aws_vpc.k8s_vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "k8s-public-subnet"
  }
}

# --------------------------------------------------
# Internet Gateway
# --------------------------------------------------

resource "aws_internet_gateway" "k8s_igw" {
  vpc_id = aws_vpc.k8s_vpc.id

  tags = {
    Name = "k8s-lab-igw"
  }
}

# --------------------------------------------------
# Public Route Table
# --------------------------------------------------

resource "aws_route_table" "k8s_public_rt" {
  vpc_id = aws_vpc.k8s_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.k8s_igw.id
  }

  tags = {
    Name = "k8s-public-route-table"
  }
}

resource "aws_route_table_association" "k8s_public_association" {
  subnet_id      = aws_subnet.k8s_public_subnet.id
  route_table_id = aws_route_table.k8s_public_rt.id
}

# --------------------------------------------------
# Control Plane Security Group
# --------------------------------------------------

resource "aws_security_group" "control_plane_sg" {
  name        = "k8s-control-plane-sg"
  description = "Security group for Kubernetes control plane"
  vpc_id      = aws_vpc.k8s_vpc.id

  # Kubernetes control plane ports
  ingress {
    description = "Kubernetes API Server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # kubelet and Kubernetes control-plane related ports
  ingress {
    description = "Kubernetes control plane ports"
    from_port   = 10248
    to_port     = 10260
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # etcd
  ingress {
    description = "etcd"
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # SSH
  ingress {
    description = "SSH from administrator IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_ip_cidr]
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "k8s-control-plane-sg"
  }
}

# --------------------------------------------------
# Worker Node Security Group
# --------------------------------------------------

resource "aws_security_group" "worker_sg" {
  name        = "k8s-worker-sg"
  description = "Security group for Kubernetes worker nodes"
  vpc_id      = aws_vpc.k8s_vpc.id

  # Kubelet
  ingress {
    description = "Kubelet API"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # kube-proxy
  ingress {
    description = "kube-proxy"
    from_port   = 10256
    to_port     = 10256
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # NodePort
  ingress {
    description = "Kubernetes NodePort"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # SSH
  ingress {
    description = "SSH from administrator IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_ip_cidr]
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "k8s-worker-sg"
  }
}

# --------------------------------------------------
# Control Plane EC2
# --------------------------------------------------

resource "aws_instance" "control_plane" {
  ami                         = var.ubuntu_ami
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.k8s_public_subnet.id
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.control_plane_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"

    tags = {
      Name = "k8s-control-plane-root"
    }
  }

  tags = {
    Name = "k8s-control-plane"
    Role = "control-plane"
  }
}

# --------------------------------------------------
# Worker Node 1
# --------------------------------------------------

resource "aws_instance" "worker_1" {
  ami                         = var.ubuntu_ami
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.k8s_public_subnet.id
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.worker_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"

    tags = {
      Name = "k8s-worker-1-root"
    }
  }

  tags = {
    Name = "k8s-worker-1"
    Role = "worker"
  }
}

# --------------------------------------------------
# Worker Node 2
# --------------------------------------------------

resource "aws_instance" "worker_2" {
  ami                         = var.ubuntu_ami
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.k8s_public_subnet.id
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.worker_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"

    tags = {
      Name = "k8s-worker-2-root"
    }
  }

  tags = {
    Name = "k8s-worker-2"
    Role = "worker"
  }
}

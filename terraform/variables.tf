variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "vpc_cidr" {
  description = "CIDR block for Kubernetes lab VPC"
  type        = string
  default     = "172.31.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "172.31.1.0/24"
}

variable "ssh_ip_cidr" {
  description = "CIDR block for ssh from my IP"
  type        = string
  default     = "106.192.162.183/32"
}

variable "ubuntu_ami" {
  description = "Ubuntu AMI ID"
  type        = string
  default     = "ami-01a00762f46d584a1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "Existing AWS EC2 key pair"
  type        = string
  default     = "LinuxKey"
}

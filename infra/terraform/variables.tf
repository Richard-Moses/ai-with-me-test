variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-2"
}

variable "vpc_cidr" {
  description = "CIDR block for devops-vpc"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_a_cidr" {
  description = "CIDR block for subnet-a"
  type        = string
  default     = "10.0.1.0/24"
}

variable "subnet_b_cidr" {
  description = "CIDR block for subnet-b"
  type        = string
  default     = "10.0.2.0/24"
}

variable "instance_type" {
  description = "EC2 instance type for all three servers"
  type        = string
  default     = "t2.micro"
}

variable "root_volume_size" {
  description = "Root disk size in GB for each server"
  type        = number
  default     = 20
}

variable "public_key_path" {
  description = "Path to the SSH PUBLIC key to register as the EC2 key pair"
  type        = string
  default     = "~/.ssh/oeson_key.pub"
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH (port 22) and to reach Jenkins (8080) and the Kubernetes API (6443). Use your own IP, e.g. 203.0.113.10/32. No default on purpose."
  type        = string
}

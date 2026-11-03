data "aws_availability_zones" "available" {
  state = "available"
}

# Ubuntu 22.04 LTS (Canonical)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---------- Network ----------

resource "aws_vpc" "devops_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "devops-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.devops_vpc.id

  tags = { Name = "devops-igw" }
}

resource "aws_subnet" "subnet_a" {
  vpc_id                  = aws_vpc.devops_vpc.id
  cidr_block              = var.subnet_a_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = { Name = "subnet-a" }
}

resource "aws_subnet" "subnet_b" {
  vpc_id                  = aws_vpc.devops_vpc.id
  cidr_block              = var.subnet_b_cidr
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = { Name = "subnet-b" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.devops_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "devops-public-rt" }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.public.id
}

# ---------- Security group ----------

resource "aws_security_group" "devops_sg" {
  name        = "devops-sg"
  description = "SSH, HTTP, NodePort range, Jenkins, Kubernetes API, and intra-cluster traffic"
  vpc_id      = aws_vpc.devops_vpc.id

  tags = { Name = "devops-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.devops_sg.id
  description       = "SSH (restricted to your IP)"
  cidr_ipv4         = var.allowed_ssh_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.devops_sg.id
  description       = "HTTP"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "nodeport" {
  security_group_id = aws_security_group.devops_sg.id
  description       = "Kubernetes NodePort range"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 30000
  to_port           = 32767
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "jenkins" {
  security_group_id = aws_security_group.devops_sg.id
  description       = "Jenkins UI (restricted to your IP)"
  cidr_ipv4         = var.allowed_ssh_cidr
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "k8s_api" {
  security_group_id = aws_security_group.devops_sg.id
  description       = "Kubernetes API from your IP"
  cidr_ipv4         = var.allowed_ssh_cidr
  from_port         = 6443
  to_port           = 6443
  ip_protocol       = "tcp"
}

# The Jenkins server must reach the Kubernetes API to run kubectl
resource "aws_vpc_security_group_ingress_rule" "k8s_api_from_vpc" {
  security_group_id = aws_security_group.devops_sg.id
  description       = "Kubernetes API from inside the VPC"
  cidr_ipv4         = var.vpc_cidr
  from_port         = 6443
  to_port           = 6443
  ip_protocol       = "tcp"
}

# Kubelet, CNI (Flannel/Calico), node_exporter etc. between the servers
resource "aws_vpc_security_group_ingress_rule" "intra_cluster" {
  security_group_id            = aws_security_group.devops_sg.id
  description                  = "All traffic between servers in this security group"
  referenced_security_group_id = aws_security_group.devops_sg.id
  ip_protocol                  = "-1"
}

resource "aws_vpc_security_group_egress_rule" "all_out" {
  security_group_id = aws_security_group.devops_sg.id
  description       = "All outbound"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ---------- Key pair ----------

resource "aws_key_pair" "oeson_key" {
  key_name   = "oeson-key"
  public_key = file(pathexpand(var.public_key_path))
}

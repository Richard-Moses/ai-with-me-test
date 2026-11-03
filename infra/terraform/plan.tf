# plan.tf: the compute plan (Task 6 naming: infra/terraform/plan.tf).
# 1 Jenkins server + 2 Kubernetes nodes, all t2.micro by default (see var.instance_type).
# The network, security group and key pair they use are in main.tf.
# Terraform loads every .tf file in this folder, so splitting files changes nothing in state.

resource "aws_instance" "jenkins_host" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.subnet_a.id
  vpc_security_group_ids = [aws_security_group.devops_sg.id]
  key_name               = aws_key_pair.oeson_key.key_name

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = { Name = "jenkins-host", Role = "jenkins" }
}

resource "aws_instance" "k8s_node_1" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.subnet_a.id
  vpc_security_group_ids = [aws_security_group.devops_sg.id]
  key_name               = aws_key_pair.oeson_key.key_name

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = { Name = "k8s-node-1", Role = "k8s-control-plane" }
}

resource "aws_instance" "k8s_node_2" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.subnet_b.id
  vpc_security_group_ids = [aws_security_group.devops_sg.id]
  key_name               = aws_key_pair.oeson_key.key_name

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = { Name = "k8s-node-2", Role = "k8s-worker" }
}

output "jenkins_public_ip" {
  description = "Jenkins public IP (browse to http://<ip>:8080)"
  value       = aws_instance.jenkins_host.public_ip
}

output "k8s_node_1_public_ip" {
  description = "Kubernetes control-plane public IP"
  value       = aws_instance.k8s_node_1.public_ip
}

output "k8s_node_2_public_ip" {
  description = "Kubernetes worker public IP"
  value       = aws_instance.k8s_node_2.public_ip
}

output "jenkins_private_ip" {
  description = "Jenkins private IP (used by Ansible when run from inside the VPC)"
  value       = aws_instance.jenkins_host.private_ip
}

output "k8s_node_1_private_ip" {
  description = "Kubernetes control-plane private IP"
  value       = aws_instance.k8s_node_1.private_ip
}

output "k8s_node_2_private_ip" {
  description = "Kubernetes worker private IP"
  value       = aws_instance.k8s_node_2.private_ip
}

output "kubernetes_node_ips" {
  description = "Kubernetes node public IPs"
  value       = [aws_instance.k8s_node_1.public_ip, aws_instance.k8s_node_2.public_ip]
}

output "kubernetes_node_private_ips" {
  description = "Kubernetes node private IPs (used between the servers)"
  value       = [aws_instance.k8s_node_1.private_ip, aws_instance.k8s_node_2.private_ip]
}

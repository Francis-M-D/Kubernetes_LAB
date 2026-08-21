output "vpc_id" {
  description = "Kubernetes lab VPC ID"
  value       = aws_vpc.k8s_vpc.id
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = aws_subnet.k8s_public_subnet.id
}

output "control_plane_public_ip" {
  description = "Public IP of Kubernetes control plane"
  value       = aws_instance.control_plane.public_ip
}

output "control_plane_private_ip" {
  description = "Private IP of Kubernetes control plane"
  value       = aws_instance.control_plane.private_ip
}

output "worker_1_public_ip" {
  description = "Public IP of worker node 1"
  value       = aws_instance.worker_1.public_ip
}

output "worker_1_private_ip" {
  description = "Private IP of worker node 1"
  value       = aws_instance.worker_1.private_ip
}

output "worker_2_public_ip" {
  description = "Public IP of worker node 2"
  value       = aws_instance.worker_2.public_ip
}

output "worker_2_private_ip" {
  description = "Private IP of worker node 2"
  value       = aws_instance.worker_2.private_ip
}

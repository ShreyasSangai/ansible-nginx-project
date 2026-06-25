output "master_public_ip" {
  description = "Master node public IP"
  value       = aws_instance.master.public_ip
}

output "master_instance_id" {
  description = "Master node Instance ID"
  value       = aws_instance.master.id
}

output "node_public_ips" {
  description = "Managed nodes public IPs"
  value       = aws_instance.nodes[*].public_ip
}

output "node_instance_ids" {
  description = "Managed nodes Instance IDs"
  value       = aws_instance.nodes[*].id
}

output "jenkins_url" {
  description = "Jenkins URL"
  value       = "http://${aws_instance.master.public_ip}:8080"
}
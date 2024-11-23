output "ansible_hosts_file" {
  value = templatefile("hosts.tpl", {
    bastion_ip    = aws_instance.bastion_host.public_ip,
    web_server_ip = aws_instance.web_server.private_ip
  })
}

output "private_key" {
  value     = tls_private_key.example.private_key_pem
  sensitive = true
}

output "bastion_ip" {
  value = aws_instance.bastion_host.public_ip
}
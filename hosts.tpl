
[bastion]
${bastion_ip} ansible_user=ec2-user ansible_ssh_private_key_file=web_server.pem

[web_servers]
${web_server_ip} ansible_user=ec2-user ansible_ssh_private_key_file=web_server.pem
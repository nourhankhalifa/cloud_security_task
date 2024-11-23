[web_servers]
%{ for ip in hosts ~}
${ip} ansible_user=ec2-user ansible_ssh_private_key_file=web_server.pem
%{ endfor ~}
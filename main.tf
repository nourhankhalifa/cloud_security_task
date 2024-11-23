data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "web_server"
  public_key = tls_private_key.example.public_key_openssh
}


resource "aws_instance" "web_server" {
  ami           = "ami-012967cc5a8c9f891"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.generated_key.key_name

  vpc_security_group_ids = [aws_security_group.web_server_sg.id]

  tags = {
    Name = "Farming-BV-Web-Server"
  }
}

resource "aws_security_group" "web_server_sg" {
  name_prefix = "web-server-sg"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "ansible_hosts_file" {
  value = templatefile("hosts.tpl", {
    hosts = aws_instance.web_server.*.public_ip
  })
}

output "private_key" {
  value     = tls_private_key.example.private_key_pem
  sensitive = true
}

resource "null_resource" "generate_ansible_hosts" {
  triggers = {
    always_run = timestamp()
  }
  provisioner "local-exec" {
    command = <<EOT
      terraform output -json ansible_hosts_file | tr -d '%0A' | grep -v '/_temp/' | xargs printf "%b" | grep -v "::debug::" > ./ansible_hosts
      # terraform output -json ansible_hosts_file | sed -e 's/^"//' -e 's/"$//' -e 's/\\\\n/\n/g' | grep -v "::debug::" > ./ansible_hosts
    EOT
  }
  provisioner "local-exec" {
    command = <<EOT
      terraform output -raw private_key > ./web_server.pem
    EOT
  }
}

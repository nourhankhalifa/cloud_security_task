data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

data "aws_ec2_managed_prefix_list" "cloudfront" {
 name = "com.amazonaws.global.cloudfront.origin-facing"
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

resource "aws_security_group_rule" "web_server_sg_cloudfront" {
  description = "HTTP from CloudFront"
  security_group_id = aws_security_group.web_server_sg.id
  type = "ingress"
  from_port = 80
  to_port = 80
  protocol = "tcp"
  prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront.id]
}

resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name = aws_instance.web_server.public_dns
    origin_id   = "my-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols = [ "SSLv3" ]
    }
  }

  enabled             = true
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "my-origin"

    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
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
      terraform output -json ansible_hosts_file | grep -v '%0A' | grep -v '/_temp/' | xargs printf "%b" | grep -v "::debug::" > ./ansible_hosts
      # terraform output -json ansible_hosts_file | sed -e 's/^"//' -e 's/"$//' -e 's/\\\\n/\n/g' | grep -v "::debug::" > ./ansible_hosts
    EOT
  }
  provisioner "local-exec" {
    command = <<EOT
      terraform output -raw private_key > ./web_server.pem
    EOT
  }
}
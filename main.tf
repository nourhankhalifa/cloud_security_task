data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

data "aws_ec2_managed_prefix_list" "cloudfront" {
 name = "com.amazonaws.global.cloudfront.origin-facing"
}

# Define the VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main-vpc"
  }
}

# Define the Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-internet-gateway"
  }
}

# Define the Route Table for the Public Subnet
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# Associate the Public Subnet with the Route Table
resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# Define an Elastic IP for the NAT Gateway
resource "aws_eip" "nat" {
  tags = {
    Name = "nat-eip"
  }
}

# Define the NAT Gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "nat-gateway"
  }
}

# Define the Route Table for the Private Subnet
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "private-route-table"
  }
}

# Associate the Private Subnet with the Route Table
resource "aws_route_table_association" "private_subnet_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}

# Subnet Definitions
resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "private-subnet"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}

# Key Pair
resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "web_server"
  public_key = tls_private_key.example.public_key_openssh
}

# Bastion Host
resource "aws_instance" "bastion_host" {
  ami           = "ami-012967cc5a8c9f891"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.generated_key.key_name

  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  subnet_id              = aws_subnet.public_subnet.id

  tags = {
    Name = "Bastion-Host"
  }
}

resource "aws_security_group" "bastion_sg" {
  name_prefix = "bastion-sg"
  vpc_id      = aws_vpc.main.id 

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

# web server
resource "aws_instance" "web_server" {
  ami           = "ami-012967cc5a8c9f891"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.generated_key.key_name

  vpc_security_group_ids = [aws_security_group.web_server_sg.id]
  subnet_id              = aws_subnet.private_subnet.id
  tags = {
    Name = "Farming-BV-Web-Server"
  }
}

resource "aws_security_group" "web_server_sg" {
  name_prefix = "web-server-sg"
  vpc_id      = aws_vpc.main.id 

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "web_server_ssh" {
  description       = "SSH access from my IP"
  security_group_id = aws_security_group.web_server_sg.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  source_security_group_id = aws_security_group.bastion_sg.id
}

resource "aws_security_group_rule" "web_server_sg_cloudfront" {
  description       = "HTTP from CloudFront"
  security_group_id = aws_security_group.web_server_sg.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  prefix_list_ids   = [data.aws_ec2_managed_prefix_list.cloudfront.id]
}

resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name = aws_instance.web_server.private_dns
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

resource "null_resource" "generate_ansible_hosts" {
  depends_on = [ aws_instance.web_server, aws_instance.bastion_host ]
  triggers = {
    always_run = timestamp()
  }
  provisioner "local-exec" {
    command = <<EOT
      terraform output -json ansible_hosts_file | grep -v '%0A' | grep -v '/_temp/' | xargs printf "%b" | grep -v "::debug::" > ./ansible_hosts
    EOT
  }
  provisioner "local-exec" {
    command = <<EOT
      terraform output -raw private_key > ./web_server.pem
    EOT
  }
}
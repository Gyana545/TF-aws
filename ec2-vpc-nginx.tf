terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.73.0"
    }
  }
}
provider "aws" {
  region = "ap-south-1"
}

#Create a VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "my_vpc"
  }
}

#Private subnet
resource "aws_subnet" "private-subnet" {
  cidr_block = "10.0.1.0/24"
  vpc_id     = aws_vpc.my_vpc.id
  tags = {
    Name = "private-subnet"
  }
}

#Public subnet
resource "aws_subnet" "public-subnet" {
  cidr_block              = "10.0.2.0/24"
  vpc_id                  = aws_vpc.my_vpc.id
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet"
  }
}

#Internet gateway
resource "aws_internet_gateway" "my-igw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "my-igw"
  }
}

#Routing table
resource "aws_route_table" "my-rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my-igw.id
  }
}

resource "aws_route_table_association" "public-sub" {
  route_table_id = aws_route_table.my-rt.id
  subnet_id      = aws_subnet.public-subnet.id
}
resource "aws_security_group" "nginx-sg" {
  vpc_id = aws_vpc.my_vpc.id

  #Inbound rule for HTTP
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #Outbound rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "nginx-sg"
  }
}

# EC2 instance For Nginx setup
resource "aws_instance" "nginxserver" {
  ami                         = "ami-03753afda9b8ba740"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public-subnet.id
  vpc_security_group_ids      = [aws_security_group.nginx-sg.id]
  associate_public_ip_address = true

  availability_zone           = "ap-south-1a"

  user_data = <<-EOF
            #!/bin/bash
            sudo yum install nginx -y
            sudo systemctl start nginx
            EOF

  tags = {
    Name = "NginxServer"
  }
}
output "instance_public_ip" {
  description = "The public IP address of the EC2 instance"
  value       = aws_instance.nginxserver.public_ip
}

output "instance_url" {
  description = "The URL to access the Nginx server"
  value       = "http://${aws_instance.nginxserver.public_ip}"
}
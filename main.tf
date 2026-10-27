provider "aws" {
  region = "af-south-1"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd*/ubuntu-*-26.04-amd64-server-*"]
  }
}

resource "aws_instance" "My_Instance" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  vpc_security_group_ids      = [aws_security_group.instance.id]
  user_data                   = <<-EOF
			#! /bin/bash
			echo "Hello World" > index.html
			nohup busybox httpd -f -p ${var.server_port} &
			EOF
  user_data_replace_on_change = true
  tags = {
    Name = "terraform-example"
  }
}

resource "aws_security_group" "instance" {
  name = "My_Instance_SG"
  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # This CIDR allows IP of any range

  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

variable "server_port" {
  description = "The port the server will use for HTTP requests"
  type        = number
  default     = 8080
}

output "public_ip" {
  description = "The public IP address of a web server"
  value       = aws_instance.My_Instance.public_ip
}

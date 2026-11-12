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
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Replaces aws_launch_configuration with a modern launch template
resource "aws_launch_template" "My_Instance" {
  name_prefix   = "my-instance-lt-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.instance.id]
  }

  user_data = base64encode(<<-EOF
      #! /bin/bash
      echo "Hello World" > index.html
      nohup busybox httpd -f -p ${var.server_port} &
      EOF
  )

  lifecycle {
    create_before_destroy = true
  }
}
# AWS ASG
resource "aws_autoscaling_group" "example" {
  target_group_arns    = [aws_alb_target_group.asg.arn]
  health_check_type    = "ELB" # Default check is EC2, this one uses target group health checks
  min_size             = 2
  max_size             = 10
  vpc_zone_identifier  = data.aws_subnets.default.ids
  # Use launch_template block instead of launch_configuration attribute
  launch_template {
    id      = aws_launch_template.My_Instance.id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }
}
# AWS ALB
resource "aws_lb" "example" {
  name               = "terraform-asg-example"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.default.ids
}

# AWS Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = 80
  protocol          = "HTTP"
  # By default, return a simple 404 page
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: Page not found fucker"
      status_code  = 404
    }
  }
}

# Target group for the auto scaling group
resource "aws_alb_target_group" "asg" {
  name     = "terraform-asg-example"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Adding the listener rules
resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100
  condition {
    path_pattern {
      values = ["*"]
    }
  }
  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.asg.arn
  }
}
# SG specifically for the load balancer
resource "aws_security_group" "alb" {
  name = "terraform-example-alb"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
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

output "alb_dns_name" {
  description = "The domain name of the load balancer"
  value       = aws_lb.example.dns_name
}

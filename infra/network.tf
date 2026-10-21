# Default VPC and its subnets. The ALB needs subnets in at least two availability zones.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Public entry point: accepts HTTP from anywhere, forwards only to tasks.
resource "aws_security_group" "alb" {
  name        = "${var.app_name}-alb"
  description = "Public HTTP to the load balancer"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP from the internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Forward to tasks"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Tasks have public IPs (no NAT gateway), but only the ALB may reach port 3000.
# Outbound is open so tasks can pull from ECR and write logs.
resource "aws_security_group" "tasks" {
  name        = "${var.app_name}-tasks"
  description = "App port reachable only from the ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "App traffic from the ALB only"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "ECR, CloudWatch Logs, and package traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

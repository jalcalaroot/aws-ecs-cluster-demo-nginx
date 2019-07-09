### ingresar credenciales
variable "access_key" {}
variable "secret_key" {}
variable "region" {}
provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region = "${var.region}"
}

variable "ecs_cluster" {
  type        = "string"
  description = "indicar el clustername"
}

resource "aws_ecs_cluster" "ecs" {
  name = "${var.ecs_cluster}"

  lifecycle {
    create_before_destroy = true
  }
}

#-----------------------------------------------------------
#VPC	
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true

  tags {
     Name = "main"
     env = "terraform"
  }
}


#Public Subnet 0
resource "aws_subnet" "public-subnet-0" {
  vpc_id            = "${aws_vpc.main.id}"
  availability_zone = "us-east-1a"
  cidr_block        = "10.0.128.0/20"
  map_public_ip_on_launch = true
  tags = {
    Name      = "public-subnet-0"
    env       = "terraform"
    layer     = "public"
  }
}
#Public Subnet 1
resource "aws_subnet" "public-subnet-1" {
  vpc_id            = "${aws_vpc.main.id}"
  availability_zone = "us-east-1b"
  cidr_block        = "10.0.144.0/20"
  map_public_ip_on_launch = true
  tags = {
    Name      = "public-subnet-1"
    env       = "terraform"
    layer     = "public"
  }
}
#Public Subnet 2
resource "aws_subnet" "public-subnet-2" {
  vpc_id            = "${aws_vpc.main.id}"
  availability_zone = "us-east-1c"
  cidr_block        = "10.0.160.0/20"	
  map_public_ip_on_launch = true
  tags = {
    Name      = "public-subnet-2"
    env       = "terraform"
    layer     = "public"
  }
}
resource "aws_internet_gateway" "main-igw" {
  vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name      = "main-igw"
    env       = "terraform"
  }
}

resource "aws_route_table" "public-rt" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.main-igw.id}"
  }
  tags = {
    Name      = "public-rt"
    env       = "terraform"
  }
}
resource "aws_route_table_association" "public-subnets-assoc-0" {
  subnet_id      = "${element(aws_subnet.public-subnet-0.*.id, count.index)}"
  route_table_id = "${aws_route_table.public-rt.id}"
}
resource "aws_route_table_association" "public-subnets-assoc-1" {
  subnet_id      = "${element(aws_subnet.public-subnet-1.*.id, count.index)}"
  route_table_id = "${aws_route_table.public-rt.id}"
}
resource "aws_route_table_association" "public-subnets-assoc-2" {
  subnet_id      = "${element(aws_subnet.public-subnet-2.*.id, count.index)}"
  route_table_id = "${aws_route_table.public-rt.id}"
}

output "vpc_id" {
  value = "${aws_vpc.main.id}"
}

output "public-subnet-0" {
  value = "${aws_subnet.public-subnet-0.id}"
}
#----------------------------------------------------
#SG
resource "aws_security_group" "main" {
  name = "main"
  description = "main"
  vpc_id      = "${aws_vpc.main.id}"

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [
      "0.0.0.0/0"]
  }
# SSH
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"]
  }
# HTTP
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"]
  }

# https
  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"]
  }

# 8080
  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"]
  }

  tags = {
    name = "main"
    env  = "terraform"
  }
}

#-----------------------------------------------
resource "aws_key_pair" "main" {
  key_name = "main"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7f56ewMZz4WLRzKLy8mnJ2ZS1gWhDiE3A4UinEqlogZQCuibNRSsF8C9oXg6IlxdeqBet5Zx4jf/qgTuEDVCF7QyyYxFtNKctSX901spJXhpusx4k9aMPmsTHGCj7DL1mHKwrvb7fSdJcsffo8R/3NWzP7bBcwLgZeTw/vSYvECNnco7yvPhIiHSvTfggj8s4tVEMb8vqkvfDJm6gRTpw3+KsA2yZGuiSFNQQcpbckVwbP5iSbalmJkRBPV5PWVx1wYLkSuPY4b6wAYyggfJ50rRO5Pvs7xhyJ7cXxTflE1OalZNpSLkAErYn4uuiW6az4BMHTB2aTVt98JEeoIwF main@main-VIT-P2412"
}

#-------------------------------------------------

resource "aws_iam_role" "ecs-service-role" {
    name                = "ecs-service-role"
    path                = "/"
    assume_role_policy  = "${data.aws_iam_policy_document.ecs-service-policy.json}"
}

resource "aws_iam_role_policy_attachment" "ecs-service-role-attachment" {
    role       = "${aws_iam_role.ecs-service-role.name}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

data "aws_iam_policy_document" "ecs-service-policy" {
    statement {
        actions = ["sts:AssumeRole"]

        principals {
            type        = "Service"
            identifiers = ["ecs.amazonaws.com"]
        }
    }
}


resource "aws_iam_role" "ecs-instance-role" {
    name                = "ecs-instance-role"
    path                = "/"
    assume_role_policy  = "${data.aws_iam_policy_document.ecs-instance-policy.json}"
}

data "aws_iam_policy_document" "ecs-instance-policy" {
    statement {
        actions = ["sts:AssumeRole"]

        principals {
            type        = "Service"
            identifiers = ["ec2.amazonaws.com"]
        }
    }
}

resource "aws_iam_role_policy_attachment" "ecs-instance-role-attachment" {
    role       = "${aws_iam_role.ecs-instance-role.name}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs-instance-profile" {
    name = "ecs-instance-profile"
    path = "/"
    roles = ["${aws_iam_role.ecs-instance-role.id}"]
    provisioner "local-exec" {
      command = "sleep 10"
    }
}

#--------------------------------------------------------

resource "aws_alb" "ecs-load-balancer" {
    name                = "ecs-load-balancer"
    security_groups     = ["${aws_security_group.main.id}"]
    subnets             = ["${aws_subnet.public-subnet-0.id}", "${aws_subnet.public-subnet-1.id}", "${aws_subnet.public-subnet-2.id}"]

    tags {
      Name = "ecs-load-balancer"
    }
}

resource "aws_alb_target_group" "ecs-target-group" {
    name                = "ecs-target-group"
    port                = "80"
    protocol            = "HTTP"
    vpc_id              = "${aws_vpc.main.id}"

    health_check {
        healthy_threshold   = "5"
        unhealthy_threshold = "2"
        interval            = "30"
        matcher             = "200"
        path                = "/"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = "5"
    }

lifecycle {
    create_before_destroy = true
  }

  depends_on = ["aws_alb.ecs-load-balancer"] // HERE!
}


resource "aws_alb_listener" "alb-listener" {
    load_balancer_arn = "${aws_alb.ecs-load-balancer.arn}"
    port              = "80"
    protocol          = "HTTP"

    default_action {
        target_group_arn = "${aws_alb_target_group.ecs-target-group.arn}"
        type             = "forward"
    }
}

#------------------------------------------------------------------

resource "aws_launch_configuration" "ecs-launch-configuration" {
    name                        = "ecs-launch-configuration"
    image_id                    = "ami-fad25980"
    instance_type               = "t3.small"
    iam_instance_profile        = "${aws_iam_instance_profile.ecs-instance-profile.id}"

    root_block_device {
      volume_type = "gp2"
      volume_size = 50
      delete_on_termination = true
    }

    lifecycle {
      create_before_destroy = true
    }

    security_groups             = ["${aws_security_group.main.id}"]
    associate_public_ip_address = "true"
    key_name                    = "main"
    user_data                   = <<EOF
                                  #!/bin/bash
                                  echo ECS_CLUSTER=${var.ecs_cluster} >> /etc/ecs/ecs.config
                                  EOF
}

resource "aws_autoscaling_group" "ecs-autoscaling-group" {
    name                        = "ecs-autoscaling-group"
    max_size                    = "3"
    min_size                    = "3"
    desired_capacity            = "3"
    vpc_zone_identifier         = ["${aws_subnet.public-subnet-0.id}", "${aws_subnet.public-subnet-1.id}", "${aws_subnet.public-subnet-2.id}"]
    launch_configuration        = "${aws_launch_configuration.ecs-launch-configuration.name}"
    health_check_type           = "ELB"
tag {
    key = "Name"
    value = "node-${var.ecs_cluster}"
    propagate_at_launch = true
  }
}

#-----------------------------------------------


# NGINX Service
resource "aws_ecs_service" "nginx" {
  name            = "nginx"
  cluster         = "${var.ecs_cluster}"
  task_definition = "${aws_ecs_task_definition.nginx.arn}"
  desired_count   = 1
  iam_role        = "${aws_iam_role.ecs-service-role.name}"

  load_balancer {
    target_group_arn = "${aws_alb_target_group.ecs-target-group.id}"
    container_name   = "nginx"
    container_port   = "80"
  }

  lifecycle {
    ignore_changes = ["task_definition"]
  }
}

resource "aws_ecs_task_definition" "nginx" {
  family = "nginx"

  container_definitions = <<EOF
[
  {
    "portMappings": [
      {
        "hostPort": 80,
        "protocol": "tcp",
        "containerPort": 80
      }
    ],
    "cpu": 256,
    "memory": 300,
    "image": "nginx:latest",
    "essential": true,
    "name": "nginx",
    "logConfiguration": {
    "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs-demo/nginx",
        "awslogs-region": "${var.region}",
        "awslogs-stream-prefix": "ecs"
      }
    }
  }
]
EOF
}

resource "aws_cloudwatch_log_group" "nginx" {
  name = "/ecs-demo/nginx"
}

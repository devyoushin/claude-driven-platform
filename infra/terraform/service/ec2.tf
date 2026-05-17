###############################################################################
# EC2 Instances - EKS 외 워크로드용
###############################################################################

# 최신 Amazon Linux 2023 AMI
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

###############################################################################
# Launch Template
###############################################################################

resource "aws_launch_template" "app" {
  name_prefix   = "${local.name}-app-"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.ec2_instance_type

  vpc_security_group_ids = [aws_security_group.ec2_app.id]

  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2_app.arn
  }

  monitoring {
    enabled = true  # Detailed monitoring for CloudWatch
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # IMDSv2 필수
    http_put_response_hop_limit = 1
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(module.tags.tags, {
      Name = "${local.name}-app"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(module.tags.tags, {
      Name = "${local.name}-app-volume"
    })
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    # CloudWatch Agent 설치
    yum install -y amazon-cloudwatch-agent
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config -m ec2 -s
  EOF
  )

  tags = module.tags.tags
}

###############################################################################
# Auto Scaling Group
###############################################################################

resource "aws_autoscaling_group" "app" {
  name_prefix         = "${local.name}-app-"
  desired_capacity    = 2
  max_size            = 4
  min_size            = 1
  vpc_zone_identifier = module.vpc.private_app_subnet_ids
  health_check_type   = "EC2"

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  dynamic "tag" {
    for_each = merge(module.tags.tags, { Name = "${local.name}-app-asg" })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

###############################################################################
# Security Group
###############################################################################

resource "aws_security_group" "ec2_app" {
  name_prefix = "${local.name}-ec2-app-"
  vpc_id      = module.vpc.vpc_id
  description = "Security group for application EC2 instances"

  ingress {
    description = "Allow traffic from Landing Zone ALB via TGW"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    description = "Allow internal VPC traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(module.tags.tags, {
    Name = "${local.name}-ec2-app-sg"
  })
}

###############################################################################
# IAM Role for EC2
###############################################################################

resource "aws_iam_role" "ec2_app" {
  name = "${local.name}-ec2-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = module.tags.tags
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.ec2_app.name
}

resource "aws_iam_role_policy_attachment" "ec2_cloudwatch" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.ec2_app.name
}

resource "aws_iam_instance_profile" "ec2_app" {
  name = "${local.name}-ec2-app-profile"
  role = aws_iam_role.ec2_app.name

  tags = module.tags.tags
}

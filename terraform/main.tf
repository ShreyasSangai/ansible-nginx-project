provider "aws" {
  region = var.aws_region
}

# --------------------------------------------------
# DATA SOURCE — Latest Amazon Linux 2 AMI
# --------------------------------------------------
data "aws_ami" "amazon_linux2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# --------------------------------------------------
# VPC — Default VPC use karenge
# --------------------------------------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# --------------------------------------------------
# SECURITY GROUP — Master Node
# --------------------------------------------------
resource "aws_security_group" "master_sg" {
  name        = "ansible-master-sg"
  description = "Security group for Ansible + Jenkins master"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from your IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Jenkins Web UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "ansible-master-sg"
    Project = "ansible-nginx"
  }
}

# --------------------------------------------------
# SECURITY GROUP — Managed Nodes
# --------------------------------------------------
resource "aws_security_group" "node_sg" {
  name        = "ansible-node-sg"
  description = "Security group for Nginx managed nodes"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "SSH from Ansible master only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP public"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS public"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "ansible-node-sg"
    Project = "ansible-nginx"
  }
}

# --------------------------------------------------
# IAM ROLE — Master node AWS API access
# --------------------------------------------------
resource "aws_iam_role" "master_role" {
  name = "ansible-master-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Project = "ansible-nginx"
  }
}

resource "aws_iam_role_policy" "master_policy" {
  name = "ansible-master-policy"
  role = aws_iam_role.master_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeRegions",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "master_profile" {
  name = "ansible-master-profile"
  role = aws_iam_role.master_role.name
}

# --------------------------------------------------
# EC2 — MASTER NODE
# --------------------------------------------------
resource "aws_instance" "master" {
  ami                    = data.aws_ami.amazon_linux2.id
  instance_type          = "c7i-flex.large"
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.master_sg.id]
  subnet_id              = tolist(data.aws_subnets.default.ids)[0]
  iam_instance_profile   = aws_iam_instance_profile.master_profile.name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name        = "ansible-master"
    Role        = "master"
    Environment = "management"
    Project     = "ansible-nginx"
  }
}

# --------------------------------------------------
# EC2 — MANAGED NODES (Nginx servers)
# --------------------------------------------------
resource "aws_instance" "nodes" {
  count                  = var.node_count
  ami                    = data.aws_ami.amazon_linux2.id
  instance_type          = "t3.micro"
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.node_sg.id]
  subnet_id              = tolist(data.aws_subnets.default.ids)[0]

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  # YE TAGS CRITICAL HAIN — dynamic inventory inhi se filter karega
  tags = {
    Name        = "nginx-node-${count.index + 1}"
    Role        = "webserver"
    Environment = "production"
    Project     = "ansible-nginx"
  }
}
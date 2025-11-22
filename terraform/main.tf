terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  common_tags = {
    Project = "valkey-ha-demo"
    Owner   = var.owner
  }
}

# --- S3 bucket (for demo / artifacts) ----------------------------------------
resource "aws_s3_bucket" "valkey_bucket" {
  bucket        = var.s3_bucket_name
  force_destroy = true

  tags = merge(local.common_tags, {
    Name = "valkey-demo-bucket"
  })
}

# --- Key pair: create PEM locally + in AWS -----------------------------------
resource "tls_private_key" "valkey_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "valkey_private_key" {
  filename        = "${path.module}/valkey-demo-key.pem"
  content         = tls_private_key.valkey_key.private_key_pem
  file_permission = "0600"
}

resource "aws_key_pair" "valkey_key" {
  key_name   = var.key_name
  public_key = tls_private_key.valkey_key.public_key_openssh

  tags = merge(local.common_tags, {
    Name = var.key_name
  })
}

# --- Networking: VPC, subnets, IGW, NAT, routes -----------------------------
resource "aws_vpc" "valkey_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "valkey-vpc"
  })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.valkey_vpc.id

  tags = merge(local.common_tags, {
    Name = "valkey-igw"
  })
}

resource "aws_subnet" "bastion" {
  vpc_id                  = aws_vpc.valkey_vpc.id
  cidr_block              = var.bastion_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"

  tags = merge(local.common_tags, {
    Name = "bastion-subnet"
  })
}

resource "aws_subnet" "valkey_master" {
  vpc_id                  = aws_vpc.valkey_vpc.id
  cidr_block              = var.valkey_master_subnet_cidr
  map_public_ip_on_launch = false
  availability_zone       = "${var.aws_region}a"

  tags = merge(local.common_tags, {
    Name = "private-db-subnet-1"
  })
}

resource "aws_subnet" "valkey_replica" {
  vpc_id                  = aws_vpc.valkey_vpc.id
  cidr_block              = var.valkey_replica_subnet_cidr
  map_public_ip_on_launch = false
  availability_zone       = "${var.aws_region}a"

  tags = merge(local.common_tags, {
    Name = "private-db-subnet-2"
  })
}

# EIP + NAT gateway for private subnets' internet access
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "valkey-nat-eip"
  })
}

resource "aws_nat_gateway" "nat" {
  subnet_id     = aws_subnet.bastion.id
  allocation_id = aws_eip.nat.id

  tags = merge(local.common_tags, {
    Name = "valkey-nat-gw"
  })

  depends_on = [aws_internet_gateway.igw]
}

# Public route table (for bastion)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.valkey_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(local.common_tags, {
    Name = "valkey-public-rt"
  })
}

resource "aws_route_table_association" "public_bastion" {
  subnet_id      = aws_subnet.bastion.id
  route_table_id = aws_route_table.public.id
}

# Private route table (for master + replica, via NAT)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.valkey_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = merge(local.common_tags, {
    Name = "valkey-private-rt"
  })
}

resource "aws_route_table_association" "private_master" {
  subnet_id      = aws_subnet.valkey_master.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_replica" {
  subnet_id      = aws_subnet.valkey_replica.id
  route_table_id = aws_route_table.private.id
}

# --- Security groups ---------------------------------------------------------
# Bastion: SSH from internet
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "Allow SSH from anywhere"
  vpc_id      = aws_vpc.valkey_vpc.id

  ingress {
    description = "SSH from internet"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "bastion-sg"
  })
}

# Valkey SG: SSH only from bastion, Valkey between valkey nodes
resource "aws_security_group" "valkey_sg" {
  name        = "db-sg"
  description = "Valkey SG for master and replica"
  vpc_id      = aws_vpc.valkey_vpc.id

  # SSH from bastion only
  ingress {
    description      = "SSH from bastion"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    security_groups  = [aws_security_group.bastion_sg.id]
  }

  # Valkey port between valkey nodes (master <-> replica)
  ingress {
    description = "Valkey traffic within SG"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "db-sg"
  })
}

# --- AMI lookup --------------------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true

  owners = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --- EC2 instances: bastion, valkey master, valkey replica ---------------------
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type_bastion
  subnet_id                   = aws_subnet.bastion.id
  associate_public_ip_address = true
  key_name                    = aws_key_pair.valkey_key.key_name
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]

  tags = merge(local.common_tags, {
    Name = "bastion-host"
    Role = "bastion"
  })
}

resource "aws_instance" "valkey_master" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type_valkey
  subnet_id              = aws_subnet.valkey_master.id
  associate_public_ip_address = false
  key_name               = aws_key_pair.valkey_key.key_name
  vpc_security_group_ids = [aws_security_group.valkey_sg.id]

  tags = merge(local.common_tags, {
    Name = "master-valkey"
    Role = "valkey-master"
  })
}

resource "aws_instance" "valkey_replica" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type_valkey
  subnet_id              = aws_subnet.valkey_replica.id
  associate_public_ip_address = false
  key_name               = aws_key_pair.valkey_key.key_name
  vpc_security_group_ids = [aws_security_group.valkey_sg.id]

  tags = merge(local.common_tags, {
    Name = "replica-valkey"
    Role = "valkey-replica"
  })
}

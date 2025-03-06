terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

resource "aws_key_pair" "bielik_key" {
  key_name   = var.key_name
  public_key = file("./ssh/id_rsa.pub")
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"

  ingress {
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
}

resource "aws_spot_instance_request" "bielik_spot" {
  ami                  = var.ami_id
  instance_type        = var.instance_type
  key_name             = var.key_name

  security_groups = [ aws_security_group.allow_ssh.name ]
  associate_public_ip_address = true

  spot_price = var.spot_price
  wait_for_fulfillment = true

  root_block_device {
    volume_size = var.ebs_volume_size
    volume_type = "gp3"
  }

  tags = {
    Name = "bielik-gpu-spot"
  }

  depends_on = [ aws_key_pair.bielik_key ]
}


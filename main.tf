terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "ca-central-1"
}



resource "aws_vpc" "narutovpc" {
  cidr_block           = "10.0.0.0/16"
  provider             = aws.central
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"
  enable_classiclink   = "false"
  instance_tenancy     = "default"
  tags = {
    Name = "narutovpc"
  }
}


resource "aws_subnet" "narutosubnet" {
  vpc_id                  = aws_vpc.narutovpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = "true"
  availability_zone       = "ca-central-1a"
  tags = {
    Name = "narutosubnet"
  }
}



resource "aws_internet_gateway" "narutogateway" {
  vpc_id = aws_vpc.narutovpc.id
  tags = {
    Name = "narutogateway"
  }
}



resource "aws_route_table" "narutoRT" {
  vpc_id = aws_vpc.narutovpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.narutogateway.id
  }

  tags = {
    Name = "narutoRT"
  }
}



locals {
  ports_in  = [22, 80, 3000]
  ports_out = [0]
}

resource "aws_security_group" "narutoSG" {
  name        = "narutoSG"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.narutovpc.id


  dynamic "ingress" {
    for_each = toset(local.ports_in)
    content {
      description = "TLS from VPC"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  dynamic "egress" {
    for_each = toset(local.ports_out)
    content {
      description = "TLS from VPC"
      from_port   = egress.value
      to_port     = egress.value
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  tags = {
    Name = "narutoSG"
  }
}

resource "aws_instance" "narutoVM" {
  ami             = "ami-0843f7c45354d48b5"
  instance_type   = "t2.micro"
  key_name        = aws_key_pair.narutokeys.key_name
  security_groups = ["${aws_security_group.narutoSG.id}"]

  user_data = <<EOF
	#!/bin/bash
	
	#Installing git and cloning the repository
	yum install git -y
	mkdir lifebit_test
	cd lifebit_test
	git clone https://github.com/nodejs/examples.git
	cd examples/servers/express/api-with-express-and-handlebars
	#Installing Nodejs
	yum -y install curl
	curl -sL https://rpm.nodesource.com/setup_14.x | sudo bash -
	yum install -y nodejs
	npm install
	npm start &
EOF

  tags = {
    Name = "narutoVM"

  }

  subnet_id = aws_subnet.narutosubnet.id
}

resource "aws_key_pair" "narutokeys" {
  key_name   = "narutokeys"
  public_key = file("${path.module}/narutokeys.pub")
}


resource "aws_eip" "naruto_eip" {
  instance = aws_instance.narutoVM.id
  vpc      = true
}


resource "aws_route_table_association" "narutoRT_AS" {
  subnet_id      = aws_subnet.narutosubnet.id
  route_table_id = aws_route_table.narutoRT.id

}

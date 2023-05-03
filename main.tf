resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name        = var.vpc_name
    Environment = "dev"
    Terraform   = "true"
  }
}

################PUBLIC SUBNET##########################################
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name        = var.public_subnet
    Environment = "dev"
    Terraform   = "true"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id

  }
  tags = {
    Name      = "tf_public_rtb"
    Terraform = "true"
  }
}

resource "aws_route_table_association" "public" {
  route_table_id = aws_route_table.public_route_table.id
  subnet_id      = aws_subnet.public_subnet.id
}

#Create Internet Gateway
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "two_tier_igw"
  }
}

######################Private##############################

resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidr
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = false

  tags = {
    Name        = var.private_subnet
    Environment = "dev"
    Terraform   = "true"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_gateway.id

  }
  tags = {
    Name      = "tf_private_rtb"
    Terraform = "true"
  }
}

resource "aws_route_table_association" "private" {
  route_table_id = aws_route_table.private_route_table.id
  subnet_id      = aws_subnet.private_subnet.id
}

#Create EIP for NAT Gateway
resource "aws_eip" "nat_gateway_eip" {
  vpc = true
  tags = {
    Name = "two_tier_igw_eip"
  }
}

#Create NAT Gateway
resource "aws_nat_gateway" "nat_gateway" {
  subnet_id     = aws_subnet.private_subnet.id
  allocation_id = aws_eip.nat_gateway_eip.id
  tags = {
    Name = "demo_nat_gateway"
  }
}

###################################SG###########################

resource "aws_security_group" "allow_tls" {
  name        = "allow_ssh_http"
  description = "allow_ssh_http"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "allow_ssh_http"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  ingress {
    description = "allow_ssh_http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_ssh_http"
  }
}


resource "aws_db_subnet_group" "mydbgrp" {
  name       = "main"
  subnet_ids = [aws_subnet.private_subnet.id, aws_subnet.public_subnet.id]

  tags = {
    Name = "My DB subnet group"
  }
}

resource "aws_db_instance" "mydb" {
  allocated_storage      = 10
  max_allocated_storage  = 20
  port                   = 5432
  multi_az               = false
  db_name                = "mydb"
  identifier             = "mytest-devdb"
  engine                 = "postgres"
  engine_version         = "15.2"
  instance_class         = "db.t3.micro"
  username               = "postgresql"
  password               = "Manju230"
  db_subnet_group_name   = aws_db_subnet_group.mydbgrp.name
  vpc_security_group_ids = [aws_security_group.allow_tls.id]
  skip_final_snapshot    = true
  #final_snapshot_identifier = "test"
  deletion_protection     = false
  availability_zone       = "ap-south-1a"
  backup_retention_period = 0
  maintenance_window      = "Mon:00:00-Mon:03:00"

  tags = {
    name = "mydb"
  }
}

###########################################################################################

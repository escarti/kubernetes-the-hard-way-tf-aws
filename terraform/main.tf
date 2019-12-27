terraform {
  required_version = "0.12.12"

  backend "s3" {
    bucket         = "hf-sandbox-tfstate-bucket"
    encrypt        = true
    key            = "kubernetes-the-hard-way/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "sandbox-tfstate-lock-table"
    profile        = "kube-the-hard-way"
  }
}

provider "aws" {
  version = "2.33.0"
  region  = var.aws_region
  profile = var.aws_profile
}

resource "aws_key_pair" "kube_auth" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

# --- Networking ---

## -- VPC --
resource "aws_vpc" "kube_vpc" {
  cidr_block = "10.0.0.0/16"
}

## -- Internet Gateway --
resource "aws_internet_gateway" "kube_igw" {

  vpc_id = aws_vpc.kube_vpc.id

  tags = {
    Name = "kube_igw"
  }
}

## -- Public routing table
resource "aws_route_table" "kube_public_rt" {
  vpc_id = aws_vpc.kube_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.kube_igw.id
  }

  tags = {
    Name = "kube_public_rt"
  }
}

## -- Public subnets --
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "kube_public_subnet" {
  count = length(data.aws_availability_zones.available.names)

  vpc_id                  = aws_vpc.kube_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.kube_vpc.cidr_block, 8, count.index)
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "kube_public_${count.index}_sn"
  }
}
## -- Security groups --
resource "aws_security_group" "kube_web_open_sg" {
  vpc_id      = aws_vpc.kube_vpc.id
  description = "Security group for open to the internet"
  name        = "kube_web_open_sg"

  #SSH 
  ingress {
    description = "Incoming ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  #HTTP
  ingress {
    description = "Standard http incoming"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #HTTPS
  ingress {
    description = "Standard https incoming"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all ports and protocols to go out"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
## -- Subnet and Rout tabel association
resource "aws_route_table_association" "kube_public_assoc" {
  count = length(aws_subnet.kube_public_subnet)  
  subnet_id      = aws_subnet.kube_public_subnet[count.index].id
  route_table_id = aws_route_table.kube_public_rt.id
}

# --- Instances ---
resource "aws_instance" "kube_master" {
  count = length(aws_subnet.kube_public_subnet)

  instance_type = var.instance_type
  ami           = var.ami_type

  tags = {
    Name = "kube_master_${count.index}_instance"
  }

  key_name               = aws_key_pair.kube_auth.id
  vpc_security_group_ids = [aws_security_group.kube_web_open_sg.id]
  subnet_id              = aws_subnet.kube_public_subnet[count.index].id
}

resource "aws_instance" "kube_worker" {
  count = length(aws_subnet.kube_public_subnet)

  instance_type = var.instance_type
  ami           = var.ami_type

  tags = {
    Name = "kube_worker_${count.index}_instance"
  }

  key_name               = aws_key_pair.kube_auth.id
  vpc_security_group_ids = [aws_security_group.kube_web_open_sg.id]
  subnet_id              = aws_subnet.kube_public_subnet[count.index].id
}

resource "aws_instance" "kube_load_balancer" {
  
  instance_type = var.instance_type
  ami           = var.ami_type

  tags = {
    Name = "kube_api_load_balancer_instance"
  }

  key_name               = aws_key_pair.kube_auth.id
  vpc_security_group_ids = [aws_security_group.kube_web_open_sg.id]
  subnet_id              = aws_subnet.kube_public_subnet[0].id

}

resource "null_resource" "ansible_provisioner_file" {
    depends_on = [aws_instance.kube_load_balancer, aws_instance.kube_worker, aws_instance.kube_master]

    provisioner "local-exec" {
    command = <<EOD
cat <<EOF > aws_hosts.yml
---
all:
  children:

    master:
      hosts:
        ${join("\n\t\t\t\t", aws_instance.kube_master.*.public_ip)}
    
    workers:
      hosts:
        ${join("\n\t\t\t\t", aws_instance.kube_worker.*.public_ip)}

    api_lb:
      hosts:
        ${join("\n\t\t\t\t", aws_instance.kube_load_balancer.*.public_ip)}
            
EOF
EOD
  }
}

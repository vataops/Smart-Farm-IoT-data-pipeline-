resource "aws_vpc" "my_vpc" {
  cidr_block = "172.16.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "tf-example"
  }
}

resource "aws_internet_gateway" "my_vpc_gw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "tf-example"
  }
}

resource "aws_route_table" "example" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_vpc_gw.id
  }

  tags = {
    Name = "example"
  }
}

resource "aws_main_route_table_association" "a" {
  vpc_id         = aws_vpc.my_vpc.id
  route_table_id = aws_route_table.example.id
}

resource "aws_subnet" "my_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "172.16.10.0/24"
  availability_zone = "ap-northeast-2a"
  map_public_ip_on_launch = true
  tags = {
    Name = "tf-example"
  }
}

resource "aws_security_group" "allow_grafana" {
  name        = "Grafana-SecGp"
  description = "Allow inbound grafana traffic"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    description      = "Grafana traffic (3000) from VPC"
    from_port        = 3000
    to_port          = 3000
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "SSH from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_grafana"
  }
}

resource "aws_instance" "grafana-ec2-dwh" {
  ami           = "ami-058165de3b7202099" # ap-northeast-2 Ubuntu 22.04 (LTS)
  instance_type = "t2.nano"
  subnet_id = aws_subnet.my_subnet.id
  key_name = "ubuntu-key"

  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.allow_grafana.id]

  user_data = <<EOF
#!/bin/bash
sudo apt-get install -y apt-transport-https
sudo apt-get install -y software-properties-common wget
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
sudo apt-get update
sudo apt-get install -y grafana
sudo systemctl daemon-reload
sudo systemctl start grafana-server
sudo systemctl status grafana-server
sudo systemctl enable grafana-server.service
EOF

  tags = {
    Name = "grafana-ec2-dwh"
  }
}
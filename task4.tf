provider "aws" {
  version = "~> 2.69"
  region  = "ap-south-1"
}
resource "aws_vpc" "myawsvpc" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true

  tags = {
    Name = "my_aws_vpc"
  }
}
resource "aws_internet_gateway" "Myingw" {
  vpc_id = aws_vpc.myawsvpc.id

  tags = {
    Name = "My_in_gw"
  }
}
resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.myawsvpc.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "My_Subnet1"
  }
}
resource "aws_subnet" "private" {
    vpc_id = aws_vpc.myawsvpc.id

    cidr_block = "192.168.0.0/24"
    availability_zone = "ap-south-1b"

  tags = {
    Name = "My_Subnet2"
  }
}
resource "aws_route_table" "route_table1" {
  vpc_id = aws_vpc.myawsvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Myingw.id
  }

  tags = {
    Name = "My_routetable"
  }
}
resource "aws_route_table_association" "route_table_association1" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.route_table1.id
}
resource "aws_eip" "nat" {
  vpc      = true
  depends_on = [aws_internet_gateway.Myingw,]
  
}
resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  depends_on = [aws_internet_gateway.Myingw,]
 
 tags = {
    Name = " NAT_GW"
  }
}
resource "aws_route_table" "route_table2" {
  vpc_id = aws_vpc.myawsvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw.id
  }

  tags = {
    Name = "My_routetable_for_natgw"
  }
}

resource "aws_route_table_association" "route_table_association2" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.route_table2.id
}
resource "aws_security_group" "websecurity" {
  name        = "web_security"
  description = "Allow http,ssh,icmp"
  vpc_id      = aws_vpc.myawsvpc.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "ALL ICMP - IPv4"
    from_port   = -1    
    to_port     = -1
    protocol    = "ICMP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks =  ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "web_sg"
  }
} 
resource "aws_security_group" "Mysqlsecurity" {
  name        = "My_sql_security"
  description = "Allow Mysql"
  vpc_id      = aws_vpc.myawsvpc.id

  ingress {
    description = "MYSQL/Aurora"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = ["${aws_security_group.websecurity.id}"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks =  ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "Mysql_sg"
  }
}
resource "aws_security_group" "bastionsecurity" {
  name        = "bastion_security"
  description = "Allow ssh for bastion host"
  vpc_id      = aws_vpc.myawsvpc.id


  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks =  ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "bastion_sg"
  }
} 
resource "aws_security_group" "MysqlServersecurity" {
  name        = "My_Sql_Server_Security"
  description = "Allow mysql ssh for bastion host only"
  vpc_id      = aws_vpc.myawsvpc.id

  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = ["${aws_security_group.bastionsecurity.id}"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks =  ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "Mysqlserver_sg"
  }
}

resource "aws_instance" "wordpress" {
  ami           = "ami-000cbce3e1b899ebd"
  instance_type = "t2.micro"
  associate_public_ip_address = true
  subnet_id = aws_subnet.public.id
  vpc_security_group_ids = ["${aws_security_group.websecurity.id}"]
  key_name = "cloudclasskey"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "wordpress"
  }

}
resource "aws_instance" "Mysql" {
  ami           = "ami-08706cb5f68222d09"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.private.id
  vpc_security_group_ids = ["${aws_security_group.Mysqlsecurity.id}","${aws_security_group.MysqlServersecurity.id}"]
  key_name = "cloudclasskey"
  availability_zone = "ap-south-1b"

 tags = {
    Name = "Mysql"
  }

}
resource "aws_instance" "mybastionhost" {
  ami           = "ami-052c08d70def0ac62"
  instance_type = "t2.micro"
  associate_public_ip_address = true
  subnet_id = aws_subnet.public.id
  vpc_security_group_ids = ["${aws_security_group.bastionsecurity.id}"]
  key_name = "cloudclasskey"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "Mybastionhost"
  }
}
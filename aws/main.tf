provider "aws" {
  region = "ap-southeast-2"
}

resource "aws_vpc" "sfnet" {
  cidr_block            = "10.0.0.0/16"
  enable_dns_support    = "true"
  enable_dns_hostnames  = "true"
  tags {
    Name = "sfnet"
  }
}

resource "aws_subnet" "public" {
  vpc_id     = "${aws_vpc.sfnet.id}"
  cidr_block = "10.0.1.0/24"

  tags {
    Name = "public"
  }
}

resource "aws_subnet" "private" {
  vpc_id     = "${aws_vpc.sfnet.id}"
  cidr_block = "10.0.2.0/24"

  tags {
    Name = "private"
  }
}


resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.sfnet.id}"

  tags {
    Name = "SFNet IGW"
  }
}

resource "aws_route_table" "igw-table" {
  vpc_id = "${aws_vpc.sfnet.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }

  tags {
    Name = "igw-table"
  }
}

resource "aws_eip" "nat-ip1" {
  vpc      = true
}

resource "aws_nat_gateway" "nat1" {
  allocation_id = "${aws_eip.nat-ip1.id}"
  subnet_id = "${aws_subnet.public.id}"
}


resource "aws_route_table" "nat-table" {
  vpc_id = "${aws_vpc.sfnet.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.nat1.id}"
  }

  tags {
    Name = "nat-table"
  }
}

resource "aws_route_table_association" "igw-table-association" {
  subnet_id      = "${aws_subnet.public.id}"
  route_table_id = "${aws_route_table.igw-table.id}"
}

resource "aws_route_table_association" "nat-table-association" {
  subnet_id      = "${aws_subnet.private.id}"
  route_table_id = "${aws_route_table.nat-table.id}"
}

data "aws_ami" "ubuntu" {
    most_recent = true

    filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
    }

    filter {
        name   = "virtualization-type"
        values = ["hvm"]
    }

    owners = ["099720109477"] # Canonical
}

resource "aws_launch_configuration" "as_conf" {
  name          = "web_config"
  image_id      = "${data.aws_ami.ubuntu.id}"
  instance_type = "m5.large"
  user_data     = "${file("${path.module}/scripts/init.sh")}"
}

resource "aws_elb" "sfabric-lb" {
    availability_zones = ["ap-southeast-2a","ap-southeast-2b","ap-southeast-2c"]
    name = "sfabric-lb"
    listener {
        instance_port     = 8000
        instance_protocol = "http"
        lb_port           = 80
        lb_protocol       = "http"
    }
}
resource "aws_autoscaling_group" "bar" {
  name                 = "terraform-asg-example"
  launch_configuration = "${aws_launch_configuration.as_conf.name}"
  min_size             = 1
  max_size             = 1

  lifecycle {
    create_before_destroy = true
  }
  availability_zones = ["ap-southeast-2a","ap-southeast-2b","ap-southeast-2c"]
  load_balancers = ["${aws_elb.sfabric-lb.id}"]
  
}

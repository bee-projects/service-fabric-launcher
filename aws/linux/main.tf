provider "aws" {
  region = "ap-southeast-2"
}

variable "region" {
  default="ap-southeast-2"
}

variable "zone1" {
  default = "ap-southeast-2a"
}

variable "zone2" {
  default = "ap-southeast-2b"
}


variable "env" {
  default = "dev"
}


variable "instance_type" {
  default = "m5.large"
}
# ----------------------------------------------------------------------------------
#  Network Setup
# ----------------------------------------------------------------------------------

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

  availability_zone="${var.zone1}"

  tags {
    Name = "public"
  }
}

resource "aws_subnet" "private" {
  vpc_id     = "${aws_vpc.sfnet.id}"
  availability_zone="${var.zone1}"
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


resource "aws_security_group" "nlb-sg" {
  name        = "nlb-sg"
  description = "Allow inbound HTTP/HTTPS traffic"
  vpc_id      = "${aws_vpc.sfnet.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "sfnode-sg" {
  name        = "sfnode-sg"
  description = "Allow inbound HTTP/HTTPS traffic"
  vpc_id      = "${aws_vpc.sfnet.id}"

  ingress {
    security_groups = ["${aws_security_group.nlb-sg.id}"]
    from_port  = 19080
    to_port     = 19080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    security_groups = ["${aws_security_group.bastion-sg.id}"]
    from_port  = 22
    to_port     = 22
    protocol    = "tcp"
  }

  ingress {
      security_groups = ["${aws_security_group.nlb-sg.id}"]
      from_port  = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "bastion-sg" {
  name        = "bastion-sg"
  description = "Allow SSh to bastion"
  vpc_id      = "${aws_vpc.sfnet.id}"

  ingress {
    from_port  = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
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
  instance_type = "${var.instance_type}"
  user_data     = "${file("${path.module}/scripts/init.sh")}"
  root_block_device {
      volume_size = 100
  }
  security_groups = ["${aws_security_group.sfnode-sg.id}"]
  key_name = "${aws_key_pair.ssh-key.id}"
  
 
}

# ----------------------------------------------------------------------------------
# Starting resources
# ----------------------------------------------------------------------------------

resource "aws_lb" "sfabric-lb" {
  name               = "sfabric-lb"
  internal           = false
  load_balancer_type = "network"
  subnets            = ["${aws_subnet.public.id}"]

  enable_deletion_protection = false
  enable_cross_zone_load_balancing = true
  
  tags {
    Environment = "${var.env}"
  }
}

resource "aws_lb_target_group" "sfnode-tg" {
  name     = "sfnode-tg"
  port     = 19080
  protocol = "TCP"
  vpc_id   = "${aws_vpc.sfnet.id}"
  stickiness {
    type = "lb_cookie"
    enabled = false
  }
}


resource "aws_lb_listener" "sfnode-listener" {
  load_balancer_arn = "${aws_lb.sfabric-lb.arn}"
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.sfnode-tg.arn}"
  }
}


resource "aws_autoscaling_group" "sfnode-asg" {
  name                 = "sfnode-asg"
  launch_configuration = "${aws_launch_configuration.as_conf.name}"
  min_size             = 1
  max_size             = 1

  lifecycle {
    create_before_destroy = true
  }
  availability_zones = ["ap-southeast-2a","ap-southeast-2b","ap-southeast-2c"]
  vpc_zone_identifier = ["${aws_subnet.private.id}"]
  target_group_arns  = ["${aws_lb_target_group.sfnode-tg.arn}"]

  tag {
    key                 = "Name"
    value               = "sfnode"
    propagate_at_launch = true
  }
}


resource "aws_instance" "bastion" {
  subnet_id = "${aws_subnet.public.id}"
  vpc_security_group_ids = ["${aws_security_group.bastion-sg.id}"]
  associate_public_ip_address = true
  ami           = "${data.aws_ami.ubuntu.id}"
  instance_type = "t2.micro"
  key_name = "${aws_key_pair.ssh-key.id}"
  tags {
    Name = "bastion"
  }
}

resource "aws_key_pair" "ssh-key" {
  key_name   = "ssh-key"
  public_key = "${file("~/.ssh/id_rsa.pub")}"
}
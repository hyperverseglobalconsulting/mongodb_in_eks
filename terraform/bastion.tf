resource "aws_iam_access_key" "user_key" {
  user = var.aws_user
}

resource aws_vpc "k8s" {
    cidr_block = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "mongodb-on-eks"
  }
}

resource "aws_internet_gateway" "bastion" {
    vpc_id      = aws_vpc.k8s.id

#    depends_on = [aws_instance.bastion]
}

resource "aws_subnet" "public" {
  for_each = {
    for index, availability_zone in var.availability_zones :
    "subnet${index + 1}" => {
      availability_zone = availability_zone
      cidr_block        = var.cidr_blocks[index]
    }
  }

  vpc_id                  = aws_vpc.k8s.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "${each.key}-public-subnet"
  }
}

resource "aws_route_table" "public" {
    vpc_id  = aws_vpc.k8s.id
    route {
        cidr_block  = "0.0.0.0/0"
        gateway_id  = aws_internet_gateway.bastion.id
    }
}

resource "aws_route_table_association" "public_route_table_assoc" {
  for_each      = { for idx, subnet in aws_subnet.public : idx => subnet.id }
  subnet_id     = each.value
  route_table_id = aws_route_table.public.id
}

data "aws_ami" "amazon_2" {
    most_recent = true
    filter {
        name    = "name"
        values  = ["amzn2-ami-kernel-*-hvm-*-x86_64-gp2"]
    }
    owners  = ["amazon"]
}

resource "aws_security_group" "sg" {
    vpc_id      = aws_vpc.k8s.id
    name        = "public_subnet"
    description = "Connect Public Subnet"

    ingress {
        cidr_blocks = ["${var.demo_server_ip}/32"]
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "tls_private_key" "pk" {
    algorithm = "RSA"
    rsa_bits  = 4096
}

resource "aws_s3_object" "file" {
    key     = var.key_name
    bucket  = var.bucket_name
    content = tls_private_key.pk.private_key_pem
}

resource "aws_key_pair" "kp" {
    key_name   = trimsuffix("${var.key_name}", ".pem")
    public_key = tls_private_key.pk.public_key_openssh
}

resource "local_file" "private_key" {
  content  = tls_private_key.pk.private_key_pem
  filename = "${path.module}/${var.key_name}"
}

resource "null_resource" "change_key_permissions" {
  depends_on = [local_file.private_key]

  provisioner "local-exec" {
    command = "sudo chmod 400 ${path.module}/${var.key_name} && sleep 10"
  }
}

locals {
  # Choose an arbitrary host number of 4 in the first subnet.
  server_ip = cidrhost(var.cidr_blocks[0], 4)

  script_path = "install_tools.sh"
}

resource "null_resource" "eks_dependency" {
  depends_on = [aws_eks_cluster.cluster]
  triggers = {
    cluster_arn = aws_eks_cluster.cluster.arn
  }
}

resource "aws_instance" "bastion" {
    vpc_security_group_ids  = ["${aws_security_group.sg.id}"]
    subnet_id               = values(aws_subnet.public)[0].id
    ami                     = data.aws_ami.amazon_2.id
    instance_type           = "t3.micro"
    key_name                = trimsuffix("${var.key_name}", ".pem")
    private_ip              = local.server_ip
#    user_data = base64encode(file("${path.module}/ssm-agent-install.sh"))
    connection {
        type        = "ssh"
        user        = "ec2-user"
        host        = "${aws_instance.bastion.public_ip}"
        private_key = "${aws_s3_object.file.content}"
        timeout     = "1m"
    }

    provisioner "file" {
        source      = "${path.module}/${var.key_name}"
        destination = "/home/ec2-user/${var.key_name}"
    }

    provisioner "file" {
      source      = local.script_path
      destination = "${path.module}/${local.script_path}"
    }

    provisioner "remote-exec" {
      inline = [
        "chmod +x ${path.module}/${local.script_path}",
        "sudo yum update -y",
#        "${path.module}/${local.script_path} ${var.aws_region} ${aws_eks_cluster.cluster.arn} ${aws_iam_access_key.user_key.id} ${aws_iam_access_key.user_key.secret}"
        "${path.module}/${local.script_path} ${var.aws_region} ${aws_eks_cluster.cluster.arn} ${var.aws_access_key} ${var.aws_secret_key}"
      ]
    }

    tags = {
        Name = "${var.server_name}"
    }

  depends_on = [
        null_resource.change_key_permissions,
        aws_subnet.public,
        null_resource.eks_dependency
  ]
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
  description = "The public IP of the bastion host"
}


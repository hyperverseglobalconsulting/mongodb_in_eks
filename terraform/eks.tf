data "aws_instance" "bastian_instance" {
  provider = aws.us_east_1
  filter {
    name   = "ip-address"
    values = [var.bastion_host_ip]
  }

  filter {
    name   = "tag:Name"
    values = [var.bastian_name_tag]
  }
}

data "aws_network_interface" "bastian_instance_network_interface" {
  provider = aws.us_east_1
  filter {
    name   = "attachment.instance-id"
    values = [data.aws_instance.bastian_instance.id]
  }
}

resource "aws_security_group" "eks_cluster_security_group" {
  name        = "${local.cluster_name}-eks-cluster-sg"
  description = "EKS cluster security group"
  vpc_id      = data.aws_network_interface.bastian_instance_network_interface.vpc_id

  tags = {
    Terraform = "true"
    Cluster   = local.cluster_name
  }
}

resource "aws_security_group_rule" "eks_cluster_sg_rule" {
  security_group_id = aws_security_group.eks_cluster_security_group.id

  type        = "ingress"
  from_port   = 0
  to_port     = 65535
  protocol    = "tcp"
#  cidr_blocks = []

  source_security_group_id = element(tolist(data.aws_instance.bastian_instance.vpc_security_group_ids), 0)
}

#resource "aws_security_group_rule" "eks_cluster_sg_rule" {
#  security_group_id = aws_security_group.eks_cluster_security_group.id
#
#  type        = "ingress"
#  from_port   = 0
#  to_port     = 0
#  protocol    = "tcp"
#  cidr_blocks = []
#
#  source_security_group_id = element(data.aws_instance.bastian_instance.vpc_security_group_ids, 0)
#}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "17.1.0"

  cluster_name = local.cluster_name
  subnets      = module.vpc.private_subnets
  cluster_version = var.cluster_version

  tags = {
    Terraform = "true"
    Cluster   = local.cluster_name
  }

  vpc_id      = data.aws_network_interface.bastian_instance_network_interface.vpc_id

  node_groups_defaults = {
    ami_type  = "AL2_x86_64"
  }

  node_groups = {
    managed-worker-group = {
      desired_capacity = var.desired_capacity
      max_capacity     = var.max_capacity
      min_capacity     = var.min_capacity
      instance_types   = [var.instance_type]
    }
  }

  cluster_security_group_id = aws_security_group.eks_cluster_security_group.id
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane."
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS control plane."
  value       = module.eks.cluster_security_group_id
}

output "cluster_id" {
  description = "EKS cluster ID."
  value       = module.eks.cluster_id
}


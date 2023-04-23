variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
  default     = "eksmongodb"
}

variable "min_capacity" {
  description = "The minimum capacity of the EKS cluster"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "The maximum capacity of the EKS cluster"
  type        = number
  default     = 1
}

variable "desired_capacity" {
  description = "The desired capacity of the EKS cluster"
  type        = number
  default     = 1
}

variable "instance_type" {
  description = "The instance type for the worker nodes"
  type        = string
  default     = "t3.nano"
}

variable "bastion_host_ip" {
  description = "The IP address of the bastion host"
  type        = string
  default     = "34.200.74.130"
}

variable "bastion_security_group" {
  description = "The security group for the bastion host"
  type        = string
  default     = "sg-0a4941fa2e2c3fbed"
}

variable "bastian_name_tag" {
  description = "The value of the 'Name' tag for the bastion host"
  type        = string
  default     = "demo_server"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16" # Replace with your desired CIDR block
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks for the public subnets"
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks for the private subnets"
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "enable_nat_gateway" {
  type        = bool
  description = "Enable NAT gateway"
  default     = true
}

variable "single_nat_gateway" {
  type        = bool
  description = "Enable single NAT gateway"
  default     = true
}

variable "enable_dns_hostnames" {
  type        = bool
  description = "Enable DNS hostnames"
  default     = true
}

variable "cluster_version" {
  type        = string
  description = "The Kubernetes version to use for the EKS cluster"
  default     = "1.21"
}

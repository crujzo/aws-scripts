variable "region" {
  description = "AWS region"
  type        = string
}

variable "name" {
  description = "Name prefix"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR (e.g. 10.13.0.0/16)"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID for NAT instance"
  type        = string
}

variable "private_route_table_id" {
  description = "Route table ID of private subnet"
  type        = string
}

variable "instance_type" {
  description = "NAT instance type"
  type        = string
  default     = "t4g.nano"
}

variable "iam_instance_profile" {
  description = "IAM instance profile name (SSM recommended)"
  type        = string
}

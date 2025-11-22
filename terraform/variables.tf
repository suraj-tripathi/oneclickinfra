variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "owner" {
  description = "Owner tag"
  type        = string
  default     = "suraj"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "bastion_subnet_cidr" {
  type        = string
  default     = "10.0.1.0/24"
}

variable "valkey_master_subnet_cidr" {
  type        = string
  default     = "10.0.2.0/24"
}

variable "valkey_replica_subnet_cidr" {
  type        = string
  default     = "10.0.3.0/24"
}

variable "instance_type_bastion" {
  type        = string
  default     = "t3.micro"
}

variable "instance_type_valkey" {
  type        = string
  default     = "t3.micro"
}

variable "s3_bucket_name" {
  description = "S3 bucket for demo (must be globally unique!)"
  type        = string
  default     = "suraj-valkey-demo-bucket-19"
}

variable "key_name" {
  description = "Name for AWS key pair"
  type        = string
  default     = "valkey-demo-key"
}

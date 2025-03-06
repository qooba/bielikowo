variable "region" {
  description = "AWS Region"
  type        = string
  default     = "eu-north-1"
}

variable "key_name" {
  description = "SSH Key Name for EC2"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type with GPU"
  type        = string
  default     = "g4dn.xlarge"
}

variable "ami_id" {
  description = "Ubuntu 22.04 AMI ID for the selected region"
  type        = string
}

variable "spot_price" {
  description = "Maximum spot instance price"
  type        = string
  default     = "0.15"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for Subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "ebs_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 50
}

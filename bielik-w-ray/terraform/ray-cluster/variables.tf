variable "location" {
  type        = string
  description = "The location where all resources will be created."
}

variable "resource_group_name" {
  type        = string
  description = "The name of the resource group."
}

variable "tags" {
  type = any
}

variable "jupyter_password" {
  description = "The password for Jupyter Lab"
  type        = string
  sensitive   = true
}

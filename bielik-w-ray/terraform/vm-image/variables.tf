variable "location" {
  type        = string
  description = "The location where all resources will be created."
}

variable "resource_group_name" {
  type        = string
  description = "The name of the resource group."
}

variable "managed_disk_id" {
  type        = string
  description = "The ID of the managed disk to create a snapshot from."
}

variable "tags" {
  type = any
}

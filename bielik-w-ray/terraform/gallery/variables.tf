variable "location" {
  type        = string
  description = "The location where all resources will be created."
}

variable "resource_group_name" {
  type        = string
  description = "The name of the resource group."
}

variable "managed_image_id" {
  type        = string
  description = "The ID of the managed image."
}

variable "tags" {
  type = any
}

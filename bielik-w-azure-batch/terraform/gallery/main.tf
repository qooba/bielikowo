terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.resource_group_name}_GALLERY"
  location = var.location
}

resource "azurerm_shared_image_gallery" "gallery" {
  name                = "bielikGallery"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

resource "azurerm_shared_image" "shared_image" {
  name                = "bielik-vm-image"
  gallery_name        = azurerm_shared_image_gallery.gallery.name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"

  identifier {
    publisher = "bielik"
    offer     = "customImage"
    sku       = "1.0"
  }
}

resource "azurerm_shared_image_version" "image_version" {
  name                = "1.0.0"
  gallery_name        = azurerm_shared_image_gallery.gallery.name
  image_name         = azurerm_shared_image.shared_image.name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  target_region {
    name                   = azurerm_resource_group.rg.location
    regional_replica_count = 1
  }

  managed_image_id = var.managed_image_id
}

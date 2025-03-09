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
  name     = "${var.resource_group_name}_BATCH"
  location = var.location
}

data "azurerm_shared_image" "shared_image" {
  name                = "bielik-vm-image"
  gallery_name        = "bielikGallery"
  resource_group_name = "${var.resource_group_name}_GALLERY"
}

resource "azurerm_batch_account" "batch" {
  name                = "bielikbatchaccount"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  pool_allocation_mode = "BatchService"
}


resource "azurerm_batch_pool" "batch_pool" {
  name                = "bielik-batch-pool"
  display_name        = "Bielik Batch Pool"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_batch_account.batch.name
  vm_size             = "Standard_NC4as_T4_v3"  # T4 GPU Spot
  node_agent_sku_id   = "batch.node.ubuntu 22.04"

  storage_image_reference {
    id = data.azurerm_shared_image.shared_image.id
  }

  auto_scale {
    formula = <<EOF
      startingNumberOfVMs = 0;
      minNumberOfVMs = 0;
      maxNumberOfVMs = 1;
      $TargetDedicatedNodes = 0;
      $TargetLowPriorityNodes = (pendingTasks > 0) ? 1 : 0;
    EOF
    evaluation_interval = "PT5M"
  }
}

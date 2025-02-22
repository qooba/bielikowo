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

resource "azurerm_resource_group" "rg_vm" {
  name     = "${var.resource_group_name}_VM"
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "bielikVNet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg_vm.location
  resource_group_name = azurerm_resource_group.rg_vm.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "bielikSubnet"
  resource_group_name  = azurerm_resource_group.rg_vm.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "bielikNSG"
  location            = azurerm_resource_group.rg_vm.location
  resource_group_name = azurerm_resource_group.rg_vm.name
}

resource "azurerm_network_security_rule" "nsr" {
  name                        = "SSH"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg_vm.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

# Network Interface and Public IP for VM1
resource "azurerm_public_ip" "public_ip1" {
  name                = "bielikPublicIP1"
  location            = azurerm_resource_group.rg_vm.location
  resource_group_name = azurerm_resource_group.rg_vm.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "nic1" {
  name                = "bielikNIC1"
  location            = azurerm_resource_group.rg_vm.location
  resource_group_name = azurerm_resource_group.rg_vm.name

  ip_configuration {
    name                          = "myNICConfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip1.id
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_assoc" {
  network_interface_id      = azurerm_network_interface.nic1.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_linux_virtual_machine" "vm1" {
  name                = "bielikVM1"
  resource_group_name = azurerm_resource_group.rg_vm.name
  location            = azurerm_resource_group.rg_vm.location
  size                = "Standard_NC4as_T4_v3"
  admin_username      = "bielik"
  network_interface_ids = [
    azurerm_network_interface.nic1.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  computer_name                   = "bielik-gpu-spot-1"
  admin_ssh_key {
    username   = "bielik"
    public_key = file("./ssh/id_rsa.pub")
  }

  priority = "Spot"
  eviction_policy = "Deallocate"
}


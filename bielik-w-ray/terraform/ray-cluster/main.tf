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

resource "azurerm_resource_group" "ray_cluster" {
  name     = "${var.resource_group_name}_RAY"
  location = var.location
}

data "azurerm_shared_image" "shared_image" {
  name                = "bielik-vm-image-py"
  gallery_name        = "bielikGalleryPy"
  resource_group_name = "${var.resource_group_name}_GALLERY_PY"
}

resource "azurerm_virtual_network" "ray_vnet" {
  name                = "ray-vnet"
  location            = azurerm_resource_group.ray_cluster.location
  resource_group_name = azurerm_resource_group.ray_cluster.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "ray_subnet" {
  name                 = "ray-subnet"
  resource_group_name  = azurerm_resource_group.ray_cluster.name
  virtual_network_name = azurerm_virtual_network.ray_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "ray_head_ip" {
  name                = "ray-head-ip"
  location            = azurerm_resource_group.ray_cluster.location
  resource_group_name = azurerm_resource_group.ray_cluster.name
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "ray_head_nic" {
  name                = "ray-head-nic"
  location            = azurerm_resource_group.ray_cluster.location
  resource_group_name = azurerm_resource_group.ray_cluster.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.ray_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ray_head_ip.id
  }
}

resource "azurerm_linux_virtual_machine" "ray_head" {
  name                  = "ray-head-vm"
  location              = azurerm_resource_group.ray_cluster.location
  resource_group_name   = azurerm_resource_group.ray_cluster.name
  size                  = "Standard_D2s_v5"
  priority              = "Spot"
  eviction_policy       = "Deallocate"
  admin_username        = "bielik"
  network_interface_ids = [azurerm_network_interface.ray_head_nic.id]

  custom_data = base64encode(<<-EOT
    #!/bin/bash
    apt update && apt install -y python3-pip
    pip3 install ray[default] polars azure-storage-blob deltalake jupyterlab

    echo "Creating Ray Head Node systemd service..."
    cat <<EOF | tee /etc/systemd/system/ray-head.service
    [Unit]
    Description=Ray Head Node
    After=network.target

    [Service]
    User=bielik
    ExecStart=/usr/local/bin/ray start --block --head --port=6379 --dashboard-port=8265
    Restart=always
    RestartSec=10

    [Install]
    WantedBy=multi-user.target
    EOF

    echo "Enabling and starting Ray Head Node service..."
    systemctl daemon-reload
    systemctl enable ray-head
    systemctl start ray-head
    
    JUPYTER_PASS_HASH=$(python3 -c "from jupyter_server.auth import passwd; print(passwd('${var.jupyter_password}'))")
    mkdir -p /home/bielik/.jupyter

    echo "Configuring Jupyter..."
    cat <<EOF > /home/bielik/.jupyter/jupyter_lab_config.py
    c.ServerApp.ip = '0.0.0.0'
    c.ServerApp.port = 8888
    c.ServerApp.password = '$JUPYTER_PASS_HASH'
    c.ServerApp.open_browser = False
    c.ServerApp.allow_root = True
    c.ServerApp.notebook_dir = '/home/bielik'
    EOF

    echo "Creating systemd service for Jupyter..."
    cat <<EOF | tee /etc/systemd/system/jupyter.service
    [Unit]
    Description=Jupyter Lab
    After=network.target

    [Service]
    User=bielik
    WorkingDirectory=/home/bielik
    ExecStart=/usr/local/bin/jupyter lab --config=/home/bielik/.jupyter/jupyter_lab_config.py
    Restart=always

    [Install]
    WantedBy=multi-user.target
    EOF

    echo "Enabling and starting Jupyter service..."
    systemctl daemon-reload
    systemctl enable jupyter
    systemctl start jupyter

    echo "Jupyter Lab setup complete!"
    chown -R bielik /tmp/ray/
  EOT
  )

  admin_ssh_key {
    username   = "bielik"
    public_key = file("./ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }


}

resource "azurerm_linux_virtual_machine_scale_set" "ray_workers" {
  name                = "ray-worker-vmss"
  location            = azurerm_resource_group.ray_cluster.location
  resource_group_name = azurerm_resource_group.ray_cluster.name
  sku                 = "Standard_NC4as_T4_v3"
  instances           = 2
  priority            = "Spot"
  eviction_policy     = "Deallocate"

  admin_username = "bielik"
  admin_ssh_key {
    username   = "bielik"
    public_key = file("./ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  network_interface {
    name    = "ray-worker-nic"
    primary = true

    ip_configuration {
      name      = "internal"
      subnet_id = azurerm_subnet.ray_subnet.id
    }
  }

  source_image_id = data.azurerm_shared_image.shared_image.id

  custom_data = base64encode(<<-EOT
    #!/bin/bash
    apt update && apt install -y python3-pip
    pip3 install ray[default] polars

    wget https://github.com/qooba/bielikowo/raw/refs/heads/main/packages/mistralrs-0.4.0-cp38-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl
    pip3 install mistralrs-0.4.0-cp38-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl

    # Get Head Node Private IP
    HEAD_IP="${azurerm_network_interface.ray_head_nic.private_ip_address}"

    echo "Waiting for Head Node to be ready..."
    until nc -z $HEAD_IP 6379; do
        echo "Head Node not ready, retrying in 5 seconds..."
        sleep 5
    done

    echo "Creating Ray Worker systemd service..."
    cat <<EOF | tee /etc/systemd/system/ray-worker.service
    [Unit]
    Description=Ray Worker Node
    After=network.target

    [Service]
    User=bielik
    Environment=HEAD_IP=${azurerm_network_interface.ray_head_nic.private_ip_address}
    ExecStart=/usr/local/bin/ray start --block --address=${azurerm_network_interface.ray_head_nic.private_ip_address}:6379
    Restart=always
    RestartSec=10

    [Install]
    WantedBy=multi-user.target
    EOF

    echo "Enabling and starting Ray Worker service..."
    systemctl daemon-reload
    systemctl enable ray-worker
    systemctl start ray-worker

  EOT
  )

  depends_on = [ azurerm_linux_virtual_machine.ray_head ]
}

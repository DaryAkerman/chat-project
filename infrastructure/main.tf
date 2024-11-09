provider "azurerm" {
  features {}
  subscription_id = "cbc417fc-e212-427f-b724-5cadb92ffe07"
}

# Define Resource Group
resource "azurerm_resource_group" "chat_app_rg" {
  name     = "chat-app-rg"
  location = "West Europe"
}

# Define Virtual Network
resource "azurerm_virtual_network" "chat_vnet" {
  name                = "chat-vnet"
  location            = azurerm_resource_group.chat_app_rg.location
  resource_group_name = azurerm_resource_group.chat_app_rg.name
  address_space       = ["10.0.0.0/16"]
}

# Define Subnet
resource "azurerm_subnet" "chat_subnet" {
  name                 = "chat-subnet"
  resource_group_name  = azurerm_resource_group.chat_app_rg.name
  virtual_network_name = azurerm_virtual_network.chat_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Public IP
resource "azurerm_public_ip" "chat_app_public_ip" {
  name                = "chat-app-public-ip"
  location            = azurerm_resource_group.chat_app_rg.location
  resource_group_name = azurerm_resource_group.chat_app_rg.name
  allocation_method   = "Static"
}

# Network Interface
resource "azurerm_network_interface" "chat_app_nic" {
  name                = "chat-app-nic"
  location            = azurerm_resource_group.chat_app_rg.location
  resource_group_name = azurerm_resource_group.chat_app_rg.name
  ip_configuration {
    name                          = "chat-app-ip-configuration"
    subnet_id                     = azurerm_subnet.chat_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.chat_app_public_ip.id
  }
}

# Security Group to Allow HTTP, Flask Port, and SSH
resource "azurerm_network_security_group" "chat_app_nsg" {
  name                = "chat-app-nsg"
  location            = azurerm_resource_group.chat_app_rg.location
  resource_group_name = azurerm_resource_group.chat_app_rg.name

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowFlaskPort"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # SSH rule
  security_rule {
    name                       = "AllowSSH"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}


# Associate NSG with Network Interface
resource "azurerm_network_interface_security_group_association" "nsg_association" {
  network_interface_id      = azurerm_network_interface.chat_app_nic.id
  network_security_group_id = azurerm_network_security_group.chat_app_nsg.id
}

# Virtual Machine
resource "azurerm_linux_virtual_machine" "chat_app_vm" {
  name                = "chat-app-vm"
  resource_group_name = azurerm_resource_group.chat_app_rg.name
  location            = azurerm_resource_group.chat_app_rg.location
  size                = "Standard_B1s"
  admin_username      = "azureuser"
  admin_password      = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.chat_app_nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  custom_data = base64encode(<<-EOF
                #!/bin/bash
                sudo apt-get update
                sudo apt-get install -y python3-pip docker.io
                sudo systemctl start docker
                sudo systemctl enable docker
                sudo docker pull winterzone2/chat-project:v1
                sudo docker run -d -p 5000:5000 winterzone2/chat-project:v4
                EOF
  )
}

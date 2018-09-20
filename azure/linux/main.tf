provider "azurerm" { }

variable "region" {
  default = "AustraliaEast"
}

variable "resource_group_name" {
  default = "sfabric-rg"
}

variable "vnet_name" {
  default = "sfabric-net"
}

resource "azurerm_resource_group" "sfabric-rg" {
  name     = "${var.resource_group_name}"
  location = "${var.region}"
}

resource "azurerm_virtual_network" "sfabric-net" {
  name                = "${var.vnet_name}"
  address_space       = ["10.0.0.0/16"]
  location            = "${azurerm_resource_group.sfabric-rg.location}"
  resource_group_name = "${azurerm_resource_group.sfabric-rg.name}"
}

resource "azurerm_subnet" "subnet1" {
  name                 = "subnet1"
  resource_group_name  = "${azurerm_resource_group.sfabric-rg.name}"
  virtual_network_name = "${azurerm_virtual_network.sfabric-net.name}"
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_public_ip" "sfabric-ip" {
  name                         = "sfabric-ip"
  location            = "${azurerm_resource_group.sfabric-rg.location}"
  resource_group_name = "${azurerm_resource_group.sfabric-rg.name}"
  public_ip_address_allocation = "static"
  domain_name_label            = "${azurerm_resource_group.sfabric-rg.name}"

  tags {
    environment = "dev"
  }
}

resource "azurerm_lb" "sfabric-lb" {
  name                = "sfabric-lb"
  location            = "${azurerm_resource_group.sfabric-rg.location}"
  resource_group_name = "${azurerm_resource_group.sfabric-rg.name}"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = "${azurerm_public_ip.sfabric-ip.id}"
  }
}

resource "azurerm_lb_probe" "web" {
  resource_group_name = "${azurerm_resource_group.sfabric-rg.name}"
  loadbalancer_id     = "${azurerm_lb.sfabric-lb.id}"
  name                = "web"
  protocol            = "tcp"
  port                = "19080"
}

resource "azurerm_lb_rule" "web" {
  resource_group_name            = "${azurerm_resource_group.sfabric-rg.name}"
  loadbalancer_id                = "${azurerm_lb.sfabric-lb.id}"
  name                           = "web"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 19080
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.backend.id}"
  probe_id                       = "${azurerm_lb_probe.web.id}"
}


resource "azurerm_lb_backend_address_pool" "backend" {
  resource_group_name = "${azurerm_resource_group.sfabric-rg.name}"
  loadbalancer_id     = "${azurerm_lb.sfabric-lb.id}"
  name                = "backend"
}

resource "azurerm_lb_nat_pool" "lbnatpool" {
  count                          = 3
  resource_group_name            = "${azurerm_resource_group.sfabric-rg.name}"
  name                           = "ssh"
  loadbalancer_id                = "${azurerm_lb.sfabric-lb.id}"
  protocol                       = "Tcp"
  frontend_port_start            = 50000
  frontend_port_end              = 50119
  backend_port                   = 22
  frontend_ip_configuration_name = "PublicIPAddress"
}

resource "azurerm_virtual_machine_scale_set" "sfabric-ss" {
  name                = "sfabric-ss"
  location            = "${azurerm_resource_group.sfabric-rg.location}"
  resource_group_name = "${azurerm_resource_group.sfabric-rg.name}"
  upgrade_policy_mode = "Manual"

  sku {
    name     = "Standard_D2s_v3"
    tier     = "Standard"
    capacity = 1
  }

  storage_profile_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_profile_data_disk {
    lun            = 0
    caching        = "ReadWrite"
    create_option  = "Empty"
    disk_size_gb   = 10
  }

  os_profile {
    computer_name_prefix = "sfnode"
    admin_username       = "azureuser"
    admin_password       = "P@ssw0rd!@#"
    custom_data          = "${file("${path.module}/scripts/init.sh")}"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/azureuser/.ssh/authorized_keys"
      key_data = "${file("~/.ssh/id_rsa.pub")}"
    }

    
  }

  network_profile {
    name    = "sfnetworkprofile"
    primary = true

    ip_configuration {
      name                                   = "DevIPConfiguration"
      subnet_id                              = "${azurerm_subnet.subnet1.id}"
      load_balancer_backend_address_pool_ids = ["${azurerm_lb_backend_address_pool.backend.id}"]
      load_balancer_inbound_nat_rules_ids    = ["${element(azurerm_lb_nat_pool.lbnatpool.*.id, count.index)}"]
    }
  }

  tags {
    environment = "dev"
  }

  
}
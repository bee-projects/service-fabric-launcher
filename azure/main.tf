provider "azurerm" {

}

variable "resource_group_name" {
  default = "terraform-vmss-cloudinit"
}

variable "location" {
  default = "eastus"
}

module "network" {
    source              = "Azure/network/azurerm"
    location            = "${var.location}"
    resource_group_name = "${var.resource_group_name}"
    allow_rdp_traffic   = "true"
    allow_ssh_traffic   = "true"  
}


module "loadbalancer" {
  source              = "Azure/loadbalancer/azurerm"
  resource_group_name = "${var.resource_group_name}"
  location            = "${var.location}"
  prefix              = "terraform-test"

  "remote_port" {
    ssh = ["Tcp", "22"]
  }

  "lb_port" {
    http = ["80", "Tcp", "80"]
  }
}

module "vmss-cloudinit" {
  source                                 = "Azure/vmss-cloudinit/azurerm"
  resource_group_name                    = "${var.resource_group_name}"
  cloudconfig_file                       = "${path.module}/cloudconfig.tpl"
  location                               = "${var.location}"
  vm_size                                = "Standard_DS2_v2"
  admin_username                         = "azureuser"
  admin_password                         = "ComplexPassword"
  ssh_key                                = "~/.ssh/id_rsa.pub"
  nb_instance                            = 2
  vm_os_simple                           = "UbuntuServer"
  vnet_subnet_id                         = "${module.network.vnet_subnets[0]}"
  load_balancer_backend_address_pool_ids = "${module.loadbalancer.azurerm_lb_backend_address_pool_id}"
  
}

output "vmss_id" {
  value = "${module.vmss-cloudinit.vmss_id}"
}
provider "google" {
    
}


data "template_file" "init-script" {
  template = "${file("scripts/init.sh")}"
  vars {
    PROXY_PATH = ""
  }
}

module "mig1" {
  source            = "GoogleCloudPlatform/managed-instance-group/google"
  version           = "1.1.13"
  region            = "australia-southeast1"
  zone              = "australia-southeast1-a"
  name              = "group1"
  size              = 1
  service_port      = 80
  service_port_name = "http"
  target_tags       = ["allow-service1"]
  startup_script    = "${data.template_file.init-script.rendered}"
}


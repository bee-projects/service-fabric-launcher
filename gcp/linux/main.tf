provider "google" {
    
}


data "template_file" "init" {
  template = "${file("script.sh")}"
}
# Create a new instance
resource "google_compute_instance" "myvm" {
   name = "myvm"
   machine_type = "n1-standard-2"
   zone = "australia-southeast1-a"
    boot_disk {
        initialize_params {
            image = "ubuntu-1604-lts"
            size = 100
        }
    }
    network_interface {
        network = "default"
        access_config {
            network_tier = "PREMIUM"
        }
    }

    metadata_startup_script = "${data.template_file.init.rendered}"

}

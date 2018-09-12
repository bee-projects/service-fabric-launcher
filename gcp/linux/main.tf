provider "google" {
    
}

resource "google_compute_network" "sfnet" {
  name                    = "sfnet"
  auto_create_subnetworks = "true"
}

data "template_file" "init-script" {
  template = "${file("${path.module}/scripts/init.sh")}"
}

resource "google_compute_instance_template" "sftemplate" {
    name                  = "default"
    instance_description  = "Service Fabric Nodes"
    machine_type          = "n1-standard-2"
    metadata_startup_script = "${data.template_file.init-script.rendered}"
    can_ip_forward        = false
    network_interface     {
        network = "sfnet"
    }
    disk {
        source_image        = "ubuntu-1604-lts"
        disk_size_gb        = 100
    }
 
}

resource "google_compute_health_check" "autohealing" {
    name                = "autohealing-health-check"
    check_interval_sec  = 5
    timeout_sec         = 5
    healthy_threshold   = 2
    unhealthy_threshold = 10                         

    http_health_check {
        request_path = "/"
        port         = "19080"
    }
}

resource "google_compute_instance_group_manager" "instance_group_manager" {
    depends_on            = ["google_compute_network.sfnet"]
    name               = "sfabric-igm"
    instance_template  = "${google_compute_instance_template.sftemplate.self_link}"
    base_instance_name = "sfabric"
    zone               = "australia-southeast1-a"
    target_size        = "1"

    named_port {
        name = "https"
        port = "443"
    }

    named_port {
        name = "sfabric"
        port = "19080"
    }  

  auto_healing_policies {
    health_check      = "${google_compute_health_check.autohealing.self_link}"
    initial_delay_sec = 300
  }
}


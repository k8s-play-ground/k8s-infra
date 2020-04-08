
resource "google_compute_http_health_check" "k8s-api-server-health-check" {
  name               = "paas-sbx-api-server-health-check"
  request_path       = "/healthz"
  check_interval_sec = 1
  timeout_sec        = 1
  host               = "paas-sbx.default.svc.cluster.local"
  port               = 8081

}
resource "google_compute_target_pool" "paas-sbx-api-server" {
  name = "paas-sbx-api"

  instances = [
    "asia-south1-a/paas-sbx-controller-0",
    "asia-south1-a/paas-sbx-controller-1",
    "asia-south1-a/paas-sbx-controller-2",
    
  ]

  health_checks = [
    google_compute_http_health_check.k8s-api-server-health-check.self_link
  ]
}


resource "google_compute_forwarding_rule" "k8s-api-server-lb" {
  name       = "paas-sbx-api-server-lb"
  target     = "${google_compute_target_pool.paas-sbx-api-server.self_link}"
  port_range = "6443"
  ip_address = "${google_compute_address.paas-external-ip.address}"
}

resource "google_compute_firewall" "paas-external" {
  name    = "paas-sbx-external"
  network = google_compute_network.paas_vpc_network.self_link

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22", "6443", "443", "80"]

  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "paas-api-health-check" {
  name    = "paas-sbx-api-health-check"
  network = google_compute_network.paas_vpc_network.self_link

  allow {
    protocol = "tcp"
  }
  source_ranges = ["209.85.204.0/22","209.85.152.0/22","35.191.0.0/16"]

}

resource "google_compute_firewall" "paas-internal" {
  name    = "paas-sbx-internal"
  network = google_compute_network.paas_vpc_network.self_link

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  source_ranges = ["10.250.0.0/24","10.100.0.0/16"]
}

resource "google_compute_subnetwork" "paas_subnet" {
  name          = "paas-sbx-subnet"
  ip_cidr_range = "10.250.0.0/24"
  network       = google_compute_network.paas_vpc_network.self_link
}

resource "google_compute_network" "paas_vpc_network" {
  name = "paas-sbx-k8s"
  auto_create_subnetworks = false
}

resource "google_compute_address" "paas-external-ip" {
  name = "paas-sbx-external-ip"
}

resource "google_compute_address" "controller_internal_address" {
  count        = "${var.master_count}"
  name         = "controller-${count.index}-internal-address"
  subnetwork   = google_compute_subnetwork.paas_subnet.self_link
  address_type = "INTERNAL"
  address      = "10.250.0.1${count.index}"
}

resource "google_compute_address" "worker_internal_address" {
  count        = "${var.node_count}"
  name         = "worker-${count.index}-internal-address"
  subnetwork   = google_compute_subnetwork.paas_subnet.self_link
  address_type = "INTERNAL"
  address      = "10.250.0.2${count.index}"
}

resource "google_compute_disk" "controller-" {
  count        = "${var.master_count}"
  name         = "master-${count.index}-dockervg"
  size         = "50"
  type         = "pd-standard"
}
resource "google_compute_instance" "sharaftfsbx" {
  count        = "${var.master_count}"
  name         = "paas-sbx-controller-${count.index}"
  machine_type = "n1-standard-1"
metadata = {
    ssh-keys = "sharafudheen:${file("~/.ssh/id_rsa_gcp_nix_paas_sbx.pub")}"
  }
  can_ip_forward = true
  tags = ["webserver","centos","paas-sbx-k8s"]
  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-7-v20200309"
      type    = "pd-standard"
      size = "50"
    }
  }
  scheduling {
    preemptible = false
    automatic_restart = false
  }
  network_interface {
    subnetwork = google_compute_subnetwork.paas_subnet.self_link
    network_ip = "${element(google_compute_address.controller_internal_address.*.address , count.index)}"
    access_config {
     /* count = "0" */
    }
  }
  attached_disk {
    source     = "${element(google_compute_disk.controller-.*.self_link , count.index)}"
    device_name = "dockervg"
  }
  service_account {
    scopes = ["compute-rw","storage-ro","service-management","service-control","logging-write","monitoring"]
  }
}

resource "google_compute_disk" "worker-" {
  count        = "${var.node_count}"
  name         = "worker-${count.index}-dockervg"
  size         = "50"
  type         = "pd-standard"
}
resource "google_compute_instance" "sharaftfsbxnode" {
  count        = "${var.node_count}"
  name         = "paas-sbx-worker-${count.index}"
  machine_type = "n1-standard-1"
metadata = {
    ssh-keys = "sharafudheen:${file("~/.ssh/id_rsa_gcp_nix_paas_sbx.pub")}"
  }
  can_ip_forward = true
  tags = ["webserver","centos","paas-sbx-k8s"]
  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-7-v20200309"
      type    = "pd-standard"
    }
  }
  scheduling {
    preemptible = false
    automatic_restart = false
  }
  network_interface {
    subnetwork = google_compute_subnetwork.paas_subnet.self_link
    network_ip = "${element(google_compute_address.worker_internal_address.*.address , count.index)}"
    access_config {
     /* count = "0" */
    }
  }
  attached_disk {
    source     = "${element(google_compute_disk.worker-.*.self_link , count.index)}"
    device_name = "dockervg"
  }
  service_account {
    scopes = ["compute-rw","storage-ro","service-management","service-control","logging-write","monitoring"]
  }
}

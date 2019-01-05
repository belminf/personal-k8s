variable "cluster_name" {}
variable "project" {}
variable "zone" {}
variable "standard_node_count" {}
variable "standard_node_type" {}

provider "google" {
  project = "${var.project}"
  zone    = "${var.zone}"
}

resource "google_container_cluster" "cluster" {
  name       = "${var.cluster_name}"

  network    = "${google_compute_network.network.self_link}"
  subnetwork = "${google_compute_subnetwork.nodes.self_link}"

  network_policy {
    enabled = true
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "${google_compute_subnetwork.nodes.secondary_ip_range.0.range_name}"
    services_secondary_range_name = "${google_compute_subnetwork.nodes.secondary_ip_range.1.range_name}"
  }

  addons_config {
    kubernetes_dashboard {
      disabled = true
    }

    horizontal_pod_autoscaling {
      disabled = true
    }
  }

  initial_node_count       = 1
  remove_default_node_pool = true
  logging_service          = "none"
}


resource "google_compute_network" "network" {
  name                    = "network"
  auto_create_subnetworks = "false"
}

resource "google_compute_subnetwork" "nodes" {
  name          = "nodes"
  ip_cidr_range = "10.101.0.0/24"
  network       = "${google_compute_network.network.self_link}"

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "172.20.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.200.0.0/16"
  }

}

resource "google_container_node_pool" "node_pool-micro" {
  name              = "default-micro"
  zone              = "${var.zone}"
  cluster           = "${google_container_cluster.cluster.name}"
  node_count        = 1

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    disk_size_gb = 10
    machine_type = "f1-micro"
    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
}

resource "google_container_node_pool" "node_pool-standard" {
  name              = "default-standard"
  zone              = "${var.zone}"
  cluster           = "${google_container_cluster.cluster.name}"
  node_count        = "${var.standard_node_count}"

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    disk_size_gb = 10
    machine_type = "${var.standard_node_type}"
    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
    preemptible = true
  }
}

output "kubectl config" {
  value = "gcloud container clusters get-credentials ${google_container_cluster.cluster.name}"
}

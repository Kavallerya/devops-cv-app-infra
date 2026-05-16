resource "google_compute_network" "vpc_network" {
  name                    = "cv-k8s-network"
  auto_create_subnetworks = true
}

resource "google_container_cluster" "primary" {
  name     = "cv-cluster"
  location = "europe-central2"
  network  = google_compute_network.vpc_network.name

  # 1. ВИМИКАЄМО AUTOPILOT
  enable_autopilot = false

  # 2. НАЛАШТОВУЄМО ФІКСОВАНИЙ КЛАСТЕР (GKE Standard)
  initial_node_count = 2 # Створити рівно 2 сервери

  node_config {
    machine_type = "e2-standard-2" # Кожен сервер: 2 vCPU, 8GB RAM. (Разом 4 vCPU — ідеально для квот!)
    
    # Обов'язкові права для нод, щоб вони могли спілкуватися з API Google
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  deletion_protection = false
}
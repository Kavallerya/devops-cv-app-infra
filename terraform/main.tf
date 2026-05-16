# Створюємо ізольовану мережу (VPC)
resource "google_compute_network" "vpc_network" {
  name                    = "cv-k8s-network"
  auto_create_subnetworks = true
}

# Створюємо GKE Autopilot кластер
resource "google_container_cluster" "primary" {
  name     = "cv-cluster"
  location = var.region

  # Вмикаємо режим Autopilot (Google сам керує нодами)
  enable_autopilot = true
  
  network = google_compute_network.vpc_network.name

  # Дозволяємо Терраформу видаляти кластер (без цього terraform destroy видасть помилку)
  deletion_protection = false 
}
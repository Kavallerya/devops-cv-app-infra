terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "google" {
  project = "cv-k8s-prod"
  region  = "europe-central2"
}

# ==========================================
# 1. МЕРЕЖА VPC
# ==========================================
resource "google_compute_network" "vpc_network" {
  name                    = "cv-k8s-network"
  auto_create_subnetworks = true
}

# ==========================================
# 2. КЛАСТЕР GKE STANDARD (Максимум квоти)
# ==========================================
resource "google_container_cluster" "primary" {
  name     = "cv-cluster"
  location = "europe-central2"
  network  = google_compute_network.vpc_network.name

  # Вимикаємо Autopilot, переходимо на повне керування
  enable_autopilot = false
  
  # Створюємо 2 ноди. Разом: 2 * 4 vCPU = 8 vCPU (забираємо всю доступну квоту)
  initial_node_count = 2 

  node_config {
    machine_type = "e2-standard-4" # 4 vCPU та 16 GB RAM на кожну ноду (Простір для всього!)
    disk_size_gb = 30              # Економія квоти дисків SSD_TOTAL_GB (ліміт 250GB)
    disk_type    = "pd-standard"   # Стандартні диски, щоб не блокувати квоту SSD

    # Область доступу для системних мікросервісів нод
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  # Дозволяє безперешкодно видаляти кластер через terraform destroy
  deletion_protection = false
}

# ==========================================
# 3. НАЛАШТУВАННЯ ВНУТРІШНІХ ПРОВАЙДЕРІВ
# ==========================================
# Динамічно отримуємо токен авторизації Google Cloud
data "google_client_config" "default" {}

# Провайдер для чистого Kubernetes (якщо знадобиться створювати маніфести)
provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

# Провайдер Helm для автоматичного встановлення чартів
provider "helm" {
  kubernetes {
    host                   = "https://${google_container_cluster.primary.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
  }
}

# ==========================================
# 4. АВТОМАТИЗАЦІЯ HELM ЧАРТІВ
# ==========================================

# Автоматичне встановлення External Secrets Operator
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true

  # Обов'язковий запуск Custom Resource Definitions (словників K8s)
  set {
    name  = "installCRDs"
    value = "true"
  }

  # Зберігаємо легке утрамбовування броні ресурсів, щоб лишити максимум гігабайт під ваш бекенд і базу даних
  set { name = "resources.requests.cpu", value = "10m" }
  set { name = "resources.requests.memory", value = "32Mi" }
  set { name = "webhook.resources.requests.cpu", value = "10m" }
  set { name = "webhook.resources.requests.memory", value = "32Mi" }
  set { name = "certController.resources.requests.cpu", value = "10m" }
  set { name = "certController.resources.requests.memory", value = "32Mi" }

  depends_on = [google_container_cluster.primary]
}

# Автоматичне встановлення ArgoCD (Повна версія з графічним інтерфейсом)
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true

  depends_on = [google_container_cluster.primary]
}
resource "google_compute_network" "vpc_network" {
  name                    = "cv-k8s-network"
  auto_create_subnetworks = true
}

resource "google_container_cluster" "primary" {
  name     = "cv-cluster"
  location = "europe-central2-a"
  network  = google_compute_network.vpc_network.name

  enable_autopilot   = false
  initial_node_count = 2 


workload_identity_config {
    workload_pool = "cv-k8s-prod.svc.id.goog"
  }


  node_config {
    machine_type = "e2-standard-4" 
    disk_size_gb = 30              
    disk_type    = "pd-standard"   
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  
  workload_metadata_config {
      mode = "GKE_METADATA"
    }
  
  }
  deletion_protection = false
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }
  
  depends_on = [google_container_cluster.primary]
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true

  depends_on = [google_container_cluster.primary]
}
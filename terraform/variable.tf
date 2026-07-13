variable "project_id" {
  description = "GCP project ID"
  type        = string
  default     = "cv-k8s-prod"
}

variable "region" {
  description = "Deployment region"
  default     = "europe-central2"
}
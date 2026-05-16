variable "project_id" {
  description = "ID вашого проекту в Google Cloud"
  type        = string
  default     = "cv-k8s-prod" # Впишіть сюди ваш точний Project ID!
}

variable "region" {
  description = "Регіон розгортання"
  default     = "europe-central2" # Варшава (найближчий до України)
}
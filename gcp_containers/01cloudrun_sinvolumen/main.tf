terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = "PROJECTID"  # sustituir por el ID del proyecto
  region  = "europe-west1"
}

# Habilita la API de Cloud Run (necesario si nunca se ha usado en el proyecto)
resource "google_project_service" "run" {
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

# Servicio Cloud Run con 2 contenedores (sidecar pattern)
# Redis y la app comparten red (localhost) igual que en ACI
resource "google_cloud_run_v2_service" "app" {
  name     = "demo-app"
  location = "europe-west1"

  depends_on = [google_project_service.run]

  template {
    containers {
      # Contenedor principal: app web
      name  = "web"
      image = "dgarridouma/get-started:part2"

      ports {
        container_port = 80
      }

      # Redis es localhost porque comparte red con la app en el mismo servicio
      # REDIS_HOST no hace falta definirla, su valor por defecto ya es localhost
    }

    containers {
      # Contenedor sidecar: Redis
      # No expone puerto al exterior, solo accesible por localhost desde la app
      name  = "redis"
      image = "redis:7"
    }
  }
}

# Permite acceso público al servicio (sin autenticación)
resource "google_cloud_run_v2_service_iam_member" "public" {
  project  = google_cloud_run_v2_service.app.project
  location = google_cloud_run_v2_service.app.location
  name     = google_cloud_run_v2_service.app.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# URL pública de la app web tras el despliegue
output "app_url" {
  value = google_cloud_run_v2_service.app.uri
}

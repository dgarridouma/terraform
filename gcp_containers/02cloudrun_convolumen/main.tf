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

# Habilita la API de Cloud Run
resource "google_project_service" "run" {
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

# Habilita la API de Cloud Storage
resource "google_project_service" "storage" {
  service            = "storage.googleapis.com"
  disable_on_destroy = false
}

# Bucket de GCS para persistencia de Redis
# Cloud Run monta el bucket como volumen usando Cloud Storage FUSE
resource "google_storage_bucket" "redis_bucket" {
  name          = "redis-data-prueba-terraform"  # debe ser único globalmente
  location      = "EU"
  force_destroy = true

  depends_on = [google_project_service.storage]
}

# Servicio Cloud Run con 2 contenedores (sidecar pattern) y volumen persistente
resource "google_cloud_run_v2_service" "app" {
  name     = "demo-app-vol"
  location = "europe-west1"

  depends_on = [google_project_service.run]

  template {
    # Monta el bucket de GCS como volumen accesible desde los contenedores
    volumes {
      name = "redis-storage"
      gcs {
        bucket    = google_storage_bucket.redis_bucket.name
        read_only = false
      }
    }

    containers {
      # Contenedor principal: app web
      name  = "web"
      image = "dgarridouma/get-started:part2"

      ports {
        container_port = 80
      }
    }

    containers {
      # Contenedor sidecar: Redis con volumen montado en /data para persistencia
      name  = "redis"
      image = "redis:7"

      # Monta el volumen en /data, que es donde Redis guarda sus datos
      volume_mounts {
        name       = "redis-storage"
        mount_path = "/data"
      }
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

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Crea el resource group que contendrá todos los recursos
resource "azurerm_resource_group" "rg" {
  name     = "grupo-app"
  location = "norwayeast"
}

# Registra el proveedor de ACA en la suscripción (necesario si nunca se ha usado)
#resource "azurerm_resource_provider_registration" "app" {
#  name = "Microsoft.App"
#}

# Crea el environment de ACA: espacio compartido de red para las Container Apps
resource "azurerm_container_app_environment" "env" {
  name                = "aca-env-demo"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  #  depends_on          = [azurerm_resource_provider_registration.app]
}

# Cuenta de almacenamiento en Azure para alojar el File Share
resource "azurerm_storage_account" "sa" {
  name                     = "sademoredis0010304c" # debe ser único globalmente
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS" # replicación local, la más barata
}

# File Share dentro de la storage account: carpeta compartida tipo NFS
resource "azurerm_storage_share" "redis_share" {
  name                 = "redis-data"
  storage_account_name = azurerm_storage_account.sa.name
  quota                = 1 # 1 GB
  depends_on           = [azurerm_storage_account.sa]
}

# Registra el File Share en el environment de ACA para que las apps puedan usarlo
resource "azurerm_container_app_environment_storage" "redis_storage" {
  name                         = "redis-storage"
  container_app_environment_id = azurerm_container_app_environment.env.id
  account_name                 = azurerm_storage_account.sa.name
  share_name                   = azurerm_storage_share.redis_share.name
  access_key                   = azurerm_storage_account.sa.primary_access_key
  access_mode                  = "ReadWrite"
}

# Container App para Redis con volumen montado en /data para persistencia
resource "azurerm_container_app" "redis" {
  name                         = "redis"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    container {
      name   = "redis"
      image  = "redis:7"
      cpu    = 0.25
      memory = "0.5Gi"

      # Monta el volumen en /data, que es donde Redis guarda sus datos
      volume_mounts {
        name = "redis-volume"
        path = "/data"
      }
    }

    # Asocia el volumen registrado en el environment al contenedor
    volume {
      name         = "redis-volume"
      storage_type = "AzureFile"
      storage_name = azurerm_container_app_environment_storage.redis_storage.name
    }
  }

  # Ingress interno TCP: solo accesible desde otras apps del mismo environment
  ingress {
    external_enabled = false
    target_port      = 6379
    transport        = "tcp"
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}

# Container App para la aplicación web
resource "azurerm_container_app" "app" {
  name                         = "get-started"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    container {
      name   = "get-started"
      image  = "miregistro2026.azurecr.io/get-started:part2" # nombreregistro.azurecr.io/get-started:part2
      cpu    = 0.25
      memory = "0.5Gi"

      # Le indica a la app dónde encontrar Redis (por nombre interno del environment)
      env {
        name  = "REDIS_HOST"
        value = azurerm_container_app.redis.name
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 80
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  # Credenciales de registro
  # Pueden ser de Docker Hub
  # O un registro de Azure Container Registries
  # Se pueden poner tantos bloques de estos tipos como registros se usen
  #secret {
  #  name  = "acr-password"
  #  value = "YOURPASSWORD"
  #}

  #registry {
  #  server               = "YOURREGISTRY.azurecr.io"
  #  username             = "YOURREGISTRY"
  #  password_secret_name = "acr-password"
  #}
}


# URL pública de la app web tras el despliegue
output "app_url" {
  value = "https://${azurerm_container_app.app.ingress[0].fqdn}"
}

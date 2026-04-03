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

# Container App para Redis
# Sin ingress externo: solo accesible desde otras apps del mismo environment
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
    }
  }

  # Ingress interno TCP: permite que otras apps accedan a Redis por su nombre
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
# Con ingress externo: accesible desde internet
resource "azurerm_container_app" "app" {
  name                         = "get-started"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    container {
      name   = "get-started"
      image  = "dgarridouma/get-started:part2" # nombreregistro.azurecr.io/get-started:part2
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

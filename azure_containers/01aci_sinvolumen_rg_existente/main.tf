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

# Referencia a un resource group ya existente en Azure (no lo crea)
data "azurerm_resource_group" "rg" {
  name = "grupocontainerapp"
}

# Container Group: unidad de despliegue en ACI que agrupa varios contenedores
# Los contenedores dentro comparten red (se ven por localhost) y ciclo de vida
resource "azurerm_container_group" "app" {
  name                = "demo-group"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  os_type             = "Linux"

  # Contenedor Redis: base de datos en memoria
  container {
    name   = "redis"
    image  = "redis:7"
    cpu    = 0.25
    memory = 0.5

    ports {
      port     = 6379
      protocol = "TCP"
    }
  }

  # Contenedor de la app web
  # No necesita REDIS_HOST porque su valor por defecto es localhost,
  # y en ACI todos los contenedores del mismo group comparten red
  container {
    name   = "web"
    image  = "dgarridouma/get-started:part2" # nombreregistro.azurecr.io/get-started:part2
    cpu    = 0.25
    memory = 0.5

    ports {
      port     = 80
      protocol = "TCP"
    }
  }

  # IP pública con DNS para acceder a la app desde internet
  ip_address_type = "Public"
  dns_name_label      = "get-started-${random_string.suffix.result}"

  # Credenciales de registro
  # Pueden ser de Docker Hub para evitar límites de rate limiting en IPs compartidas de Azure
  # O un registro de Azure Container Registries
  # Se pueden poner tantos bloques de este tipo como registros se usen
  image_registry_credential {
    server   = "index.docker.io" # nombreregistro.azurecr.io
    username = "YOURUSER"
    password = "YOURPASSWORD"
  }

  # Solo exponemos el puerto 80 al exterior; el 6379 queda interno
  exposed_port {
    port     = 80
    protocol = "TCP"
  }
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}


# URL pública de la app web tras el despliegue
output "app_url" {
  value = "http://${azurerm_container_group.app.fqdn}"
}

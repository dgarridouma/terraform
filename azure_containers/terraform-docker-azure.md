# Terraform con Docker en Azure

## Comunicación entre contenedores

- **ACI**: los contenedores deben estar en el mismo container group para comunicarse por `localhost`. Si se separan, pueden comunicarse exponiendo una IP pública, pero es menos directo y más caro.
- **ACA**: los contenedores de apps distintas se comunican por la red interna del environment, por lo que no necesitan estar juntos. Es mejor separarlos para que cada servicio tenga su propio ciclo de vida, escalado y configuración independiente (aunque no es obligatorio).

## Crear Service Principal para Terraform

```bash
az ad sp create-for-rbac --name "terraform-sp" --role Contributor \
  --scopes /subscriptions/<SUBSCRIPTION_ID>
```

La salida devuelve las credenciales necesarias para Terraform:

```json
{
  "appId": "<CLIENT_ID>",
  "displayName": "terraform-sp",
  "password": "<CLIENT_SECRET>",
  "tenant": "<TENANT_ID>"
}
```

> Protege estas credenciales. No las incluyas en el código ni en el control de versiones.

## Ejecutar Terraform dentro de un contenedor Docker

### Init (no requiere credenciales)

```bash
docker run -it --rm -v %cd%:/workspace -w /workspace hashicorp/terraform:latest init
```

### Apply

```bash
docker run -it --rm -v %cd%:/workspace -w /workspace \
  -e ARM_CLIENT_ID="<CLIENT_ID>" \
  -e ARM_CLIENT_SECRET="<CLIENT_SECRET>" \
  -e ARM_SUBSCRIPTION_ID="<SUBSCRIPTION_ID>" \
  -e ARM_TENANT_ID="<TENANT_ID>" \
  hashicorp/terraform:latest apply
```

### Destroy

```bash
docker run -it --rm -v %cd%:/workspace -w /workspace \
  -e ARM_CLIENT_ID="<CLIENT_ID>" \
  -e ARM_CLIENT_SECRET="<CLIENT_SECRET>" \
  -e ARM_SUBSCRIPTION_ID="<SUBSCRIPTION_ID>" \
  -e ARM_TENANT_ID="<TENANT_ID>" \
  hashicorp/terraform:latest destroy
```

## Registro del proveedor de Azure Container Apps

Si es la primera vez que se usa ACA en la suscripción, hay que registrar el proveedor:

```bash
az provider register --namespace Microsoft.App

# Comprobar estado del registro
az provider show --namespace Microsoft.App --query registrationState
```

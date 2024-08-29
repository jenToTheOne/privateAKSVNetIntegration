#register feature
#resource "azurerm_resource_provider_registration" "EnableAPIServerVnetIntegrationPreview" {
 # name = "Microsoft.ContainerService"

  #feature {
   # name       = "EnableAPIServerVnetIntegrationPreview"
    #registered = true
  #}
#}

#fetch resource group
data "azurerm_resource_group" "rg" {
  name = "rg_tf_private_aks"
}

#fetch kubernetes cluster
data "azurerm_kubernetes_cluster" "aks_private_001" {
  name                = "aks_private_001"
  resource_group_name = data.azurerm_resource_group.rg.name
}

#fetch vnet
data "azurerm_virtual_network" "vnet_aks" {
  name                = "vnet-aks"
  resource_group_name = data.azurerm_resource_group.rg.name
}

#subnet delegation
resource "azurerm_subnet" "subnet_api_server" {
  name                 = "subnet-api-server"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = data.azurerm_virtual_network.vnet_aks.name
  address_prefixes     = ["10.10.2.0/24"]

  delegation {
    name = "aks-api-delegation"
    service_delegation {
      name    = "Microsoft.ContainerService/managedClusters"
    }
  }
}

#identity setup
data "azurerm_user_assigned_identity" "mi_aks" {
  name                = "mi-aks"
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_role_assignment" "aks_role_01" {
  scope                = azurerm_subnet.subnet_api_server.id
  role_definition_name = "Network Contributor"
  principal_id         = data.azurerm_user_assigned_identity.mi_aks.principal_id
}


#aks cluster update
resource "azapi_update_resource" "aks_vnet_integration" {
  type       = "Microsoft.ContainerService/managedClusters@2024-06-02-preview"
  resource_id = data.azurerm_kubernetes_cluster.aks_private_001.id

  body = jsonencode({
    properties = {
      apiServerAccessProfile = {
        enableVnetIntegration = true,
        subnetId = azurerm_subnet.subnet_api_server.id
        privateDNSZone = "/subscriptions/e5f97bbd-e7a0-4d94-9a6f-b1e82a4c703a/resourceGroups/rg_tf_private_aks/providers/Microsoft.Network/privateDnsZones/dev.privatelink.westus2.azmk8s.io"
      }
    }
  })

  depends_on = [
    data.azurerm_kubernetes_cluster.aks_private_001
  ]
}
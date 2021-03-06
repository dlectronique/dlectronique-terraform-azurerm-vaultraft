# use this if you want to use azure KMS as a backend instead of Vault transit. 
# configure vault :
#  seal "azurekeyvault" {
#    tenant_id      = "${tenant_id}"
#    client_id      = "${client_id}"
#    client_secret  = "${client_secret}"
#    vault_name     = "${kmsvaultname}"
#    key_name       = "${kmskeyname}"
#    enviroment    = "AzurePublicCloud"
#  }


resource "random_id" "keyvault" {
  byte_length = 4
}

resource "random_id" "keyvaultkey" {
  byte_length = 4
}

resource "azurerm_key_vault" "vaultraft" {
  name                        = "vaultraft-${random_id.keyvault.hex}"
  location                    = azurerm_resource_group.vaultraft.location
  resource_group_name         = azurerm_resource_group.vaultraft.name
  enabled_for_deployment      = true
  enabled_for_disk_encryption = true
  tenant_id                   = var.tenant_id

  sku_name  = "standard"
  

  tags = {
    name      = var.owner
    TTL       = var.TTL
    owner     = var.owner
 }
}

resource "azurerm_user_assigned_identity" "vaultraft" {
  resource_group_name = azurerm_resource_group.vaultraft.name
  location            = azurerm_resource_group.vaultraft.location

  name = "${var.hostname}-vaultraft-vm"
}

resource "azurerm_key_vault_access_policy" "vaultraft_vm" {
  key_vault_id          = azurerm_key_vault.vaultraft.id
  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = data.azurerm_client_config.current.object_id
  certificate_permissions = [
    "get",
    "list",
    "create",
  ]
  key_permissions = [
    "backup",
    "create",
    "decrypt",
    "delete",
    "encrypt",
    "get",
    "import",
    "list",
    "purge",
    "recover",
    "restore",
    "sign",
    "unwrapKey",
    "update",
    "verify",
    "wrapKey",
  ]
  secret_permissions = [
    "get",
    "list",
    "set",
  ]
}

resource "azurerm_key_vault_key" "vaultraft" {
  name      = "vaultraft-${random_id.keyvaultkey.hex}"
  key_vault_id = azurerm_key_vault.vaultraft.id
  key_type  = "RSA"
  key_size  = 2048
  key_opts =   [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]

  tags =   {
    name      = var.owner
    TTL       = var.TTL
    owner     = var.owner
  }
}

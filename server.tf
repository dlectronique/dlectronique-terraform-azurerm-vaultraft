
data "template_file" "servers" {
  depends_on = [azurerm_public_ip.servers-pip]
  count      = "${var.servers}"

  template = "${join("\n", list(
    file("${path.module}/templates/shared/base.sh"),
    file("${path.module}/templates/nodes/vault.sh"),
  ))}"

  vars = {
    location   = var.location
    node_name  = "${var.hostname}-servers-${count.index}"
    private_ip = azurerm_network_interface.servers-nic[count.index].private_ip_address
    public_ip  = azurerm_public_ip.servers-pip[count.index].ip_address
    tpl_vault_leader_addr = azurerm_public_ip.leader-pip.ip_address
    enterprise = var.enterprise
    vaultlicense = var.vaultlicense
    vault_url = var.vault_url
    vault_ent_url = var.vault_ent_url
    subscription_id = var.subscription_id
    tenant_id       = var.tenant_id
    client_id       = var.client_id
    client_secret   = var.client_secret
    kmsvaultname  = azurerm_key_vault.vaultraft.name
    kmskeyname    = azurerm_key_vault_key.vaultraft.name
  }
}


# Gzip cloud-init config
data "template_cloudinit_config" "servers" {
  depends_on = [data.template_file.servers]
  count      = "${var.servers}"

  gzip          = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content      = data.template_file.servers[count.index].rendered
  }

}


resource "azurerm_subnet_network_security_group_association" "servers" {
  subnet_id                 = azurerm_subnet.servers.id
  network_security_group_id = azurerm_network_security_group.vaultraft-sg.id
}


resource "azurerm_network_interface" "servers-nic" {
  count               = var.servers
  name                = "${var.demo_prefix}servers-nic-${count.index}"
  location            = var.location
  resource_group_name = azurerm_resource_group.vaultraft.name

  ip_configuration {
    name                          = "${var.demo_prefix}-${count.index}-ipconfig"
    subnet_id                     = azurerm_subnet.servers.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.servers-pip[count.index].id

  }

  tags = {
    name  = var.owner
    TTL   = var.TTL
    owner = var.owner

  }
}

resource "azurerm_subnet" "servers" {
  name                 = "${var.demo_prefix}-servers"
  virtual_network_name = azurerm_virtual_network.awg.name
  resource_group_name  = azurerm_resource_group.vaultraft.name
  address_prefixes     = ["10.0.40.0/24"]
}

# Every Azure Virtual Machine comes with a private IP address. You can also 
# optionally add a public IP address for Internet-facing applications and 
# demo environments like this one.
resource "azurerm_public_ip" "servers-pip" {
  count               = var.servers
  name                = "${var.demo_prefix}-servers-ip-${count.index}"
  location            = var.location
  resource_group_name = azurerm_resource_group.vaultraft.name
  allocation_method   = "Static"
  domain_name_label   = "${var.hostname}-servers-${count.index}"
  sku                 = "Standard"

  tags = {
    name  = var.owner
    TTL   = var.TTL
    owner = var.owner

  }
}

resource "azurerm_virtual_machine" "servers" {
  count               = var.servers
  name                = "${var.hostname}-servers-${count.index}"
  location            = var.location
  resource_group_name = azurerm_resource_group.vaultraft.name
  vm_size             = var.vm_size
  availability_set_id = azurerm_availability_set.vm.id

  network_interface_ids            = [azurerm_network_interface.servers-nic[count.index].id]
  delete_os_disk_on_termination    = "true"
  delete_data_disks_on_termination = "true"

  storage_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }

  storage_os_disk {
    name              = "${var.hostname}-sever-osdisk-${count.index}"
    managed_disk_type = "Standard_LRS"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    disk_size_gb      = var.storage_disk_size
  }


  os_profile {
    computer_name  = "${var.hostname}-servers-${count.index}"
    admin_username = var.admin_username
    admin_password = var.admin_password
    custom_data = element(data.template_cloudinit_config.servers.*.rendered, count.index)
  }


  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
    name  = var.owner
    TTL   = var.TTL
    owner = var.owner
  }
}

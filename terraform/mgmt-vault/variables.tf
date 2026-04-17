# 2. Persistent Storage for Raft (Tiny but critical)
resource "openstack_blockstorage_volume_v2" "mgmt_vault_vol" {
  name = "mgmt-vault-data"
  size = 10 # 10GB is plenty for the Transit engine
}

# 3. The Management Vault Instance
resource "openstack_compute_instance_v2" "mgmt_vault" {
  name            = "mgmt-vault-transit"
  flavor_name     = "m1.tiny" # Low resource footprint
  image_name      = "Ubuntu-24.04"
  key_pair        = openstack_compute_keypair_v2.management_key.name
  security_groups = [openstack_networking_secgroup_v2.mgmt_vault_sg.name]

  network {
    uuid        = openstack_networking_network_v2.mgmt_net.id
    fixed_ip_v4 = "10.10.10.100" # Fixed IP for predictable unseal config
  }

  block_device {
    uuid                  = openstack_blockstorage_volume_v2.mgmt_vault_vol.id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = false
  }

  user_data = <<-EOF
    #cloud-config
    packages:
      - gpg
      - wget
    runcmd:
      # Install Vault binary
      - wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
      - echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list
      - apt-get update && apt-get install vault -y
      
      # Prepare Raft directories
      - mkdir -p /opt/vault/data
      - chown -R vault:vault /opt/vault/data
    EOF
}
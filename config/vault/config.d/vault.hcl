api_addr      = "https://0.0.0.0"
cluster_addr  = "https://0.0.0.0"
disable_mlock = true
ui            = true

storage "file" {
  path = "/vault/file"
}

listener "tcp" {
  address       = "0.0.0.0:443"
  tls_disable   = false
  tls_disable_client_certs = true
  tls_cert_file = "/vault/config/vault.pem"
  tls_key_file  = "/vault/config/vault.rsa"
}

max_lease_ttl = "720h"
default_lease_ttl = "168h"

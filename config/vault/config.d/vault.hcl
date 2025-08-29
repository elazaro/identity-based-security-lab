ui            = true
cluster_addr  = "http://0.0.0.0:8201"
api_addr      = "http://0.0.0.0:8200"
disable_mlock = true

storage "file" {
  path = "/vault/file"
}

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_disable   = true
}

max_lease_ttl = "720h"
default_lease_ttl = "168h"

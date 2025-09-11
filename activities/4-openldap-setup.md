# Activity 4: Identity-Based Security: OpenLDAP Setup

This activity is intended to guide you through the changes needed to make an
LDAP Server available for Keycloak to use it as a users storage, it can also be
used by an IGA solution such as SailPoint, PingAM, OIM, or Syncope to create
new identities' account, this way IGA-IAM integration can leverage in a single
repository for accounts reducing the burden of migrate accounts from a legacy
repo to Keycloak or create all the accounts in many places, including Keycloak.

For this laboratory we will use the osixia/openldap docker image.

### Goals

- Get an OpenLDAP Server up and running in our docker infrastructure.

### Assumptions:

- You are able to open, modify, save a file using VIM, and of course you can
  close VIM 😈
- You are running either Linux or MacOS in your local machine, if you use
  windows, sorry, I cannot help.

## Fake DNS settings.

We are naming our ldap server as "openldap.mxrisc.com" to make this FQDN resolvable from our local machine, we are not using any DNS server for simplicity, (we could add one to the lab, but nah!!), so if you are using linux or MacOS X, simply run the following command:

```
$ sudo vi /etc/hosts
```

Add the following line or modify the existing one to add openldap.mxrisc.com domain pointing to the localhost IPv4 address.

```
127.0.0.1	localhost openldap.mxrisc.com vault.mxrisc.com siem.mxrisc.com auth.mxrisc.com identity.mxrisc.com traefik.mxrisc.com
```

Save the file and ping the FQDN, this must resolve to ```127.0.0.1```

```
PING localhost (127.0.0.1): 56 data bytes
64 bytes from 127.0.0.1: icmp_seq=0 ttl=64 time=0.070 ms
64 bytes from 127.0.0.1: icmp_seq=1 ttl=64 time=0.199 ms
```

## Creating Volumes

There are two directories we want to make persistent through container
restarts, they are ```/var/lib/ldap``` and ```/var/ldap/slapd.d``` the first
one is used to store the directory data and the second one stores the server
configuration.

To make them persistent we need to create and mount docker volumes for each one
and mount them to the proper mount point in the container. 

Creating a volume is as easy as running the following commands:

```
$ docker volume create openldap-data
$ docker volume create openldap-conf
```

And that's it; if no error was printed, the volumes should be there for you to
configure the service in the ```docker-compose.yml``` file.

If paranoic, you can validate the volumes exist using the following command:

```
$ docker volume ls | grep openldap
DRIVER    VOLUME NAME
local     openldap-conf
local     openldap-data
```

We can discuss later what the ```local``` driver means and how to create more
interesting volumes, but this is enough for now.

## Configure Compose File

Once we have a couple of nice new volumes, we can configure the service in the
```docker-compose.yml``` file. For this, the first think to do is to make the
volumes available in the context of this configuration.

Go to the bottom of your ```docker-compose.yml``` file and add the following
lines.

```
  openldap-data:
    external: true
  openldap-conf:
    external: true
```

I said the bottom, but this can be any place where your file has the volumes listed, now, you can add the service definition as follows:

```
  openldap:
    image: osixia/openldap:stable-arm64v8
    hostname: openldap.mxrisc.com
    container_name: openldap
    restart: always
    environment:
      LDAP_ORGANISATION: 'mxRISC'
      LDAP_DOMAIN: 'mxrisc.com'
      LDAP_BASE_DN: 'dc=mxrisc,dc=com'
      LDAP_ADMIN_PASSWORD: 'admin-password'
      LDAP_CONFIG_PASSWORD: 'config-password'
      LDAP_READONLY_USER: false
      LDAP_RFC2307BIS_SCHEMA: false
      LDAP_BACKEND: 'mdb'
      LDAP_TLS: false
      LDAP_TLS_CRT_FILENAME: '/usr/local/share/certs/openldap.pem'
      LDAP_TLS_KEY_FILENAME: '/usr/local/share/certs/openldap.rsa'
      LDAP_TLS_DH_PARAM_FILENAME: '/usr/local/share/certs/diffie-hellman-params.pem'
      LDAP_TLS_CA_CRT_FILENAME: '/usr/local/share/certs/mxrisc_certification_chain.pem'
      LDAP_TLS_ENFORCE: false
      LDAP_TLS_CIPHER_SUITE: 
      LDAP_TLS_VERIFY_CLIENT: 'demand'
      HOSTNAME: 'openldap.mxrisc.com'
      LDAP_OPENLDAP_UID: 1001
      LDAP_OPENLDAP_GID: 1001
    volumes:
      - openldap-data:/var/lib/ldap
      - openldap-conf:/var/ldap/slapd.d
      - ./config/mxrisc_tls_certs:/usr/local/share/certs/
    labels:
      - "traefik.enable=true"
      - "traefik.tcp.routers.ldap.rule=hostsni(`openldap.mxrisc.com`)"
      - "traefik.tcp.routers.ldap.tls.passthrough=true"
      - "traefik.tcp.routers.ldap.entrypoints=websecure"
      - "traefik.tcp.services.vault.loadbalancer.server.port=389"
```

As you can see, I'm trying to set as many environment variables as possible in
order to configure as much as possible from the docker-compose file rather than
setting new configuration files and mounting them or rebuilding the docker
image.

In this first configuration I'm not enabling any TLS configuration, so only
LDAP protocol is available, although I set some variable to future settings we
will check in detail in the future.

```
      LDAP_TLS: false
      LDAP_TLS_CRT_FILENAME: '/usr/local/share/certs/openldap.pem'
      LDAP_TLS_KEY_FILENAME: '/usr/local/share/certs/openldap.rsa'
      LDAP_TLS_DH_PARAM_FILENAME: '/usr/local/share/certs/diffie-hellman-params.pem'
      LDAP_TLS_CA_CRT_FILENAME: '/usr/local/share/certs/mxrisc_certification_chain.pem'
      LDAP_TLS_ENFORCE: false
      LDAP_TLS_CIPHER_SUITE: 
      LDAP_TLS_VERIFY_CLIENT: 'demand'
```

Another important set of parameters are the onces related to the domain
configuration. In this lab I'm using alway mxrisc.com, and this ldap server
will use that domain as the base distinguished name.

```
      LDAP_ORGANISATION: 'mxRISC'
      LDAP_DOMAIN: 'mxrisc.com'
      LDAP_BASE_DN: 'dc=mxrisc,dc=com'
```

The service configuration mounts the volumes into the corresponding
mount points, also the Hashicorp Vault PKI engine certificates for TLS
configuration in the future.

```
    volumes:
      - openldap-data:/var/lib/ldap
      - openldap-conf:/var/ldap/slapd.d
      - ./config/mxrisc_tls_certs:/usr/local/share/certs/
```

Last but not least, a router and a service for Traefik to expose the ldap
protocol is set:

```
    labels:
      - "traefik.enable=true"
      - "traefik.tcp.routers.ldap.rule=hostsni(`openldap.mxrisc.com`)"
      - "traefik.tcp.routers.ldap.tls.passthrough=true"
      - "traefik.tcp.routers.ldap.entrypoints=websecure"
      - "traefik.tcp.services.vault.loadbalancer.server.port=389"
```

That's it, save your ```docker-compose.yml``` file and start the service.

## Start and Stop the service

You can start this specific service using compose command as follows.

```
$ docker compose up -d openldap
```

The above command will start the service in the background, along with the rest
of the services configured and running, you don't need to stop everything to
start this single service, just indicating the service name is enough for
Docker to start the named service.

Sometimes is useful for troubleshooting to start the service and keep the
terminal attached to the container, in that case hyou can just avoid the
```-d``` switch and it will start the container printing everything to your
terminal.

```
$ docker compose up openldap
```

Of course, you can stop the service without stopping the rest of services
running, to do so, just run the following command which will stop and remove
the service container instance, that way if you change something in the
docker-compose file, it will pick the latest changes when starting the service.

```
$ docker compose stop openldap
$ docker compose rm openldap
```

## Test connection.

Testing the connection is the last step in this activity, as we didn't configure this first version of our LDAP server to use TLS (ldaps), we 

The ```LDAP_TLS``` environment variable in the docker-compose file turns on or
off the TLS parameters for openldap to listen over ldaps. As we set it to
false, there's no ldaps listening.

```
      LDAP_TLS: false
```


Openldap docker image will automatically create an admin account under the ```LDAP_BASE_DN``` distinguished name we provided, resulting in an administrator account under the following DN: ```cn=admin,dc=mxrisc,dc=com```

```
      LDAP_BASE_DN: 'dc=mxrisc,dc=com'
      LDAP_ADMIN_PASSWORD: 'admin-password'
```

As we already configured Traefik, the hosts file in our local computer and
labeled the docker service to present itself through Traefik, we can proceed to
test thist service issueing a query against the root DN in our brand new
openldap server.

```
$ ldapsearch -x -H ldap://openldap.mxrisc.com -b "dc=mxrisc,dc=com" -D "cn=admin,dc=mxrisc,dc=com" -w admin-password
```

The ldapsearch command executed as above must return an output as the listed below.

```
# extended LDIF
#
# LDAPv3
# base <dc=mxrisc,dc=com> with scope subtree
# filter: (objectclass=*)
# requesting: ALL
#

# mxrisc.com
dn: dc=mxrisc,dc=com
objectClass: top
objectClass: dcObject
objectClass: organization
o: mxRISC
dc: mxrisc

# search result
search: 2
result: 0 Success

# numResponses: 2
# numEntries: 1
```

## Troubleshooting

- ```ldap_bind: Invalid credentials (49)```: check if the admin account DN is correct, is you changed the BASE_DN to another value different to the provided, make sure to use it as part of the ```cn=admin``` account.

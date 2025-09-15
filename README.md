# Identity-Based Laboratory

## About this laboratory

This lab is intended to provide you with an infrastructure for practicing the
most standard and vendor-agnostic way Identity and Access Management, (IAM) and
Identity Governance and Administration (IGA) concepts, it also provides a
Security Information and Event Management (SIEM) that you can use to configure
alerts and use it's elastic search engine to record audit data an create
reports.

Another important concept in information security, maybe a cornerstone in
modern internet communications is the Public Key Infrastructure, cryptography
is one of my passions I left for a while, but I'm taking it back in this lab as
it makes sense as part of and Identity-Based Security architecture, as not only
people, but computers, devices even programs are subject for identity
management, a PKI becomes a relevant piece in this lab.

## Landscape

For this lab, I've choosen opensource tools for IAM and IGA, as well as
Source-Available license software for Secrets Management which I will use as
PKI. there's no personal preference while choosing this software but I've found
quite pleasand to play with them.

For the SIEM part this lab uses Wazuh Dashboard, Manager and Indexer which are
distributed as GPL and Apache License, this are OpenSearch and ElastikSearch
customized tools for SIEM, so far it is a secondary goal in my lab, but there
will be a moment where Auditing, Logs and Alerts will become critical while
developing an Identity-Base Security Architecture.

### The Software

***IAM***

For the IAM, Access Management this laboratory is intended to implement as many
protocols as possible to help the user to understand as much as each protocol
features, ***KeyCloak***, supports SAML2.0 for Enterprise application that need
Federation and Logout, OAuth 2.0 for securing APIs and OpenID Connect (OIDC)
for modern applications with web security requirements.

This laboratory will authenticate the users through KeyCloak, so SIEM
Dashboard, and Hashicorp Vault will be integrated with KC for authentication,
so far only Hashicorp is integrated.

This deployments uses MySQL as the KC backend database for configurations and
data.

> ***TODO:*** Include a practice lab for enabling Vault to KC integration. 

***IGA***

For this opensource / source-available project I'm planning to integrate Apache
Syncope for Identity Governance and Administration, but this is not ready yet,
although, planning an industry available solutions alternative, I'm working on
a second Identity-Based Security Lab working with Forgerock

***SIEM***

Wazuh is an opensource SIEM solution based on ELK (Elasticsearch, Kibana, and
Logstash) in this first stage of this lab, I'm only using Elastic and Kibana
for Java applications logging and analysis using Filebeat as the logs forwarder
for pusing logs from an SLF4j output file formated for logstash through logback
encoding.

Check out the simple API-Based Digital Signature application (renaming pending)
in the
[web-digital-signature](https://github.com/elazaro/web-digital-signature.git)
repo.

***Secrets Management and PKI***

The original plan was to build an entire PKI, including CA, RA and UI from
scratch in a Microservices and Clean Code architecture, but while exploring
Hashicorp Vault as a Secrets Management solution which was already in my scope,
I discovered that it includes PKI Services through its PKI Engine, and
encryption using the Transit Engine, this is particulary usefull because it
already provides interfacing to use HCM devices and FIPS 140-2 compliance which
could be challengin for my basic PKI.

So, Hashicorp Vault will be my choice for Secrets Management (usefull for
storing access and authorization tokens), and as PKI for issuing certificates
for Services, Devices and People.

Hashicorp supports ACME (Automatic Certificate Management Environment) protocol
which is scheduled as next step to be implemented in this lab.

***Platform***
This Laboratory uses Docker desktop to run every above-listed service (except
for the Java application) the purpose is to provide a quick mechanism for the
Lab's users to deploy it easily and helping them to quickly start playing with
the platform.

This lab uses Traefik Proxy as application gateway to expose the backend
applications based on FQDN in the URL, this way, a request like
http://auth.mxrisc.com will pass through Traefik router, and then to the
traefik service pointing to the either web (HTTP) or websecure (HTTPS) backend
service, if there are more than a single backend server it can be configured
directly in the service as loadbalanced, including persistence strategy, but to
keep things simple each backend service in this lab is not clustered or
redundant.

## How to use this lab.

This lab's docker-compose file should allow you to run all the software with no
problems, still, most of the functional configurations in the software, for
example PKI engine and Intermediate CA with ACME enabled in HCP Vault is not
shipped with the configurations in this repo, I'll writte complementary guide
to configure the different aspects to make the lab functional.


### Prerequisites:

- Latest Docker Desktop installed in your local computer.

### Docker compose up.

To start all the services as daemons in the background run the following
command from the directory where you cloned this repo.

``` $ docker compose up -d ```

This command will run all the services configured in the docker-compose file,
the ```-d``` switch makes docker to run the containers in the background if you
run the command without the switch all the containers will capture the terminal
and print their logs directly to it, it's not a bad idea to use it, but you
will find a neat alternative below in this document.

If you change any configuration in the docker-compose while the container was
running, you can follow the process listed below:

```
# Stop the modified container
$ docker compose stop <service-name>
# Remove the 
$ docker compose rm <service-name>
# Restart the container
$ docker compose up -d <service-name>
# you can skip the -d switch if you want to see the logs as they show while
# booting the image.
```

If you want to print a given container logs to your terminal, 

```
$ docker compose logs -f <service-name>
```

The ```-f``` switch makes docker to capture the terminal and printing the logs
as they come if you just want the latest printed logs you can avoid this flag
and docker will print only the latest few lines in your log; it is basically
the same as the tail command.

You can use the Docker Desktop's UI to perform most of these tasks, but...
***where's the fun on it?***

>***Important:*** I've only tested this on a MacOS X computer, it should work on any other OS but some path separators or absolute paths should be adjusted to make it run on Windows... I guess...   

# Acknowledge
I want no to say thanks to ChatGPT as it resulted a very poor tool for
reasoning and making decisions. on the otherhand my large and sadly avandoned
collection of O'Reilly, Manning, Springer, Apress, NoStarch, etc... books
resulted in a satisfactory method to build and configure the best possible way
this small lab.

Please feel free to open a discussion an request features I'd be happy and will
enjoy implementing any weird and bizzare use case you'd like to share.

## Activities

# Hashicorp Vault

[Activity 3: OIDC Role with TLS](activities/3-vault-oidc-role-rw.md)

# OpenLDAP

[Activity 4: Adding OpenLDAP into the laboratory](activities/4-openldap-setup.md)

[Activity 5: Identity-Based Security: OpenLDAP Setup for complex structure.](activities/5-openldap-structure.md)

## Document's versions history:

| Version | Notes                                                                                   |
| ---     | ---                                                                                     |
| 1.0     | First version with many missing pieces, but delivering a usable lab with many features. |
| 1.1     | Instructions to start the docker compose file, it should have been in the v1 right?     |
| 1.2     | New activities section documenting different configurations implemented in the lab.     |
| 1.3.0   | activities/4-openldap-setup.md added reference.                                         |
| 1.3.1   | activities/5-openldap-structure.md added reference.                                     |


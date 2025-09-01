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


***Infrastructure***
This Laboratory uses Docker desktop to run every above-listed service (except
for the Java application) the purpose is to provide a quick mechanism for the
Lab's users to deploy it easily and helping them to quickly start playing with
the platform.


# Acknowledge
I want no to say thanks to ChatGPT as it resulted a very poor tool for
reasoning and making decisions. on the otherhand my large and sadly avandoned
collection of O'Reilly, Manning, Springer, Apress, NoStarch, etc... books
resulted in a satisfactory method to build and configure the best possible way
this small lab.

Please feel free to open a discussion an request features I'd be happy and will
enjoy implementing any weird and bizzare use case you'd like to share.

## Document's versions history:

| Version | Notes                                                                                   |
| ---     | ---                                                                                     |
| 1.0     | First version with many missing pieces, but delivering a usable lab with many features. |


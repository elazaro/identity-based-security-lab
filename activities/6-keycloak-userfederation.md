# Activity 6: Identity-Based Security: KeyCloak User Federation

In real-life organization it is not uncommon to find accounts repositories
where access is centrally managed as much as possbile, these repositories as
based on LDAP directory implementations as Active Directory, Oracle Directory,
eDirectory, etc... 

Keycloak can use an ldap directory as accounts repository, still it will
replicate accounts from the source into its own database either in a scheduled
fashion or during the first time the users autenticates. 

There's an alternative not to replicate users from the backend LDAP directory
into the Keycloak database but it might prevent some keycloak features from
working if the data stored in LDAP (openldap in our lab) does not match the
requirements for those features to work. we will explore these limitations
later. 

## Goals

We will configure Keycloak to use our just created openldap environment as its
accounts repository.

## Assumptions

- You have the openldap environment ready.
- You are familiar with the linux command line.

## Plan

The following list describes the activities we will perform to make this
integration work.

- Create a System account in openldap for it be used by Keycloak to autenticate
  against the directory.
- Grant proper access to the system account in openldap.
- Explore the Keycloak components.
- Explore the kcadmin.sh CLI.
- Create an org.keycloak.storage.UserStorageProvider component using the CLI.
- Adjusting the keycloak system account in openldap.

## Process

### Creating System Account.

We already learned how to create accounts in openldap using the ```ldapadd```
command.

Creating a System account for Keycloak involves three steps:

1. Create the account definition using an LDIF document as the onle below and
saving it as ```keycloak.ldif``` in a project's location.

```
dn: cn=keycloak,ou=devices,dc=mxrisc,dc=com
objectClass: mxriscSystem
objectClass: account
cn: keycloak
gidNumber: 5002
homeDirectory: /home/keycloak
uid: 5002
uidNumber: 5002
c: MX
```

2. Pushing the account into openldap: 

```
$ ldapadd \
    -x -H ldap://openldap.mxrisc.com -D "cn=admin,dc=mxrisc,dc=com" -w admin-password \
    -f config/openldap/objects/keycloak.ldif
```

3. Setting a new password for the recently created account:

```
$ ldappasswd \
    -x -H ldap://openldap.mxrisc.com -D "cn=admin,dc=mxrisc,dc=com" -w admin-password \
    -S cn=keycloak,ou=devices,dc=mxrisc,dc=com
New password:
Re-enter new password: 
```

The ldappasswd logs into openldap with the ```cn=admin``` account and sets a
new password using the ```-S``` option to the account indicated as the very last
parameter.

### Granting access to openldap's system account.

The object class we are using for service accounts its named system account,
although the standard would be to call these account types as Service accounts,
I'm only using a non-standard name to make everything more interesting, and
also because each organization has its own naming conventions, in mxRISC we
call them "system" accounts. 😉

Keycloak will need access to the whole openldap tree, using the account as it
is right now would fail while trying to search accounts other than its own, so
we need to grant access to the rest of the tree, as we are only reading
employees' accounts, we can grant the least privilege only.

Before applying any change I hightly encourage you to backup your current
olcDatabase, you can use wheter method, and you can also use the following
command to inspect the current configuration.

```
docker container exec -it <<container_id>> ldapsearch -Y EXTERNAL -b "cn=config" -H ldapi:///  '(olcDatabase=mdb)'
```

To do this, we need to modify the olcDatabase using an ldif as follows:

```
dn: olcDatabase={1}mdb,cn=config
changetype: modify
replace: olcAccess
olcAccess: {0}to * by dn.exact=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth manage by * break
olcAccess: {1}to attrs=userPassword,shadowLastChange by self write by dn="cn=admin,dc=mxrisc,dc=com" write by anonymous auth by * none
olcAccess: {2}to dn.one="o=internal-users,dc=mxrisc,dc=com" by dn.base="cn=keycloak,ou=devices,dc=mxrisc,dc=com" write
olcAccess: {3}to dn.children="dc=mxrisc,dc=com" by dn.base="cn=keycloak,ou=devices,dc=mxrisc,dc=com" search
olcAccess: {4}to * by self read by dn="cn=admin,dc=mxrisc,dc=com" write by * none
```

This ldif grants write access over the internal-users container and restricts
its access to their children containers, that way if a disabled or legal-hold
accouts got moved to any subtree, they will be inaccessible by the keycloak
system account preventing these accounts to login to any resource through
keycloak. 

ACLs 2 and 3 make the work, the first one grants read access to the
internal-users container and it's children, while the second grants search
access to the baseDN, this second acl is needed for the keycloak account being
able to search for accounts otherwise, even if you have the write acl, keycloak
won't be able to search any account in the DIT.

### Exploring Keycloak components architecture.

Keycloak builds, at a very high level, its configuration on two important
building blocks, Components and Providers; The component describes a standard
set of attribute Keycloak can use to interact with the Provider.

The component model includes the providerId and the providerType, where the
providerId indicates the specific provider identifier unique for this type of
provider, while the providerType points to the class implementing the supported
capabilities of each component. 

The provider is the implementation while the component represents the
integration between Keycloak and the functionality provided.

The ```org.keycloak.storage.UserStorageProvider``` class is the providers'
superclass for accounts federation, we will create this component into the KC
configuration, the ```org.keycloak.storage.ldap.LDAPStorageProvider``` is the
subclass implementing account federation against an LDAP directory.

There are other components such as the one implemented by the
```org.keycloak.storage.ldap.mappers.LDAPStorageMapper``` class, which
describes how to retrieve one account attribute from ldap and map it to a
Keycloak account attribute.

In our activity we will observe how, there are references from one componente
to other, such as the relationship between the LDAPStorageProvider and one to
many LDAPStorageMappers.

<!-- inserting here an UML diagram would be interesting -->

### Exploring the kcadmin.sh CLI 

Keycloak provides as most of the mothern Information Security Technologies, an
UI, but in my humble opinion, any tool which claims being flexible and
powerfull MUST provide a good CLI or API for managing and configuring its
features.

An UI is fine, its nice, brings a user friendly experience to the end users,
but it's not enough for serious implementations and projects where the
engineers are continously changing settings, onboarding applications,
configuring users backends, and many repetivive or complex activities on the
platform, that's the spirit behind my laboratory prefering CLI or APIs over UI
configuration where available. Also, an UI encapsulates many concepts behind an
apply button, of a form retrieving paramaters; Knowledge over the low level
components and architectural elements is key when troubleshooting real-life
problems in an efficient, accourate and productive way.

So, said that; Keycloak's CLI is a Java application wrapped in a ```sh```
script named kcadm.sh. This Script uses the installed java virtual machine to
start the Java Client packed in the keycloak-admin-cli-<<version>>.jar file.

>***Note: *** Some creativity can be used to modify how to execute or integrate
>the admin-cli into you own bash, korn, power, python scripts, or even to
>integrate it into another application by just using the classes in the
>admin-cli application or the libraries in the client/lib directory shipped with
>keycloak. 

These libraries and classes use the Keycloak API, so an alternative, if you
don't have access to the kcadmin.sh script and its components, is to use the
API directly from your ```curl```, postman or whatever API client you use.

Please refer to the Keycloak documentation in this matter: 

<!-- Todo: Add links to the API definition and the admin-cli and libraries Javadoc  -->

Let's focus in this activity on the kcadm.sh script usage.

The first thing you need to do before being able to retrieve or modify any
object in Keycloak is to login to the system. to do so, you must execute the
```config credentials``` command against the corresponding Keycloak URL passing
your administrator username and password and optionally indicating what realm
will you work with.

***Login***

```
docker container exec -it $(docker container ls --format "{{.ID}}" --filter "name=keycloak") \
/opt/keycloak/bin/kcadm.sh config credentials \
--server http://auth.mxrisc.com/\
--user elazaro\
--realm master
```
In this version I (slightly) improved the command to use docker and get the
container's id directly from its output, rather than using a separate execution
to obtain it. 

The first line of the command above runs ```docker container ls``` to get the
ID from the container named 'keycloak' and passes it as argument to a parent
```docker container exec``` command to finally execute the shped in
```/opt/keycloak/bin/kcadm.sh``` command contained in the docker image.

The second line executes the kcadm.sh script passing the ```config
credentials``` operation to authenticate against a server.

The third line indicates the kcadm command what server send to the login
requests.

The fourth line passes the user name to login, it must be a real administrator
or be granted with whatever privilege needed to manage the server.

Finally, the last line indicates what realm this user is authenticating
against.

Once the authentication was completed successfuly the authorization token is
stored internally by the admin-cli application making it available through the
next command invocations until it is expired.

### Creating an UserStorageProvider using the CLI

After the authentication was completed, we can proceed with the UserStorage
component creation, for this we will execute the following command:

```
$ docker container exec -it $(docker container ls --format "{{.ID}}" --filter "name=keycloak") \
    /opt/keycloak/bin/kcadm.sh create components \
    -r mxrisc \
    -s name=ldap-provider \
    -s providerId=ldap \
    -s providerType=org.keycloak.storage.UserStorageProvider \
    -s 'config.priority=["1"]' \
    -s 'config.fullSyncPeriod=["-1"]' \
    -s 'config.changedSyncPeriod=["-1"]'  \
    -s 'config.cachePolicy=["DEFAULT"]'  \
    -s config.evictionDay=[]  \
    -s config.evictionHour=[]  \
    -s config.evictionMinute=[]  \
    -s config.maxLifespan=[]  \
    -s 'config.batchSizeForSync=["1000"]'  \
    -s 'config.editMode=["READONLY"]' \
    -s 'config.syncRegistrations=["false"]' \
    -s 'config.vendor=["openldap"]' \
    -s 'config.usernameLDAPAttribute=["cn"]'  \
    -s 'config.rdnLDAPAttribute=["uid"]'  \
    -s 'config.uuidLDAPAttribute=["entryUUID"]'  \
    -s 'config.userObjectClasses=["mxriscEmployee"]'  \
    -s 'config.connectionUrl=["ldap://openldap.mxrisc.com"]'   \
    -s 'config.usersDn=["o=internal-users,dc=mxrisc,dc=com"]'  \
    -s 'config.authType=["simple"]'  \
    -s 'config.bindDn=["cn=keycloak,ou=devices,dc=mxrisc,dc=com"]'  \
    -s 'config.bindCredential=["keycloak-password"]'  \
    -s 'config.searchScope=["1"]'  \
    -s 'config.useTruststoreSpi=["always"]'  \
    -s 'config.connectionPooling=["true"]'  \
    -s 'config.pagination=["true"]'  \
    -s 'config.debug=["true"]'  \
    -s 'config.debug=["true"]'  \
    -s 'config.enabled=["false"]' \
    -s 'config.importEnabled=["true"]'
```

The command listed above, indicates the realm, in this ```mxrisc``` in this
case, where the user storage is being set-up, all the list of ```-s```
parameters, indicate the particular component parameters, while creating
different types of componentes, these parameters can change based on each
components requirements, in this case, as we are setting-up an LDAP based user
storage, you can easily map each parameter to an openldap connection parameter.
Configuration parameter names are quite self describing, although I'm
explaining each of these in the following table.

| Parameter             | Value                                     | Description                                                                                                                                        |
| ---                   | ---                                       | ---                                                                                                                                                |
| name                  | ldap-provider                             | Just the component name.                                                                                                                           |
| providerId            | ldap                                      | No need to say anything.                                                                                                                           |
| providerType          | org.keycloak.storage.UserStorageProvider  | The class which implements the component logic.                                                                                                    |
| priority              | "1"                                       | An integer indicating the users storage priority while searching for the account for authentication.                                               |
| fullSyncPeriod        | "-1"                                      | Indicates the period of time in seconds to perform a fullsync, this synchronize all the users in LDAP into Keycloak, disabled using -1 for now.    |
| changedSyncPeriod     | "-1"                                      | Indicates the period of time in seconds to sync changed accounts, this is sort of a Delta Sync form LDAP into Keycloak, disabled using -1 for now. |
| cachePolicy           | "DEFAULT"                                 | Keycloak storage providers support DEFAULT, EVICT_DAILY, EVICT_WEEKLY, MAX_LIFESPAN, and NO_CACHE                                                  |
| evictionDay           |                                           | When using Weekly, the day of the week when the eviction occurs.                                                                                   |
| evictionHour          |                                           | When using Weekly, Daily, the hour of the day the eviction takes place.                                                                            |
| evictionMinute        |                                           | When using Weekly, Daily, the minute of the hour the evition happens.                                                                              |
| maxLifespan           |                                           | The Maximum lifespan in seconds for caching.                                                                                                       |
| batchSizeForSync      | "1000"                                    | The number of accounts to read in a batch while synching                                                                                           |
| editMode              | "READ_ONLY"                               | The Storage configuration mode it can be one of the following: READ_ONLY, WRITABLE, UNSYNCED                                                       |
| syncRegistrations     | "false"                                   |                                                                                                                                                    |
| vendor                | "openldap"                                | Indicates this UserStorageProvider specific vendor for the factory to build the proper implementation.                                             |
| usernameLDAPAttribute | "cn"                                      | This is how the username will be mapped in the User Model within Keycloak                                                                          |
| rdnLDAPAttribute      | "cn"                                      | This is the attribute Keycloak will use to search for the account in the LDAP directory.                                                           |
| uuidLDAPAttribute     | "entryUUID"                               | The Account Unique identifier in the downstream LDAP Directory.                                                                                    |
| userObjectClasses     | "mxriscEmployee"                          | The filter indicating what objectClasses Keycloak will read from LDAP.                                                                             |
| connectionUrl         | "ldap://openldap.mxrisc.com"              | The LDAP Server's URI, in this case we are not using TLS so the protocol is ldap.                                                                  |
| usersDn               | "o=internal-users,dc=mxrisc,dc=com"       | The base DN Keycloak will use to search and read accounts from LDAP.                                                                               |
| authType              | "simple"                                  | LDAP Authentication type, simple (username and password) or SASL                                                                                   |
| bindDn                | "cn=keycloak,ou=devices,dc=mxrisc,dc=com" | The System account DN to authenticate Keycloak against its LDAP user repository.                                                                   |
| bindCredential        | "keycloak-password"                       | The System account's password.                                                                                                                     |
| searchScope           | "1"                                       | An integer indicating the search scope 0=base 1=single-level 2=subtree                                                                             |
| useTruststoreSpi      | "always"                                  |                                                                                                                                                    |
| connectionPooling     | "true"                                    | Enable/Disable connection pooling.                                                                                                                 |
| pagination            | "true"                                    | Enable/Disable pagination for sync.                                                                                                                |
| debug                 | "true"                                    | Enable/Disable debugging while using the component.                                                                                                |
| enabled               | "false"                                   | Enables/Disables the whole Users Repository                                                                                                        |
| importEnabled         | "true"                                    | Enables account Import, if there's no Sync it will import the account when a user logs-in                                                          |

Once the UserStorage component was created in Keycloak we can authenticate
against the 'account-service' endpoint using any account existing in openldap
```http://<keycloak-fqdn>/realms/<realm-name>/account``` this Endpoint allows the
logged in user to change some account attributes such as the First name, Last
name and email address.

We can now authenticate with the ```xsurname``` account using the password set
in openldap through the ```http://auth.mxrisc.com/realms/mxrisc/account``` URL,
this authentication page looks as follows:

![Keycloak authentication page](https://github.com/elazaro/identity-based-security-lab/blob/main/activities/imgs/6.1 keycloak-authentication.png?raw=true)

Once authenticated, Keycloak will show a Personal Info page for the user to
complete or modify its personal information, setting up MFA and check Activity
and Applications granted to the account.


![Keycloak personal info page](https://github.com/elazaro/identity-based-security-lab/blob/main/activities/imgs/6.2 keycloak-personal-info.png?raw=true)



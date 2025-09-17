# Activity 5: Identity-Based Security: OpenLDAP Setup for complex structure.

At this point we can go ahead and configure Keycloak to use OpenLDAP for users
federation, although, in the wilderness things are not that easy, there could
be different LDAP containers containing different types of objects, even
accounts in different statuses or created with custom attributes, in real life
deployment scenarios can follow any crazy data architecture, so lets get ready
to face weird situations.

### Goals

This activity's goal is to configure a complex structure in our brand new LDAP
server trying to replicate common scenarios where account objects are stored
across different containers and structures and include extended attributes
relevant for authentication and authorization but not part of the standard
Schema COSINE X.500

### Assumptions:

- You are familiar with how an LDAP tree looks like
- You are familiar with what an LDAP object is, and the standard attributes
  such as DN and CN.
- You are confortable typing commands in your terminal.

## Organization Structure

By default, openldap will create a tree structure based on the ```ROOT_DN``` environment variable, in our case ```dc=mxrisc,dc=com``` below this structure we can create as many branches as we need, the proposed structure would be:

```
dc=com,dc=mxrisc
    ├── o=internet-users
    │   └── ou=disabled
    ├── o=internal-users
    │   ├── ou=disabled
    │   └── ou=legalhold
    └── ou=devices
```

An LDIF file (LDAP Data Interchange Format) is needed to create this, you can
also use a visual tool like Apache Directory Studio, but... dude, non-alcohol
beer is not beer.

```
dn: o=internet-users,dc=mxrisc,dc=com
objectClass: top
objectClass: organization
o: internet-users
description: mxRISC customers' accounts.

dn: o=internal-users,dc=mxrisc,dc=com
objectClass: top
objectClass: organization
o: internal-users
description: mxRISC Umpa Lumpas' accounts. (yeah, yeah, I know)

dn: ou=devices,dc=mxrisc,dc=com
objectClass: top
objectClass: OrganizationalUnit
ou: devices
description: mxRISC devices' accounts, idk exactly what will I drop here.

dn: ou=disabled,o=internet-users,dc=mxrisc,dc=com
objectClass: top
objectClass: OrganizationalUnit
ou: disabled
description: Bad Hombres' accounts.

dn: ou=disabled,o=internal-users,dc=mxrisc,dc=com
objectClass: top
objectClass: OrganizationalUnit
ou: disabled
description: We will miss you.

dn: ou=legalhold,o=internal-users,dc=mxrisc,dc=com
objectClass: top
objectClass: OrganizationalUnit
ou: legalhold
description: Oh boy!
```

Save the above text into an ldif file or take it from
```activities/assets/4-organization-structure-creation.ldif``` in this
repository and run the following command, if yout saved it under your own
naming and path, change the file path in the command line.


```
$ ldapadd \
    -x -H ldap://openldap.mxrisc.com -D "cn=admin,dc=mxrisc,dc=com" -w admin-password  \
    -f activities/assets/4-organization-structure-creation.ldif
```

The command's output must be as follows: 

```
adding new entry "o=internet-users,dc=mxrisc,dc=com"
adding new entry "o=internal-users,dc=mxrisc,dc=com"
adding new entry "ou=devices,dc=mxrisc,dc=com"
adding new entry "ou=disabled,o=internet-users,dc=mxrisc,dc=com"
adding new entry "ou=disabled,o=internal-users,dc=mxrisc,dc=com"
adding new entry "ou=legalhold,o=internal-users,dc=mxrisc,dc=com"
```

The ```ldapadd``` command creates any object as specified in an LDIF file, you
can specify as many attributes as needed in the LDIF file, this way you can
create a whole LDAP structure just pressing a key, okay, maybe a few more, but
it's faster and less error prone than creating many objects from a UI.

## Extending the Account Schema

Extending the default Schema is simpre, we just need to create a new schema
file with the attribute we need, the difficult part is selecting the proper
setting for each attribute.

Let's use a first example to dissec the schema definition through the
attributetype and objectclass directive.

```
attributetype ( 1.1.2.1.1 
    NAME 'mxriscLeader' 
    DESC 'Pointer to this person's leader DN not the manager.'
    EQUALITY distinguishedNameMatch
    SUBSTR caseIgnoreSubstringsMatch
    SYNTAX 1.3.6.1.4.1.1466.115.121.1.12
    SINGLE-VALUE
)

objectclass ( 1.1.2.2.1
    NAME 'mxrisc-employees'
    DESCRIPTION 'mxRISC customized accounts'
    SUP account
    STRUCTURAL
    MUST(cn)
    MAY (manager $ mxriscLeader)
)
```

The attributeType directive receives the following parameters (among others)

- Unique OID (object identifier, based on the Internet Assigned Numbers Authority.
- Name.
- Readable description of the attribute purpose.
- Equality policy to match values, in this case it must match a DN structure.
- Substring policy to retrieve substrings while searching.
- Syntax indicates the OID of the corresponding data type.
- Single value flag indicating this attribute type can hold only a single
  value, it can be set to multivalue if needed.

The objectclass directive follows a similar set of input arguments, except for
the following:

- SUP indicates what object class this new class inherits attributes from.
- STRUCTURAL indicates the object class is ... well... STRUCTURAL
- MUST sets the minimum attributes this class needs for an object to be created.
- MAY set optional attributes for this class, we are setting the brand new
  manager and mxriscLeader attributes as optional.

For more information please refer to the openldap documentation which is awesome to read.

[OpenLDAP administration guide - Schema](https://www.openldap.org/doc/admin23/schema.html)

### Converting the schema into an ldif file.

The next step is to convert this schema file into an ldif file so we can use
the ```ldapadd``` command to add the attribute types and new object classed to
the schema configuration of OpenLDAP.


The osixia openldap container includes a tool to conver schema files to ldif
files, it is located in the
```./container/service/slapd/assets/schema-to-ldif.sh``` path in the container,
we can use the ```docker exec``` command to either start a bash shell or
execute the script directly in the container.

To execute either option (we will take the second alternative in this
activity), we need to configure a few things in the ```docker-compose.yml```
file.

1. Mount the directory where we created the schema file into a temporary
   location in the container.

    In the ```docker-compose.yml``` file, add the following line to the
openldap service's volumes settings:

```
      - ./config/openldap/schema/custom:/tmp/custom ```

    This will make every file in the custom directory available in the
```/tmp/custom``` directory within the container.

1.1. Alternatively we can just copy the file using the ```docker cp``` command.

    ``` docker cp ./config/openldap/schema/custom/mxrisc.schema
<<container-id>>:/tmp/mxrisc.schema ```

    This will copy the mxrisc.schema file into the container's directory /tmp/

2. Restart the running service.

    ``` $ docker compose stop openldap $ docker compose rm openldap $ docker
compose up -d openldap ```

    This is process is important to make sure that the new service instance
will pick all the latest changes made in the ```docker-compose.yml``` file.

3. Convert the schema file to an ldif file.

    ``` $ docker container exec -it <<container-id>>
./container/service/slapd/assets/schema-to-ldif.sh /tmp/custom/mxrisc.schema
config file testing succeeded ```

    This command will create the ldif file resulting from the schema in the
same directory, if you mounted the directory from your local machine, you can
inspect the ```mxrisc.ldif``` file directly from that path. otherwise if you
need to inspect if you will need to copy it from the docker container.
    
    Note that the ```/tmp/custom/mxrisc.schema``` file resides inside the
docker image, not your local machine or user space.

4. Apply the changes to openldap.

    ``` $ docker container exec -it <<container-id>> ldapadd -Y EXTERNAL -H
ldapi:/// -f /tmp/custom/mxrisc.ldif ```

    Note that we are using the ldapi protocol rather than ldap, this is because
our administrator account is restricted and cannot modify the schema remotely,
it must use the file descriptor based local communication and as you can guess
the ```ldapadd``` command is again running withing the docker container rather
than in the local user space.


## Creating accounts

``` dn: cn=elazaro,o=internal-users,dc=mxrisc,dc=com objectClass: account
objectClass: mxriscEmployee cn: elazaro uid: 5001 ``` ``` $ ldapadd -x -H
ldap://openldap.mxrisc.com -D "cn=admin,dc=mxrisc,dc=com" -w admin-password -f
config/openldap/objects/accounts.ldif ```

## Let's implement a requirement

The mxRISC Identities team wants three different objecClasses for different
account types and each type with different attribute requirements.

- Employee
    - Manager DN
    - Leader DN
    - Allowed Country
    - Password
- Customer
    - Country
    - Password
- System
    - Country
    - Password

Based on these requirements requirements we can detect easily the following:

- Manager is an RFC1274 attribute flagged as MAY in extensibleObject and
  inetOrgPerson objectClasses.
- Leader DN is not a standard attribute so we must create it.
- Country is an RFC4519 attribute but only flagged as MAY or MUST in a few
  objectClasses including extensibleObject.
- Password is an RFC4519 attribute, flagged as MAY in many objectClasses
  including extensibleObject, inetOrgPerson, person and posixAccount.

We can create a table to map our attributes as follows:

| Attribute    | extensibleObject | inetOrgPerson | person | posixAccount | custom |
| ---          | ---              | ---           | ---    | ---          | ---    |
| manager      | ✅               | ✅            |        | ✅           |        |
| leader       |                  |               |        |              | ✅     |
| c            | ✅               |               |        |              |        |
| userPassword | ✅               | ✅            | ✅     | ✅           |        |

We can see in this table that we can implement each of these custom objectClasses in 
several different ways.

extensibleObject includes almost all the attributes we need except for the
leader DN, also includes hundreds of other attributes we don't need and
probably want to avoid, so to keep the implementation simple, extensibleObject
is not the best choice.

inetOrgPerson is the next option, actually according to RFC2798 it's inteded to
hold information about people, it include many usefull attributes we can use in
the future, but it doesn't include the country needed for customer's accounts,
let's use this objectClass as base class for our Employee and Customer classes,
we can include the additional necessary attribute on each class definition.

person, is a superclass of inetOrgPerson, so it makes no sense to consider it
as inetOrgPerson fits the best the requirement. 

Finally, posixAccount is a class indeded for UNIX accounts, we need a System or
Service Account Class, the posixAccount matches the best as it is used for
users to login to UNIX systems, the only challenge is that it does not have a
country attribute and will need to create a custom class to make it match the
requirements.

Then, our classes definition would be as follows:

| Class          | SUP           | Additional Attributes |
| ---            | ---           | ---                   |
| mxriscEmployee | inetOrgPerson | mxrisctLeader, c      |
| mxriscCustomer | inetOrgPerson | c                     |
| mxriscSystem   | posixAccount  | c                     |

We already have the mxristLeader attribute, and it matches our requirements, so we
are good, although we created the mxriscEmployee as an account subclass, we
need to fix this first.

For this we will use the following ldif file:

```
dn: cn={9}mxrisc,cn=schema,cn=config
changetype: modify
replace: olcObjectClasses
olcObjectClasses: ( 1.1.2.2.1 NAME 'mxriscEmployee' DESC 'mxRISC customized accounts' SUP inetOrgPerson STRUCTURAL MUST cn MAY ( c $ mxriscLeader ) )
```

Save the above in the ```config/openldap/schema/custom/new-mxrisc.ldif``` file.

Observe the ```{9}``` in the ```cn``` attribute; it is an ordering and indexig
feature in the openldap backend, when modifying an existing schema definition
you must use the correct index, to retrieve the correct value and modify the
```dn``` in the ldif file use the following command.

```
$ docker container exec -it <<container-id>> ldapsearch -Y EXTERNAL -b "cn=schema,cn=config" -H ldapi:///  '(cn=*mxrisc)'
```

As you may have noticed we are using the ```ldapi://``` protocol, this is
because the ```cn=config``` tree is protected.

Once we have all the information needed, apply the changes with the ldapmodify
command using the ldapi protocol.

```
$ docker container exec -it <<container-id>> ldapmodify -Y EXTERNAL -H ldapi:/// -f /tmp/custom/new-mxrisc.ldif
    SASL/EXTERNAL authentication started
    SASL username: gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth
    SASL SSF: 0
    modifying entry "cn={9}mxrisc,cn=schema,cn=config"
```

Now we can create the other two objectClasses we need, mxriscCustomer and
mxriscSystem, the objectClass definition must be like described below:   

```
objectclass ( 1.1.2.2.2 
    NAME 'mxriscCustomer' 
    DESC 'mxRISC's customers with access from the internet.' 
    SUP inetOrgPerson 
    STRUCTURAL 
    MUST( c ) 
 )

objectclass ( 1.1.2.2.3 
    NAME 'mxriscSystem' 
    DESC 'mxRISC applications and infrastructure.' 
    SUP posixAccount 
    AUXILIAR 
    MAY ( c ) 
 )
```

Follow the same procedure we followed while creating the mxriscEmployee class
for the first time.

> ***Note:*** The posixAccount is AUXILIAR object, so it can only be inherited
> by AUXILIAR objects but these classes cannot be used to create any object so
> when creating a System Account, use it in combination with another STRUCTURAL
> objectClass such as account.


### The easy way

If you are starting the openldap for the first time, you can just create a
schema file containing the objectClass and attributeType definitions and
present it in the  ```LDAP_SEED_INTERNAL_SCHEMA_PATH``` environment variable.

Remember you first need to mount the local file in the path set to this
variable.

When started, the container will pick this file, convert it into an ldif and
will apply the changes to the schema for you, so you don't need to execute any
of the steps described before, but hey!, now you know the hard way, you deserve
a break.

```
attributetype ( 1.1.2.1.1 
    NAME 'mxriscLeader' 
    DESC 'Pointer to the team leader DN not the manager.' 
    EQUALITY distinguishedNameMatch 
    SUBSTR caseIgnoreSubstringsMatch 
    SYNTAX 1.3.6.1.4.1.1466.115.121.1.12 
    SINGLE-VALUE 
 )

objectclass ( 1.1.2.2.1 
    NAME 'mxriscEmployee' 
    DESC 'mxRISC customized accounts' 
    SUP inetOrgPerson 
    STRUCTURAL 
    MAY (c $ mxriscLeader) 
 )

objectclass ( 1.1.2.2.2 
    NAME 'mxriscCustomer' 
    DESC 'mxRISC customers with access from the internet.' 
    SUP inetOrgPerson 
    STRUCTURAL 
    MUST(c) 
 )

objectclass ( 1.1.2.2.3 
    NAME 'mxriscSystem' 
    DESC 'mxRISC applications and infrastructure.' 
    SUP posixAccount 
    AUXILIAR 
    MAY (c) 
 )
```


## Testing changes

### Organization structure changes.
After creating the container you can use the ldapsearch command to retrieve all
the new created containers.

The following two commands will retrieve the organization and
organizationalUnit containers and their descriptions.

```
$ ldapsearch \ 
    -x -H ldap://openldap.mxrisc.com -b "dc=mxrisc,dc=com" -D "cn=admin,dc=mxrisc,dc=com" -w admin-password  \
    objectclass=organization dn description

```
$ ldapsearch \ 
    -x -H ldap://openldap.mxrisc.com -b "dc=mxrisc,dc=com" -D "cn=admin,dc=mxrisc,dc=com" -w admin-password  \
    objectclass=organizationalUnit dn description
```

### Schema Changes
To verify the schema has the changes after aplying the ```LDIF``` generated
file to it, use the following command.

```
$ ldapsearch \
    -x -H ldap://openldap.mxrisc.com -b "cn=Subschema" -D "cn=admin,dc=mxrisc,dc=com" -s base -w admin-password \ 
    '(&(objectclass=subschema))' objectClasses
```
It show the following output:

```
...
attributeTypes: ( 1.1.2.1.1 NAME 'mxriscLeader' DESC 'Pointer to the team lead
 er DN not the manager.' EQUALITY distinguishedNameMatch SUBSTR caseIgnoreSubs
 tringsMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.12 SINGLE-VALUE )
...
objectClasses: ( 1.1.2.2.1 NAME 'mxriscEmployee' DESC 'mxRISC customized accou
 nts' SUP account STRUCTURAL MUST cn MAY ( manager $ mxriscLeader ) )

# search result
search: 2
result: 0 Success

# numResponses: 2
# numEntries: 1
```

### Account Creation

For account creation validation we only need to check if the new account exists in the directory and that it is of the expected object class ```mxriscEmployee```. the fo

```
$ ldapsearch \
    -x -H ldap://openldap.mxrisc.com -b "dc=mxrisc,dc=com" -D "cn=admin,dc=mxrisc,dc=com" -w admin-password \
    '(objectclass=mxriscEmployee)'
```

The output will be as:

````
# elazaro, internal-users, mxrisc.com
dn: cn=elazaro,o=internal-users,dc=mxrisc,dc=com
objectClass: account
objectClass: mxriscEmployee
cn: elazaro
uid: 5001

# search result
search: 2
result: 0 Success

# numResponses: 2
# numEntries: 1
```

### Schema modification.

Once you've modified the mxriscEmployee objectClass you can verify the
description matches the changes using the following command.

```
$ docker container exec -it <<container-id>> ldapsearch -Y EXTERNAL -b "cn=schema,cn=config" -H ldapi:///  '(cn=*mxrisc)'
```

The output must be as follows:

```
# {9}mxrisc, schema, config
dn: cn={9}mxrisc,cn=schema,cn=config
objectClass: olcSchemaConfig
cn: {9}mxrisc
olcAttributeTypes: {0}( 1.1.2.1.1 NAME 'mxriscLeader' DESC 'Pointer to the tea
 m leader DN not the manager.' EQUALITY distinguishedNameMatch SUBSTR caseIgno
 reSubstringsMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.12 SINGLE-VALUE )
olcObjectClasses: {0}( 1.1.2.2.1 NAME 'mxriscEmployee' DESC 'mxRISC customized
  accounts' SUP inetOrgPerson STRUCTURAL MUST cn MAY ( c $ mxriscLeader ) )
```

You can see how SUP is not inetOrgPerson and MAY attributes are c and
mxriscLeader which is correct.

## Troubleshooting


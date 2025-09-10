# HCP Lab Activity 3

For this lab activity, I'm using the ```docker container exec``` command, this way  

## Reading the default Role.

```
$ docker container exec \
    -e "VAULT_TOKEN=<<root_token>>" \
    -e "VAULT_ADDR=https://vault.mxrisc.com:443" \
    -e "VAULT_CACERT=/vault/config/mxrisc_certification_chain.pem" \
    <<container-id>> \ 
    vault read auth/oidc/role/default
```

The above listed command receives four arguments, the ```-e``` are inteded to
set the runtime variables for the vault command to work in the provided
laboratory environment.

<!-- The ```-it ``` options are for capturing the STDIN and to attach a pseudo-TTY
to the command, as we are not using a shell, it's not needed.-->

The command that will be executed within the container is the following one:

```
vault read auth/oidc/role/default
```

It reads the default role in the auth/oidc/role path and returns (in my
scenario) an output as follows:

```
Key                        Value
---                        -----
allowed_redirect_uris      [http://vault.mxrisc.com/ui/vault/auth/oidc/oidc/callback http://vault.mxrisc.com/oidc/callback]
bound_audiences            <nil>
bound_claims               <nil>
bound_claims_type          string
bound_subject              n/a
claim_mappings             <nil>
clock_skew_leeway          0
expiration_leeway          0
groups_claim               n/a
max_age                    0
not_before_leeway          0
oidc_scopes                <nil>
policies                   [default]
role_type                  oidc
token_bound_cidrs          []
token_explicit_max_ttl     0s
token_max_ttl              0s
token_no_default_policy    false
token_num_uses             0
token_period               0s
token_policies             [default]
token_ttl                  0s
token_type                 default
user_claim                 sub
user_claim_json_pointer    false
verbose_oidc_logging       false
```

The purpose of this activity is to fix the allowed_redirect_uris for the OIDC
login flow to work properly as at this point, Vault is configured to expose its
services through a TLS/SSL enabled listener.

The current role allowed_redirect_uris is set to allow non https endpoints, so
we need to change that to make Vault OIDC authentication work properly.

With the role configured as shown before an error is returned while trying to
login to Vault using Keycloak as Authorization server. 

![If TLS is set in Vault, but not as an allowed redirect url, this error is shown](https://github.com/elazaro/identity-based-security-lab/blob/main/activities/imgs/3.0 Sign-to-OIDC-Failure.png?raw=true)

## Write changes to the Role.

```
$ docker container exec \
    -e "VAULT_TOKEN=<<root_token>>" \
    -e "VAULT_ADDR=https://vault.mxrisc.com:443" \
    -e "VAULT_CACERT=/vault/config/mxrisc_certification_chain.pem" \
    <<container-id>> \ 
    vault write auth/oidc/role/default \
        allowed_redirect_uris="https://vault.mxrisc.com/ui/vault/auth/oidc/oidc/callback" \
        allowed_redirect_uris="https://vault.mxrisc.com/oidc/callback" \
```

In this case we used the write command rather than the read one as we are
modifying the object in the target path.

The ```allowed_redirect_uris``` parameter with override the existing values replacing
the old values with the new ones.

The output returned by the command should be:

```
Success! Data written to: auth/oidc/role/default
```

Finally, after the change was pushed to the role, reading the object back from
vault must show the proper URLs set.

```
Key                        Value
---                        -----
allowed_redirect_uris      [https://vault.mxrisc.com/ui/vault/auth/oidc/oidc/callback https://vault.mxrisc.com/oidc/callback]
bound_audiences            <nil>
...
```

Once the object was fixed, we can use Keycloak to authenticate to vault by
selecting the OIDC authentication Method, this option will redirect us to the
Keycloak authentication screen and once a correct authentication is performed
and authorized, Keycloack will bring us back to Vault showing the granted
resources.

![OIDC Selection](https://github.com/elazaro/identity-based-security-lab/blob/main/activities/imgs/3.1 OIDC Selection.png?raw=true)

![Vault User Menu](https://github.com/elazaro/identity-based-security-lab/blob/main/activities/imgs/3.2 Authenticated Vault.png?raw=true)

There's another activity for restricting and creating accounts with limited
resources available in Vault.

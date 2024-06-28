# Loris Base Image

Loris installed without MRI Module.


## ENV Vars

### Build Args

- LORIS_SOURCE: Source for Loris install, either "release" or "git"
  - "release": Uses LORIS_VERSION to download release tarball and install
  - "git": Clones Loris repo and installs from HEAD

- LORIS_VERSION: Version for install when using LORIS_SOURCE="release"
  - Default: "25.0.2"

- LORIS_VERSION_TAG: "v${LORIS_VERSION}"

### Install

- PROJECT_NAME: Name of apache config files, as well as included in data directory path.
  - Default: 'loris'

- TZ: Timezone. 
  - Default: 'America/New_York'

### Runtime Config

**Database Config**
- MYSQL_HOST
- MYSQL_DATABASE
- MYSQL_USER
- MYSQL_PASSWORD_FILE: Using docker-compose secrets to mount password file. Should be set to /run/secrets/<secret_name>
- MYSQL_ROOT_PASSWORD_FILE

**Loris Runtime Config**
- LORIS_ADMIN_USER
- LORIS_ADMIN_PASSWORD_FILE: Using docker-compose secrets, e.g. /run/secrets/<secret_name>
- LORIS_EMAIL: Email address from which to send administrative emails.
  - TODO: Set up using msmtp and SMTP credentials.

- LORIS_HOST
- LORIS_PORT

**Special Variables**
- DEBUG_CONTAINER: Set to 1 or 0. If 1, do not run Loris install script, simply start container. Used to debug install process.


### Post-Install Study Site Database Set-up

- SITE_NAME
- SITE_ALIAS
- MRI_ALIAS
- STUDY_SITE_YN
- VISIT_LABEL
- WINDOW_MIN_DAYS
- WINDOW_MAX_DAYS
- OPTIMUM_MIN_DAYS
- OPTIMUM_MAX_DAYS
- WINDOW_MIDPOINT_DAYS
- VISIT_LABEL


### TODO

PSCID Set-Up

- in config.xml

```xml
<PSCID> 
    <generation>user</generation> 
    <structure>
        <seq type="alphanumeric" length="2"/>
    </structure>
</PSCID>
```

**Project**

```sql
INSERT INTO Project (Name, recruitmentTarget) VALUES('%PROJECT_NAME%', NULL);
```

**Sites**

```sql
INSERT INTO psc (Name, Alias, MRI_alias, Study_site) VALUES ('Montreal','MTL','MTL','Y');
```



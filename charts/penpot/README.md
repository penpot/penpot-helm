# penpot

![Version: 0.36.0-unreleased](https://img.shields.io/badge/Version-0.36.0--unreleased-informational?style=flat-square) ![AppVersion: 2.13.3](https://img.shields.io/badge/AppVersion-2.13.3-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

Helm chart for Penpot, the Open Source design and prototyping platform.

## What is Penpot

Penpot is the first **open-source** design tool for design and code collaboration. Designers can create stunning designs, interactive prototypes, design systems at scale, while developers enjoy ready-to-use code and make their workflow easy and fast. And all of this with no handoff drama.

Penpot is available on browser and [self host](https://penpot.app/self-host). It’s web-based and works with open standards (SVG, CSS and HTML). And last but not least, it’s free!

## Prerequisites

Penpot requires the following external services to be available before installing the chart:

- **PostgreSQL** (v15 or higher recommended): Penpot uses PostgreSQL as its primary database for storing all application data (users, projects, files, etc.). You must have a running PostgreSQL instance accessible from the Kubernetes cluster.
- **Valkey** (or a compatible Redis® instance): Penpot uses Valkey as an in-memory data store for caching, session management and real-time communication between components. You must have a running Valkey (or Redis®) instance accessible from the Kubernetes cluster.

### How to provision PostgreSQL and Valkey

Here are some recommended methods to set up these dependencies:

#### PostgreSQL

| Method | Description |
|--------|-------------|
| **Bitnami Helm Chart** | Deploy PostgreSQL in the same Kubernetes cluster using the [Bitnami PostgreSQL chart](https://artifacthub.io/packages/helm/bitnami/postgresql). Quick setup: `helm install my-postgresql oci://registry-1.docker.io/bitnamicharts/postgresql --set auth.username=penpot --set auth.password=penpot --set auth.database=penpot` |
| **CloudNativePG Operator** | Use the [CloudNativePG](https://cloudnative-pg.io/) Kubernetes operator for production-grade PostgreSQL with automated failover, backups and high availability. |
| **Managed cloud services** | Use a managed PostgreSQL service from your cloud provider: [Amazon RDS for PostgreSQL](https://aws.amazon.com/rds/postgresql/), [Azure Database for PostgreSQL](https://azure.microsoft.com/products/postgresql/), [Google Cloud SQL for PostgreSQL](https://cloud.google.com/sql/docs/postgres), or [DigitalOcean Managed Databases](https://www.digitalocean.com/products/managed-databases-postgresql). |
| **Docker / VM** | Run PostgreSQL on a separate server or VM outside of Kubernetes and expose it via a reachable hostname or IP. |

#### Valkey

| Method | Description |
|--------|-------------|
| **Bitnami Helm Chart** | Deploy Valkey in the same Kubernetes cluster using the [Bitnami Valkey chart](https://artifacthub.io/packages/helm/bitnami/valkey). Quick setup: `helm install my-valkey oci://registry-1.docker.io/bitnamicharts/valkey --set architecture=standalone --set auth.enabled=false` |
| **Managed cloud services** | Use a managed Redis®-compatible service: [Amazon ElastiCache for Redis](https://aws.amazon.com/elasticache/redis/), [Azure Cache for Redis](https://azure.microsoft.com/products/cache/), [Google Cloud Memorystore](https://cloud.google.com/memorystore), or [DigitalOcean Managed Redis](https://www.digitalocean.com/products/managed-databases-redis). |
| **Docker / VM** | Run Valkey (or Redis®) on a separate server or VM and expose it via a reachable hostname or IP. |

> **Note**: Penpot only requires a standalone Valkey/Redis® instance. Cluster or replication mode is not necessary.

## Installing the Chart

To install the chart with the release name `my-release`:

```console
$ helm repo add penpot http://helm.penpot.app
$ helm install my-release penpot/penpot
```

To customize the installation, you can specify each parameter by passing the argument `--set key=value[,key=value]` in the `helm install` command.

Provide the connection details of your PostgreSQL and Valkey instances during installation, For example,
```
helm install my-release \
  --set config.postgresql.host=<your-postgresql-host> \
  --set config.postgresql.port=5432 \
  --set config.postgresql.database=penpot \
  --set config.postgresql.username=penpot \
  --set config.postgresql.password=<your-postgresql-password> \
  --set config.redis.host=<your-valkey-host> \
  --set config.redis.port=6379 \
  --set config.redis.database=0 \
  --set persistence.assets.enabled=true \
  penpot/penpot
```
> **Note:** Replace `<your-postgresql-host>`, `<your-postgresql-password>` and `<your-valkey-host>` with the actual values of your instances.

Alternatively, a YAML file that specifies the values for the above parameters can be provided while installing the chart. For example,

```console
helm install my-release -f values.yaml penpot/penpot
```
An example values.yaml for external instances:

```yml
config:
  postgresql:
    host: "my-postgresql.example.com"
    port: 5432
    database: "penpot"
    username: "penpot"
    password: "my-secret-password"
  redis:
    host: "my-valkey.example.com"
    port: 6379
    database: "0"

persistence:
  assets:
    enabled: true
```
> **Tip**: You can use the default values.yaml

### 🔐 OpenShift Requirements

If you are deploying on OpenShift, you may need to allow the pods to run with the `anyuid` Security Context Constraint (SCC). 
You can do this with the following command:

```console
oc adm policy add-scc-to-group anyuid system:serviceaccounts:<your-namespace>
```

Replace <your-namespace> with the actual namespace, e.g. penpot.

Alternatively, if you do not want to relax this security constraint, you can configure the container to use a specific UID allowed by OpenShift by setting it explicitly in the values file.
First, get the UID range assigned to your namespace:

```console
oc get project <your-namespace> -o jsonpath='{.metadata.annotations.openshift\.io/sa\.scc\.uid-range}'
```

This will return a value like:

```console
1000700000/10000
```
From that range, you can pick a UID (e.g., 1000700000) and set it in your `values.yaml` like this:

```console
backend:
  securityContext:
    runAsUser: 1000700000

frontend:
  securityContext:
    runAsUser: 1000700000

exporter:
  securityContext:
    runAsUser: 1000700000
```

Replace `1000700000` with a valid UID from your namespace range.
This allows running the chart securely in OpenShift without granting anyuid permissions.

</details>

## Parameters

### Global

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| global.imagePullSecrets | list | `[]` | Global Docker registry secret names. E.g. imagePullSecrets:   - myRegistryKeySecretName |

### General

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| fullnameOverride | string | `""` | To fully override common.names.fullname |
| nameOverride | string | `""` | To partially override common.names.fullname |
| serviceAccount.annotations | object | `{}` | Annotations for service account. Evaluated as a template. |
| serviceAccount.enabled | bool | `true` | Specifies whether a ServiceAccount should be created. |
| serviceAccount.name | string | `"penpot"` | The name of the ServiceAccount to use. If not set and enabled is true, a name is generated using the fullname template. |

### Penpot Configuration

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| config.apiSecretKey | string | `"kmZ96pAxhTgk3HZvvBkPeVTspGBneKVLEpO_3ecORs_gwACENZ77z05zCe7skvPsQ3jI3QgkULQOWCuLjmjQsg"` | A random secret key needed for persistent user sessions. Generate with `python3 -c "import secrets; print(secrets.token_urlsafe(64))"` for example. |
| config.autoFileSnapshot.every | int | `5` | How many changes before generating a new snapshot. You also need to add the 'auto-file-snapshot' flag to the PENPOT_FLAGS variable. |
| config.autoFileSnapshot.timeout | string | `"3h"` | If there isn't a snapshot during this time, the system will generate one automatically. You also need to add the 'auto-file-snapshot' flag to the PENPOT_FLAGS variable. |
| config.existingSecret | string | `""` | The name of an existing secret. |
| config.extraEnvs | list | `[]` | Specify any additional environment values you want to provide to all the containers (frontend, backend and exporter) in the deployment according to the [specification](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#environment-variables) |
| config.fileDataBackend | string | `"legacy-db"` | Define the strategy (backend) for internal file data storage of Penpot. Use "legacy-db" (default) the current behaviour, "db" to use an specific table in the database (future default) and "storage" to use the predefined objects storage system (S3, file system,...) |
| config.flags | string | `"enable-registration enable-login-with-password disable-email-verification enable-smtp"` | The feature flags to enable. Check [the official docs](https://help.penpot.app/technical-guide/configuration/) for more info. |
| config.internalResolver | string | `""` | Add custom resolver for frontend. e.g. 192.168.1.1 |
| config.objectsStorage.filesystem.directory | string | `"/opt/data/assets"` | The storage directory to use if you chose the filesystem storage backend. |
| config.objectsStorage.s3.accessKeyID | string | `""` | The S3 access key ID to use if you chose the S3 storage backend. |
| config.objectsStorage.s3.bucket | string | `""` | The name of the S3 bucket to use if you chose the S3 storage backend. |
| config.objectsStorage.s3.endpointURI | string | `""` | The S3 endpoint URI to use if you chose the S3 storage backend. |
| config.objectsStorage.s3.existingSecret | string | `""` | The name of an existing secret. |
| config.objectsStorage.s3.region | string | `""` | The S3 region to use if you chose the S3 storage backend. |
| config.objectsStorage.s3.secretAccessKey | string | `""` | The S3 secret access key to use if you chose the S3 storage backend. |
| config.objectsStorage.s3.secretKeys.accessKeyIDKey | string | `""` | The S3 access key ID to use from an existing secret. |
| config.objectsStorage.s3.secretKeys.endpointURIKey | string | `""` | The S3 endpoint URI to use from an existing secret. |
| config.objectsStorage.s3.secretKeys.secretAccessKey | string | `""` | The S3 secret access key to use from an existing secret. |
| config.objectsStorage.storageBackend | string | `"fs"` | The storage backend for different objects (assets, old data...) to use. Use `fs` for filesystem, and `s3` for S3. |
| config.postgresql.database | string | `"penpot"` | The PostgreSQL database to use. |
| config.postgresql.existingSecret | string | `""` | The name of an existing secret. |
| config.postgresql.host | string | `""` | The PostgreSQL host to connect to. Empty to use dependencies. |
| config.postgresql.password | string | `"penpot"` | The database password to use. |
| config.postgresql.port | int | `5432` | The PostgreSQL host port to use. |
| config.postgresql.secretKeys.passwordKey | string | `""` | The password key to use from an existing secret. |
| config.postgresql.secretKeys.postgresqlUriKey | string | `""` | The postgresql uri key to use from an existing secret. (postgresql://host:port/database). |
| config.postgresql.secretKeys.usernameKey | string | `""` | The username key to use from an existing secret. |
| config.postgresql.username | string | `"penpot"` | The database username to use. |
| config.privacyPolicyUri | string | `""` | Url adress to Privacy Policy (empty to hide the link) |
| config.providers.existingSecret | string | `""` | The name of an existing secret to use. |
| config.providers.github.clientID | string | `""` | The GitHub client ID to use. |
| config.providers.github.clientSecret | string | `""` | The GitHub client secret to use. |
| config.providers.github.enabled | bool | `false` | Whether to enable GitHub configuration. To enable GitHub auth, also add `enable-login-with-github` to the flags. |
| config.providers.gitlab.baseURI | string | `"https://gitlab.com"` | The GitLab base URI to use. |
| config.providers.gitlab.clientID | string | `""` | The GitLab client ID to use. |
| config.providers.gitlab.clientSecret | string | `""` | The GitLab client secret to use. |
| config.providers.gitlab.enabled | bool | `false` | Whether to enable GitLab configuration. To enable GitLab auth, also add `enable-login-with-gitlab` to the flags. |
| config.providers.google.clientID | string | `""` | The Google client ID to use. To enable Google auth, add `enable-login-with-google` to the flags. |
| config.providers.google.clientSecret | string | `""` | The Google client secret to use. To enable Google auth, add `enable-login-with-google` to the flags. |
| config.providers.google.enabled | bool | `false` | Whether to enable Google configuration. To enable Google auth, add `enable-login-with-google` to the flags. |
| config.providers.ldap.attributesEmail | string | `"mail"` | The LDAP attributes email to use. |
| config.providers.ldap.attributesFullname | string | `"cn"` | The LDAP attributes fullname to use. |
| config.providers.ldap.attributesPhoto | string | `"jpegPhoto"` | The LDAP attributes photo format to use. |
| config.providers.ldap.attributesUsername | string | `"uid"` | The LDAP attributes username to use. |
| config.providers.ldap.baseDN | string | `"ou=people,dc=planetexpress,dc=com"` | The LDAP base DN to use. |
| config.providers.ldap.bindDN | string | `"uid=admin,ou=people,dc=planetexpress,dc=com"` | The LDAP bind DN to use. |
| config.providers.ldap.bindPassword | string | `"GoodNewsEveryone"` | The LDAP bind password to use. |
| config.providers.ldap.enabled | bool | `false` | Whether to enable LDAP configuration. To enable LDAP, also add `enable-login-with-ldap` to the flags. |
| config.providers.ldap.host | string | `"ldap"` | The LDAP host to use. |
| config.providers.ldap.port | int | `10389` | The LDAP port to use. |
| config.providers.ldap.ssl | bool | `false` | Whether to use SSL for the LDAP connection. |
| config.providers.ldap.startTLS | bool | `false` | Whether to utilize StartTLS for the LDAP connection. |
| config.providers.ldap.userQuery | string | `"(&(|(uid=:username)(mail=:username))(memberOf=cn=penpot,ou=groups,dc=my-domain,dc=com))"` | The LDAP user query to use. |
| config.providers.oidc.authURI | string | `""` | Optional OpenID Connect auth URI to use. Auto discovered if not provided. |
| config.providers.oidc.baseURI | string | `""` | The OpenID Connect base URI to use. |
| config.providers.oidc.clientID | string | `""` | The OpenID Connect client ID to use. |
| config.providers.oidc.clientSecret | string | `""` | The OpenID Connect client secret to use. |
| config.providers.oidc.emailAttribute | string | `""` | Optional OpenID Connect email attribute to use. If not provided, the `email` prop will be used. |
| config.providers.oidc.enabled | bool | `false` | Whether to enable OIDC configuration. To enable OpenID Connect auth, also add `enable-login-with-oidc` to the flags. |
| config.providers.oidc.nameAttribute | string | `""` | Optional OpenID Connect name attribute to use. If not provided, the `name` prop will be used. |
| config.providers.oidc.roles | string | `"designer developer"` | Optional OpenID Connect roles to use. If no role is provided, role checking is  disabled (default role values are set below, to disable role verification, send an empty string). |
| config.providers.oidc.rolesAttribute | string | `""` | Optional OpenID Connect roles attribute to use. If not provided, the role checking will be disabled. |
| config.providers.oidc.scopes | string | `"scope1 scope2"` | Optional OpenID Connect scopes to use. These settings allow overwriting the required scopes, use with caution because penpot requires at least `name` and `email` attrs found on the user info. Optional, defaults to `openid profile`. |
| config.providers.oidc.tokenURI | string | `""` | Optional OpenID Connect token URI to use. Auto discovered if not provided. |
| config.providers.oidc.userURI | string | `""` | Optional OpenID Connect user URI to use. Auto discovered if not provided. |
| config.providers.secretKeys.githubClientIDKey | string | `""` | The GitHub client ID key to use from an existing secret. |
| config.providers.secretKeys.githubClientSecretKey | string | `""` | The GitHub client secret key to use from an existing secret. |
| config.providers.secretKeys.gitlabClientIDKey | string | `""` | The GitLab client ID key to use from an existing secret. |
| config.providers.secretKeys.gitlabClientSecretKey | string | `""` | The GitLab client secret key to use from an existing secret. |
| config.providers.secretKeys.googleClientIDKey | string | `""` | The Google client ID key to use from an existing secret. |
| config.providers.secretKeys.googleClientSecretKey | string | `""` | The Google client secret key to use from an existing secret. |
| config.providers.secretKeys.ldapBindPasswordKey | string | `""` | The LDAP admin bind password to use from an exsiting secret |
| config.providers.secretKeys.oidcClientIDKey | string | `""` | The OpenID Connect client ID key to use from an existing secret. |
| config.providers.secretKeys.oidcClientSecretKey | string | `""` | The OpenID Connect client secret key to use from an existing secret. |
| config.publicUri | string | `"http://penpot.example.com"` | The public domain to serve Penpot on. **IMPORTANT:** Set `disable-secure-session-cookies` in the flags if you plan on serving it on a non HTTPS domain. |
| config.redis.database | string | `"0"` | The Valkey database to connect to. |
| config.redis.existingSecret | string | `""` | The name of an existing secret. |
| config.redis.host | string | `""` | The Valkey host to connect to. Empty to use dependencies |
| config.redis.port | int | `6379` | The Valkey host port to use. |
| config.redis.secretKeys.redisUriKey | string | `""` | The redis uri key to use from an existing secret. (redis://:password@host:port/database). |
| config.registrationDomainWhitelist | string | `""` | Comma separated list of allowed domains to register. Empty to allow all domains. |
| config.secretKeys.apiSecretKey | string | `""` | The api secret key to use from an existing secret. |
| config.smtp.defaultFrom | string | `""` | The SMTP default email to send from. |
| config.smtp.defaultReplyTo | string | `""` | The SMTP default email to reply to. |
| config.smtp.enabled | bool | `false` | Whether to enable SMTP configuration. You also need to add the 'enable-smtp' flag to the PENPOT_FLAGS variable. |
| config.smtp.existingSecret | string | `""` | The name of an existing secret. |
| config.smtp.host | string | `""` | The SMTP host to use. |
| config.smtp.password | string | `""` | The SMTP password to use. |
| config.smtp.port | string | `""` | The SMTP host port to use. |
| config.smtp.secretKeys.passwordKey | string | `""` | The SMTP password to use from an existing secret. |
| config.smtp.secretKeys.usernameKey | string | `""` | The SMTP username to use from an existing secret. |
| config.smtp.ssl | bool | `false` | Whether to use SSL for the SMTP connection. |
| config.smtp.tls | bool | `true` | Whether to use TLS for the SMTP connection. |
| config.smtp.username | string | `""` | The SMTP username to use. |
| config.telemetryEnabled | bool | `true` | Whether to enable sending of anonymous telemetry data. |
| config.termsOfServicesUri | string | `""` | Url adress to Terms of Services (empty to hide the link) |

### Penpot backend

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| backend.affinity | object | `{}` | Affinity for Penpot pods assignment. Check [the official doc](https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#affinity-and-anti-affinity) |
| backend.containerSecurityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["all"]},"readOnlyRootFilesystem":false,"runAsNonRoot":true,"runAsUser":1001}` | Configure Container Security Context. Check [the official doc](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-pod) |
| backend.deploymentAnnotations | object | `{}` | An optional map of annotations to be applied to the controller Deployment |
| backend.extraEnvs | list | `[]` | Specify any additional environment values you want to provide to the backend container in the deployment according to the [specification](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#environment-variables) |
| backend.image.pullPolicy | string | `"IfNotPresent"` | The image pull policy to use. |
| backend.image.repository | string | `"penpotapp/backend"` | The Docker repository to pull the image from. |
| backend.image.tag | string | `"2.13.3"` | The image tag to use. |
| backend.nodeSelector | object | `{}` | Node labels for Penpot pods assignment. Check [the official doc](https://kubernetes.io/docs/user-guide/node-selection/) |
| backend.pdb | object | `{"enabled":false,"maxUnavailable":null,"minAvailable":null}` | Configure Pod Disruption Budget for the backend pods. Check [the official doc](https://kubernetes.io/docs/tasks/run-application/configure-pdb/) |
| backend.pdb.enabled | bool | `false` | Enable Pod Disruption Budget for the backend pods. |
| backend.pdb.maxUnavailable | int,string | `nil` | The number or percentage of pods from that set that can be unavailable after the eviction (e.g.: 3, "10%"). |
| backend.pdb.minAvailable | int,string | `nil` | The number or percentage of pods from that set that must still be available after the eviction (e.g.: 3, "10%"). |
| backend.podAnnotations | object | `{}` | An optional map of annotations to be applied to the controller Pods |
| backend.podLabels | object | `{}` | An optional map of labels to be applied to the controller Pods |
| backend.podSecurityContext | object | `{"fsGroup":1001}` | Configure Pods Security Context. Check [the official doc](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-pod) |
| backend.replicaCount | int | `1` | The number of replicas to deploy. |
| backend.resources | object | `{"limits":{},"requests":{}}` | Penpot backend resource requests and limits. Check [the official doc](https://kubernetes.io/docs/user-guide/compute-resources/) |
| backend.resources.limits | object | `{}` | The resources limits for the Penpot backend containers |
| backend.resources.requests | object | `{}` | The requested resources for the Penpot backend containers |
| backend.service.annotations | object | `{}` | Mapped annotations for the backend service |
| backend.service.port | int | `6060` | The http service port to use. |
| backend.service.type | string | `"ClusterIP"` | The http service type to create. |
| backend.startupProbe | object | `{"failureThreshold":30,"httpGet":{"path":"/readyz","port":"http"},"periodSeconds":10}` | Startup probe for the Penpot backend containers. Tolerates up to 30 * 10 = 300 seconds = 5 Minutes. Check [the official doc](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/#define-startup-probes) |
| backend.tolerations | list | `[]` | Tolerations for Penpot pods assignment. Check [the official doc](https://kubernetes.io/docs/concepts/configuration/taint-and-toleration/) |
| backend.volumeMounts | list | `[]` | Extra volumes to be mounted in the countainer. Check [the official doc](https://kubernetes.io/docs/concepts/storage/volumes/) |
| backend.volumes | list | `[]` | Extra volumes to be made available. Check [the official doc](https://kubernetes.io/docs/concepts/storage/volumes/) |

### Penpot Frontend

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| frontend.affinity | object | `{}` | Affinity for Penpot pods assignment. Check [the official doc](https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#affinity-and-anti-affinity) |
| frontend.containerSecurityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["all"]},"readOnlyRootFilesystem":false,"runAsNonRoot":true,"runAsUser":1001}` | Configure Container Security Context. Check [the official doc](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-pod) |
| frontend.deploymentAnnotations | object | `{}` | An optional map of annotations to be applied to the controller Deployment |
| frontend.extraEnvs | list | `[]` | Specify any additional environment values you want to provide to the frontend container in the deployment according to the [specification](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#environment-variables) |
| frontend.image.pullPolicy | string | `"IfNotPresent"` | The image pull policy to use. |
| frontend.image.repository | string | `"penpotapp/frontend"` | The Docker repository to pull the image from. |
| frontend.image.tag | string | `"2.13.3"` | The image tag to use. |
| frontend.nodeSelector | object | `{}` | Node labels for Penpot pods assignment. Check [the official doc](https://kubernetes.io/docs/user-guide/node-selection/) |
| frontend.pdb | object | `{"enabled":false,"maxUnavailable":null,"minAvailable":null}` | Configure Pod Disruption Budget for the frontend pods. Check [the official doc](https://kubernetes.io/docs/tasks/run-application/configure-pdb/) |
| frontend.pdb.enabled | bool | `false` | Enable Pod Disruption Budget for the frontend pods. |
| frontend.pdb.maxUnavailable | int,string | `nil` | The number or percentage of pods from that set that can be unavailable after the eviction (e.g.: 3, "10%"). |
| frontend.pdb.minAvailable | int,string | `nil` | The number or percentage of pods from that set that must still be available after the eviction (e.g.: 3, "10%"). |
| frontend.podAnnotations | object | `{}` | An optional map of annotations to be applied to the controller Pods |
| frontend.podLabels | object | `{}` | An optional map of labels to be applied to the controller Pods |
| frontend.podSecurityContext | object | `{"fsGroup":1001}` | Configure Pods Security Context. Check [the official doc](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-pod) |
| frontend.replicaCount | int | `1` | The number of replicas to deploy. |
| frontend.resources | object | `{"limits":{},"requests":{}}` | Penpot frontend resource requests and limits. Check [the official doc](https://kubernetes.io/docs/user-guide/compute-resources/) |
| frontend.resources.limits | object | `{}` | The resources limits for the Penpot frontend containers |
| frontend.resources.requests | object | `{}` | The requested resources for the Penpot frontend containers |
| frontend.service.annotations | object | `{}` | Mapped annotations for the frontend service |
| frontend.service.port | int | `8080` | The service port to use. |
| frontend.service.type | string | `"ClusterIP"` | The service type to create. |
| frontend.tolerations | list | `[]` | Tolerations for Penpot pods assignment. Check [the official doc](https://kubernetes.io/docs/concepts/configuration/taint-and-toleration/) |
| frontend.volumeMounts | list | `[]` | Extra volumes to be mounted in the countainer. Check [the official doc](https://kubernetes.io/docs/concepts/storage/volumes/) |
| frontend.volumes | list | `[]` | Extra volumes to be made available. Check [the official doc](https://kubernetes.io/docs/concepts/storage/volumes/) |

### Penpot exporter

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| exporter.affinity | object | `{}` | Affinity for Penpot pods assignment. Check [the official doc](https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#affinity-and-anti-affinity) |
| exporter.containerSecurityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["all"]},"readOnlyRootFilesystem":false,"runAsNonRoot":true,"runAsUser":1001}` | Configure Container Security Context. Check [the official doc](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-pod) |
| exporter.deploymentAnnotations | object | `{}` | An optional map of annotations to be applied to the controller Deployment |
| exporter.extraEnvs | list | `[]` | Specify any additional environment values you want to provide to the exporter container in the deployment according to the [specification](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#environment-variables) |
| exporter.image.imagePullPolicy | string | `"IfNotPresent"` | The image pull policy to use. |
| exporter.image.repository | string | `"penpotapp/exporter"` | The Docker repository to pull the image from. |
| exporter.image.tag | string | `"2.13.3"` | The image tag to use. |
| exporter.nodeSelector | object | `{}` | Node labels for Penpot pods assignment. Check [the official doc](https://kubernetes.io/docs/user-guide/node-selection/) |
| exporter.pdb | object | `{"enabled":false,"maxUnavailable":null,"minAvailable":null}` | Configure Pod Disruption Budget for the exporter pods. Check [the official doc](https://kubernetes.io/docs/tasks/run-application/configure-pdb/) |
| exporter.pdb.enabled | bool | `false` | Enable Pod Disruption Budget for the exporter pods. |
| exporter.pdb.maxUnavailable | int,string | `nil` | The number or percentage of pods from that set that can be unavailable after the eviction (e.g.: 3, "10%"). |
| exporter.pdb.minAvailable | int,string | `nil` | The number or percentage of pods from that set that must still be available after the eviction (e.g.: 3, "10%"). |
| exporter.podAnnotations | object | `{}` | An optional map of annotations to be applied to the controller Pods |
| exporter.podLabels | object | `{}` | An optional map of labels to be applied to the controller Pods |
| exporter.podSecurityContext | object | `{"fsGroup":1001}` | Configure Pods Security Context. Check [the official doc](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-pod) |
| exporter.replicaCount | int | `1` | The number of replicas to deploy. Enable persistence.exporter if you use more than 1 replicaCount |
| exporter.resources | object | `{"limits":{},"requests":{}}` | Penpot frontend resource requests and limits. Check [the official doc](https://kubernetes.io/docs/user-guide/compute-resources/) |
| exporter.resources.limits | object | `{}` | The resources limits for the Penpot frontend containers |
| exporter.resources.requests | object | `{}` | The requested resources for the Penpot frontend containers |
| exporter.service.annotations | object | `{}` | Mapped annotations for the exporter service |
| exporter.service.port | int | `6061` | The service port to use. |
| exporter.service.type | string | `"ClusterIP"` | The service type to create. |
| exporter.tolerations | list | `[]` | Tolerations for Penpot pods assignment. Check [the official doc](https://kubernetes.io/docs/concepts/configuration/taint-and-toleration/) |
| exporter.volumeMounts | list | `[]` | Extra volumes to be mounted in the countainer. Check [the official doc](https://kubernetes.io/docs/concepts/storage/volumes/) |
| exporter.volumes | list | `[]` | Extra volumes to be made available. Check [the official doc](https://kubernetes.io/docs/concepts/storage/volumes/) |

### Persistence

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| persistence.assets.accessModes | list | `["ReadWriteOnce"]` | Penpot objects persistent Volume access modes. |
| persistence.assets.annotations | object | `{}` | Penpot objects persistent Volume Claim annotations. |
| persistence.assets.enabled | bool | `true` | Enable Penpot objects persistence using Persistent Volume Claims. |
| persistence.assets.existingClaim | string | `""` | The name of an existing PVC to use for Penpot objects persistence. |
| persistence.assets.size | string | `"20Gi"` | Penpot objects persistent Volume size. |
| persistence.assets.storageClass | string | `""` | Penpot objects persistent Volume storage class. If defined, storageClassName: <storageClass>. If undefined (the default) or set to null, no storageClassName spec is set, choosing the default provisioner. |
| persistence.exporter.accessModes | list | `["ReadWriteOnce"]` | Exporter persistent Volume access modes. |
| persistence.exporter.annotations | object | `{}` | Exporter persistent Volume Claim annotations. |
| persistence.exporter.enabled | bool | `false` | Enable exporter persistence using Persistent Volume Claims. If exporter.replicaCount you have to enable it. |
| persistence.exporter.existingClaim | string | `""` | The name of an existing PVC to use for persistence. |
| persistence.exporter.size | string | `"10Gi"` | Exporter persistent Volume size. |
| persistence.exporter.storageClass | string | `""` | Exporter persistent Volume storage class. Empty is choosing the default provisioner by the provider. |

### Ingress

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| ingress.annotations | object | `{}` | Mapped annotations for the ingress crontroller. E.g. annotations:   kubernetes.io/ingress.class: nginx   kubernetes.io/tls-acme: "true" |
| ingress.className | string | `""` | The Ingress className. |
| ingress.enabled | bool | `false` | Enable (frontend) Ingress Controller. |
| ingress.hosts | list | `["penpot.example.com"]` | Array style hosts for the (frontend) ingress crontroller. |
| ingress.hosts[0] | string | `"penpot.example.com"` | The default external hostname to access to the penpot app. |
| ingress.path | string | `"/"` | Root path for every hosts. |
| ingress.tls | list | `[]` | Array style TLS secrets for the (frontend) ingress crontroller. E.g. tls:   - secretName: penpot.example.com-tls     hosts:       - penpot.example.com |

### Reute (for OpenShift Container Platform)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| route.annotations | object | `{}` | An optional map of annotations to be applied to the route. |
| route.enabled | bool | `false` | Enable Openshift/OKD Route. Check [the official doc](https://docs.openshift.com/container-platform/4.16/networking/routes/route-configuration.html). When it is enabled, all fsGroup and runAsUser must be changed to null. |
| route.host | string | `"penpot.example.com"` | The default external hostname to access to the penpot app. |
| route.path | string | `nil` | Define a path to use Path-based routes. |
| route.tls | object | `{}` | A Map with TLS configuration for the route. E.g. tls:   terminationType: edge   terminationPolicy: Redirect |
| route.wildcardPolicy | string | `"None"` | Define the wildcard policy (None, Subdomain, ...) |

## Upgrading

### To 0.29.0

Penpot 2.11 is implementing a more complex storage system (not just for store assets). To do this, it has changed the names of some environment variables, and we should apply the same nomenclature.

The changes to be made if you have modified `config.assets` are:

- `config.assets` must be `config.objetsStorage`.
- Value for `config.objetsStorage.storageBackend` must be changed from `assets-fs` or `assets-s3` to `fs` or `s3` respectively.

For example, if you use this file to set up your penpot instance

```yml
# values.local.yaml
# (...)

config:
  #(...)

  assets:
    storageBackend: "assets-s3"
    s3:
      accessKeyID: "my-access-key-id"
      secretAccessKey: "my-secret-key"
      region: "eu-west1"
      bucket: "penpot-assets"

# (...)
```

you must exchange it for this one:

```yml
# values.local.yaml
# (...)

config:
  #(...)

  objectsStorage:           # <- Changed
    storageBackend: "s3"    # <- Changed
    s3:
      accessKeyID: "my-access-key-id"
      secretAccessKey: "my-secret-key"
      region: "eu-west1"
      bucket: "penpot-assets"

# (...)
```

### To 0.23.0

Since Penpot 2.8, Penpot has migrated from Redis to Valkey. Although migration is recommended, Penpot will work seamlessly with compatible Redis versions for a long, long time.

Using `global.valkeyEnabled` and `global.redisEnabled` you will be able to choose which one to use.

## Resources

You can ask and answer questions, have open-ended conversations, and follow along on decisions affecting the project.

💾 [Documentation](https://help.penpot.app/technical-guide/)

🚀 [Getting Started](https://help.penpot.app/technical-guide/getting-started/)

✏️ [Tutorials](https://www.youtube.com/playlist?list=PLgcCPfOv5v54WpXhHmNO7T-YC7AE-SRsr)

🏘️ [Architecture](https://help.penpot.app/technical-guide/developer/architecture/)

📚 [Dev Diaries](https://penpot.app/dev-diaries.html)

## License ##

```
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

Copyright (c) KALEIDOS INC
```
Penpot is a Kaleidos’ [open source project](https://kaleidos.net/)

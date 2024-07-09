# penpot

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![AppVersion: 2.0.3](https://img.shields.io/badge/AppVersion-2.0.3-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

Helm chart for Penpot, the Open Source design and prototyping platform.

## Installing the Chart

To install the chart with the release name `my-release`:

```console
$ helm repo add penpot http://helm.penpot.app
$ helm install my-release penpot/penpot
```

## Values

### Backend parameters

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| backend.affinity | object | `{}` | Affinity for Penpot pods assignment. Check [the official doc](https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#affinity-and-anti-affinity) |
| backend.containerSecurityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["all"]},"enabled":true,"readOnlyRootFilesystem":false,"runAsNonRoot":true,"runAsUser":1001}` | Configure Container Security Context. Check [the official doc](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-pod) |
| backend.containerSecurityContext.allowPrivilegeEscalation | bool | `false` | Set Penpot containers' security context allowPrivilegeEscalation |
| backend.containerSecurityContext.capabilities | object | `{"drop":["all"]}` | Set Penpot containers' security context capabilities to be dropped |
| backend.containerSecurityContext.enabled | bool | `true` | Enabled Penpot containers' security context |
| backend.containerSecurityContext.readOnlyRootFilesystem | bool | `false` | Set Penpot containers' security context readOnlyRootFilesystem |
| backend.containerSecurityContext.runAsNonRoot | bool | `true` | Set Penpot container's security context runAsNonRoot |
| backend.containerSecurityContext.runAsUser | int | `1001` | Set Penpot containers' security context runAsUser |
| backend.deploymentAnnotations | object | `{}` | An optional map of annotations to be applied to the controller Deployment |
| backend.image.pullPolicy | string | `"IfNotPresent"` | The image pull policy to use. |
| backend.image.repository | string | `"penpotapp/backend"` | The Docker repository to pull the image from. |
| backend.image.tag | string | `"2.0.3"` | The image tag to use. |
| backend.nodeSelector | object | `{}` | Node labels for Penpot pods assignment. Check [the official doc](https://kubernetes.io/docs/user-guide/node-selection/) |
| backend.podAnnotations | object | `{}` | An optional map of annotations to be applied to the controller Pods |
| backend.podSecurityContext | object | `{"enabled":true,"fsGroup":1001}` | Configure Pods Security Context. Check [the official doc](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-pod) |
| backend.podSecurityContext.enabled | bool | `true` | Enabled Penpot pods' security context |
| backend.podSecurityContext.fsGroup | int | `1001` | Set Penpot pod's security context fsGroup |
| backend.replicaCount | int | `1` | The number of replicas to deploy. |
| backend.resources | object | `{"limits":{},"requests":{}}` | Penpot backend resource requests and limits. Check [the official doc](https://kubernetes.io/docs/user-guide/compute-resources/) |
| backend.resources.limits | object | `{}` | The resources limits for the Penpot backend containers |
| backend.resources.requests | object | `{}` | The requested resources for the Penpot backend containers |
| backend.service.port | int | `6060` | The http service port to use. |
| backend.service.type | string | `"ClusterIP"` | The http service type to create. |
| backend.tolerations | list | `[]` | Tolerations for Penpot pods assignment. Check [the official doc](https://kubernetes.io/docs/concepts/configuration/taint-and-toleration/) |

### Configuration parameters

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| config.apiSecretKey | string | `"kmZ96pAxhTgk3HZvvBkPeVTspGBneKVLEpO_3ecORs_gwACENZ77z05zCe7skvPsQ3jI3QgkULQOWCuLjmjQsg"` | A random secret key needed for persistent user sessions. Generate with `python3 -c "import secrets; print(secrets.token_urlsafe(64))"` for example. |
| config.assets.filesystem.directory | string | `"/opt/data/assets"` | The storage directory to use if you chose the filesystem storage backend. |
| config.assets.s3.accessKeyID | string | `""` | The S3 access key ID to use if you chose the S3 storage backend. |
| config.assets.s3.bucket | string | `""` | The name of the S3 bucket to use if you chose the S3 storage backend. |
| config.assets.s3.endpointURI | string | `""` | The S3 endpoint URI to use if you chose the S3 storage backend. |
| config.assets.s3.existingSecret | string | `""` | The name of an existing secret. |
| config.assets.s3.region | string | `""` | The S3 region to use if you chose the S3 storage backend. |
| config.assets.s3.secretAccessKey | string | `""` | The S3 secret access key to use if you chose the S3 storage backend. |
| config.assets.s3.secretKeys.accessKeyIDKey | string | `""` | The S3 access key ID to use from an existing secret. |
| config.assets.s3.secretKeys.endpointURIKey | string | `""` | The S3 endpoint URI to use from an existing secret. |
| config.assets.s3.secretKeys.secretAccessKey | string | `""` | The S3 secret access key to use from an existing secret. |
| config.assets.storageBackend | string | `"assets-fs"` | The storage backend for assets to use. Use `assets-fs` for filesystem, and `assets-s3` for S3. |
| config.flags | string | `"enable-registration enable-login-with-password disable-email-verification enable-smtp enable-prepl-server"` | The feature flags to enable. Check [the official docs](https://help.penpot.app/technical-guide/configuration/) for more info. |
| config.postgresql.database | string | `"penpot"` | The PostgreSQL database to use. |
| config.postgresql.existingSecret | string | `""` | The name of an existing secret. |
| config.postgresql.host | string | `""` | The PostgreSQL host to connect to. Empty to use dependencies. |
| config.postgresql.password | string | `"penpot"` | The database password to use. |
| config.postgresql.port | int | `5432` | The PostgreSQL host port to use. |
| config.postgresql.secretKeys.passwordKey | string | `""` | The password key to use from an existing secret. |
| config.postgresql.secretKeys.usernameKey | string | `""` | The username key to use from an existing secret. |
| config.postgresql.username | string | `"penpot"` | The database username to use. |
| config.providers | object | `{"existingSecret":"","github":{"clientID":"","clientSecret":"","enabled":false},"gitlab":{"baseURI":"https://gitlab.com","clientID":"","clientSecret":"","enabled":false},"google":{"clientID":"","clientSecret":"","enabled":false},"ldap":{"attributesEmail":"mail","attributesFullname":"cn","attributesPhoto":"jpegPhoto","attributesUsername":"uid","baseDN":"ou=people,dc=planetexpress,dc=com","bindDN":"cn=admin,dc=planetexpress,dc=com","bindPassword":"GoodNewsEveryone","enabled":false,"host":"ldap","port":10389,"ssl":false,"startTLS":false,"userQuery":"(&(|(uid=:username)(mail=:username))(memberOf=cn=penpot,ou=groups,dc=my-domain,dc=com))"},"oidc":{"authURI":"","baseURI":"","clientID":"","clientSecret":"","emailAttribute":"","enabled":false,"nameAttribute":"","roles":"role1 role2","rolesAttribute":"","scopes":"scope1 scope2","tokenURI":"","userURI":""},"secretKeys":{"githubClientIDKey":"","githubClientSecretKey":"","gitlabClientIDKey":"","gitlabClientSecretKey":"","googleClientIDKey":"","googleClientSecretKey":"","oidcClientIDKey":"","oidcClientSecretKey":""}}` | Penpot Authentication providers parameters |
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
| config.providers.ldap.bindDN | string | `"cn=admin,dc=planetexpress,dc=com"` | The LDAP bind DN to use. |
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
| config.providers.oidc.roles | string | `"role1 role2"` | Optional OpenID Connect roles to use. If no role is provided, roles checking  disabled. |
| config.providers.oidc.rolesAttribute | string | `""` | Optional OpenID Connect roles attribute to use. If not provided, the roles checking will be disabled. |
| config.providers.oidc.scopes | string | `"scope1 scope2"` | Optional OpenID Connect scopes to use. This settings allow overwrite the required scopes, use with caution because penpot requres at least `name` and `email` attrs found on the user info. Optional, defaults to `openid profile`. |
| config.providers.oidc.tokenURI | string | `""` | Optional OpenID Connect token URI to use. Auto discovered if not provided. |
| config.providers.oidc.userURI | string | `""` | Optional OpenID Connect user URI to use. Auto discovered if not provided. |
| config.providers.secretKeys.githubClientIDKey | string | `""` | The GitHub client ID key to use from an existing secret. |
| config.providers.secretKeys.githubClientSecretKey | string | `""` | The GitHub client secret key to use from an existing secret. |
| config.providers.secretKeys.gitlabClientIDKey | string | `""` | The GitLab client ID key to use from an existing secret. |
| config.providers.secretKeys.gitlabClientSecretKey | string | `""` | The GitLab client secret key to use from an existing secret. |
| config.providers.secretKeys.googleClientIDKey | string | `""` | The Google client ID key to use from an existing secret. |
| config.providers.secretKeys.googleClientSecretKey | string | `""` | The Google client secret key to use from an existing secret. |
| config.providers.secretKeys.oidcClientIDKey | string | `""` | The OpenID Connect client ID key to use from an existing secret. |
| config.providers.secretKeys.oidcClientSecretKey | string | `""` | The OpenID Connect client secret key to use from an existing secret. |
| config.publicUri | string | `"http://penpot.example.com"` | The public domain to serve Penpot on. Set `disable-secure-session-cookies` in the flags if you plan on serving it on a non HTTPS domain. |
| config.redis.database | string | `"0"` | The Redis database to connect to. |
| config.redis.host | string | `""` | The Redis host to connect to. Empty to use dependencies |
| config.redis.port | int | `6379` | The Redis host port to use. |
| config.registrationDomainWhitelist | string | `""` | Comma separated list of allowed domains to register. Empty to allow all domains. |
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

### Exporter parameters

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| exporter.affinity | object | `{}` | Affinity for Penpot pods assignment. Check [the official doc](https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#affinity-and-anti-affinity) |
| exporter.containerSecurityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["all"]},"enabled":true,"readOnlyRootFilesystem":false,"runAsNonRoot":true,"runAsUser":1001}` | Configure Container Security Context. Check [the official doc](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-pod) |
| exporter.containerSecurityContext.allowPrivilegeEscalation | bool | `false` | Set Penpot containers' security context allowPrivilegeEscalation |
| exporter.containerSecurityContext.capabilities | object | `{"drop":["all"]}` | Set Penpot containers' security context capabilities to be dropped |
| exporter.containerSecurityContext.enabled | bool | `true` | Enabled Penpot containers' security context |
| exporter.containerSecurityContext.readOnlyRootFilesystem | bool | `false` | Set Penpot containers' security context readOnlyRootFilesystem |
| exporter.containerSecurityContext.runAsNonRoot | bool | `true` | Set Penpot container's security context runAsNonRoot |
| exporter.containerSecurityContext.runAsUser | int | `1001` | Set Penpot containers' security context runAsUser |
| exporter.deploymentAnnotations | object | `{}` | An optional map of annotations to be applied to the controller Deployment |
| exporter.image.imagePullPolicy | string | `"IfNotPresent"` | The image pull policy to use. |
| exporter.image.repository | string | `"penpotapp/exporter"` | The Docker repository to pull the image from. |
| exporter.image.tag | string | `"2.0.3"` | The image tag to use. |
| exporter.nodeSelector | object | `{}` | Node labels for Penpot pods assignment. Check [the official doc](https://kubernetes.io/docs/user-guide/node-selection/) |
| exporter.podAnnotations | object | `{}` | An optional map of annotations to be applied to the controller Pods |
| exporter.podSecurityContext | object | `{"enabled":true,"fsGroup":1001}` | Configure Pods Security Context. Check [the official doc](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-pod) |
| exporter.podSecurityContext.enabled | bool | `true` | Enabled Penpot pods' security context |
| exporter.podSecurityContext.fsGroup | int | `1001` | Set Penpot pod's security context fsGroup |
| exporter.replicaCount | int | `1` | The number of replicas to deploy. Enable persistence.exporter if you use more than 1 replicaCount |
| exporter.resources | object | `{"limits":{},"requests":{}}` | Penpot frontend resource requests and limits. Check [the official doc](https://kubernetes.io/docs/user-guide/compute-resources/) |
| exporter.resources.limits | object | `{}` | The resources limits for the Penpot frontend containers |
| exporter.resources.requests | object | `{}` | The requested resources for the Penpot frontend containers |
| exporter.service.port | int | `6061` | The service port to use. |
| exporter.service.type | string | `"ClusterIP"` | The service type to create. |
| exporter.tolerations | list | `[]` | Tolerations for Penpot pods assignment. Check [the official doc](https://kubernetes.io/docs/concepts/configuration/taint-and-toleration/) |

### Frontend parameters

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| frontend.affinity | object | `{}` | Affinity for Penpot pods assignment. Check [the official doc](https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#affinity-and-anti-affinity) |
| frontend.deploymentAnnotations | object | `{}` | An optional map of annotations to be applied to the controller Deployment |
| frontend.image.pullPolicy | string | `"IfNotPresent"` | The image pull policy to use. |
| frontend.image.repository | string | `"penpotapp/frontend"` | The Docker repository to pull the image from. |
| frontend.image.tag | string | `"2.0.3"` | The image tag to use. |
| frontend.nodeSelector | object | `{}` | Node labels for Penpot pods assignment. Check [the official doc](https://kubernetes.io/docs/user-guide/node-selection/) |
| frontend.podAnnotations | object | `{}` | An optional map of annotations to be applied to the controller Pods |
| frontend.replicaCount | int | `1` | The number of replicas to deploy. |
| frontend.resources | object | `{"limits":{},"requests":{}}` | Penpot frontend resource requests and limits. Check [the official doc](https://kubernetes.io/docs/user-guide/compute-resources/) |
| frontend.resources.limits | object | `{}` | The resources limits for the Penpot frontend containers |
| frontend.resources.requests | object | `{}` | The requested resources for the Penpot frontend containers |
| frontend.service.port | int | `80` | The service port to use. |
| frontend.service.type | string | `"ClusterIP"` | The service type to create. |
| frontend.tolerations | list | `[]` | Tolerations for Penpot pods assignment. Check [the official doc](https://kubernetes.io/docs/concepts/configuration/taint-and-toleration/) |

### Common parameters

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| fullnameOverride | string | `""` | To fully override common.names.fullname |
| nameOverride | string | `""` | To partially override common.names.fullname |
| serviceAccount.annotations | object | `{}` | Annotations for service account. Evaluated as a template. |
| serviceAccount.enabled | bool | `true` | Specifies whether a ServiceAccount should be created. |
| serviceAccount.name | string | `"penpot"` | The name of the ServiceAccount to use. If not set and enabled is true, a name is generated using the fullname template. |

### Global parameters

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| global.imagePullSecrets | list | `[]` | Global Docker registry secret names. E.g. imagePullSecrets:   - myRegistryKeySecretName |
| global.postgresqlEnabled | bool | `false` | Whether to deploy the Bitnami PostgreSQL chart as subchart. Check [the official chart](https://artifacthub.io/packages/helm/bitnami/postgresql) for configuration. |
| global.redisEnabled | bool | `false` | Whether to deploy the Bitnami Redis chart as subchart. Check [the official chart](https://artifacthub.io/packages/helm/bitnami/redis) for configuration. |

### Ingress parameters

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| ingress.annotations | object | `{}` | Mapped annotations for the ingress crontroller. E.g. annotations:   kubernetes.io/ingress.class: nginx   kubernetes.io/tls-acme: "true" |
| ingress.className | string | `""` | The Ingress className. |
| ingress.enabled | bool | `false` | Enable (frontend) Ingress Controller. |
| ingress.hosts | list | `[{"host":"penpot.example.com"}]` | Array style hosts for the (frontend) ingress crontroller. |
| ingress.hosts[0] | object | `{"host":"penpot.example.com"}` | The default external hostname to access to the penpot app. |
| ingress.path | string | `"/"` | Root path for every hosts. |
| ingress.tls | list | `[]` | Array style TLS secrets for the (frontend) ingress crontroller. E.g. tls:   - secretName: penpot.example.com-tls     hosts:       - penpot.example.com |

### Persistence parameters

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| persistence.assets.accessModes | list | `["ReadWriteOnce"]` | Assets persistent Volume access modes. |
| persistence.assets.annotations | object | `{}` | Assetsp ersistent Volume Claim annotations. |
| persistence.assets.enabled | string | `"fals"` | Enable assets persistence using Persistent Volume Claims. |
| persistence.assets.existingClaim | string | `""` | The name of an existing PVC to use for assets persistence. |
| persistence.assets.size | string | `"20Gi"` | Assets persistent Volume size. |
| persistence.assets.storageClass | string | `""` | Assets persistent Volume storage class. If defined, storageClassName: <storageClass>. If undefined (the default) or set to null, no storageClassName spec is set, choosing the default provisioner. |
| persistence.exporter.accessModes | list | `["ReadWriteOnce"]` | Exporter persistent Volume access modes. |
| persistence.exporter.annotations | object | `{}` | Exporter persistent Volume Claim annotations. |
| persistence.exporter.enabled | bool | `false` | Enable exporter persistence using Persistent Volume Claims. If exporter.replicaCount you have to enable it. |
| persistence.exporter.existingClaim | string | `""` | The name of an existing PVC to use for persistence. |
| persistence.exporter.size | string | `"10Gi"` | Exporter persistent Volume size. |
| persistence.exporter.storageClass | string | `""` | Exporter persistent Volume storage class. Empty is choosing the default provisioner by the provider. |

### PostgreSQL Dependencie parameters

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| postgresql | object | `{"auth":{"database":"penpot","password":"penpot","username":"penpot"}}` | PostgreSQL configuration (Check for [more parameters here](https://artifacthub.io/packages/helm/bitnami/postgresql)) |
| postgresql.auth.database | string | `"penpot"` | Name for a custom database to create. |
| postgresql.auth.password | string | `"penpot"` | Password for the custom user to create. |
| postgresql.auth.username | string | `"penpot"` | Name for a custom user to create. |

### Redis Dependencie parameters

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| redis | object | `{"auth":{"enabled":false}}` | Redis configuration (Check for [more parameters here](https://artifacthub.io/packages/helm/bitnami/redis)) |
| redis.auth.enabled | bool | `false` | Whether to enable password authentication. |

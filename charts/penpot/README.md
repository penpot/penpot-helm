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

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| backend.affinity | object | `{}` |  |
| backend.containerSecurityContext.allowPrivilegeEscalation | bool | `false` |  |
| backend.containerSecurityContext.capabilities.drop[0] | string | `"all"` |  |
| backend.containerSecurityContext.enabled | bool | `true` |  |
| backend.containerSecurityContext.readOnlyRootFilesystem | bool | `false` |  |
| backend.containerSecurityContext.runAsNonRoot | bool | `true` |  |
| backend.containerSecurityContext.runAsUser | int | `1001` |  |
| backend.image.pullPolicy | string | `"IfNotPresent"` |  |
| backend.image.repository | string | `"penpotapp/backend"` |  |
| backend.image.tag | string | `"2.0.3"` |  |
| backend.nodeSelector | object | `{}` |  |
| backend.podSecurityContext.enabled | bool | `true` |  |
| backend.podSecurityContext.fsGroup | int | `1001` |  |
| backend.replicaCount | int | `1` |  |
| backend.resources.limits | object | `{}` |  |
| backend.resources.requests | object | `{}` |  |
| backend.service.http.port | int | `6060` |  |
| backend.service.http.type | string | `"ClusterIP"` |  |
| backend.service.prepl.enabled | bool | `false` |  |
| backend.service.prepl.port | int | `6063` |  |
| backend.service.prepl.type | string | `"ClusterIP"` |  |
| backend.tolerations | list | `[]` |  |
| config.apiSecretKey | string | `"kmZ96pAxhTgk3HZvvBkPeVTspGBneKVLEpO_3ecORs_gwACENZ77z05zCe7skvPsQ3jI3QgkULQOWCuLjmjQsg"` |  |
| config.assets.filesystem.directory | string | `"/opt/data/assets"` |  |
| config.assets.s3.accessKeyID | string | `""` |  |
| config.assets.s3.bucket | string | `""` |  |
| config.assets.s3.endpointURI | string | `""` |  |
| config.assets.s3.existingSecret | string | `""` |  |
| config.assets.s3.region | string | `""` |  |
| config.assets.s3.secretAccessKey | string | `""` |  |
| config.assets.s3.secretKeys.accessKeyIDKey | string | `""` |  |
| config.assets.s3.secretKeys.endpointURIKey | string | `""` |  |
| config.assets.s3.secretKeys.secretAccessKey | string | `""` |  |
| config.assets.storageBackend | string | `"assets-fs"` |  |
| config.flags | string | `"enable-registration enable-login-with-password disable-email-verification enable-smtp enable-prepl-server"` |  |
| config.postgresql.database | string | `"penpot"` |  |
| config.postgresql.existingSecret | string | `""` |  |
| config.postgresql.host | string | `""` |  |
| config.postgresql.password | string | `"penpot"` |  |
| config.postgresql.port | int | `5432` |  |
| config.postgresql.secretKeys.passwordKey | string | `""` |  |
| config.postgresql.secretKeys.usernameKey | string | `""` |  |
| config.postgresql.username | string | `"penpot"` |  |
| config.providers.existingSecret | string | `""` |  |
| config.providers.github.clientID | string | `""` |  |
| config.providers.github.clientSecret | string | `""` |  |
| config.providers.github.enabled | bool | `false` |  |
| config.providers.gitlab.baseURI | string | `"https://gitlab.com"` |  |
| config.providers.gitlab.clientID | string | `""` |  |
| config.providers.gitlab.clientSecret | string | `""` |  |
| config.providers.gitlab.enabled | bool | `false` |  |
| config.providers.google.clientID | string | `""` |  |
| config.providers.google.clientSecret | string | `""` |  |
| config.providers.google.enabled | bool | `false` |  |
| config.providers.ldap.attributesEmail | string | `"mail"` |  |
| config.providers.ldap.attributesFullname | string | `"cn"` |  |
| config.providers.ldap.attributesPhoto | string | `"jpegPhoto"` |  |
| config.providers.ldap.attributesUsername | string | `"uid"` |  |
| config.providers.ldap.baseDN | string | `"ou=people,dc=planetexpress,dc=com"` |  |
| config.providers.ldap.bindDN | string | `"cn=admin,dc=planetexpress,dc=com"` |  |
| config.providers.ldap.bindPassword | string | `"GoodNewsEveryone"` |  |
| config.providers.ldap.enabled | bool | `false` |  |
| config.providers.ldap.host | string | `"ldap"` |  |
| config.providers.ldap.port | int | `10389` |  |
| config.providers.ldap.ssl | bool | `false` |  |
| config.providers.ldap.startTLS | bool | `false` |  |
| config.providers.ldap.userQuery | string | `"(&(|(uid=:username)(mail=:username))(memberOf=cn=penpot,ou=groups,dc=my-domain,dc=com))"` |  |
| config.providers.oidc.authURI | string | `""` |  |
| config.providers.oidc.baseURI | string | `""` |  |
| config.providers.oidc.clientID | string | `""` |  |
| config.providers.oidc.clientSecret | string | `""` |  |
| config.providers.oidc.emailAttribute | string | `""` |  |
| config.providers.oidc.enabled | bool | `false` |  |
| config.providers.oidc.nameAttribute | string | `""` |  |
| config.providers.oidc.roles | string | `"role1 role2"` |  |
| config.providers.oidc.rolesAttribute | string | `""` |  |
| config.providers.oidc.scopes | string | `"scope1 scope2"` |  |
| config.providers.oidc.tokenURI | string | `""` |  |
| config.providers.oidc.userURI | string | `""` |  |
| config.providers.secretKeys.githubClientIDKey | string | `""` |  |
| config.providers.secretKeys.githubClientSecretKey | string | `""` |  |
| config.providers.secretKeys.gitlabClientIDKey | string | `""` |  |
| config.providers.secretKeys.gitlabClientSecretKey | string | `""` |  |
| config.providers.secretKeys.googleClientIDKey | string | `""` |  |
| config.providers.secretKeys.googleClientSecretKey | string | `""` |  |
| config.providers.secretKeys.oidcClientIDKey | string | `""` |  |
| config.providers.secretKeys.oidcClientSecretKey | string | `""` |  |
| config.publicUri | string | `"http://penpot.example.com"` |  |
| config.redis.database | string | `"0"` |  |
| config.redis.host | string | `""` |  |
| config.redis.port | int | `6379` |  |
| config.registrationDomainWhitelist | string | `""` |  |
| config.smtp.defaultFrom | string | `""` |  |
| config.smtp.defaultReplyTo | string | `""` |  |
| config.smtp.enabled | bool | `false` |  |
| config.smtp.existingSecret | string | `""` |  |
| config.smtp.host | string | `""` |  |
| config.smtp.password | string | `""` |  |
| config.smtp.port | string | `""` |  |
| config.smtp.secretKeys.passwordKey | string | `""` |  |
| config.smtp.secretKeys.usernameKey | string | `""` |  |
| config.smtp.ssl | bool | `false` |  |
| config.smtp.tls | bool | `true` |  |
| config.smtp.username | string | `""` |  |
| config.telemetryEnabled | bool | `true` |  |
| exporter.affinity | object | `{}` |  |
| exporter.containerSecurityContext.allowPrivilegeEscalation | bool | `false` |  |
| exporter.containerSecurityContext.capabilities.drop[0] | string | `"all"` |  |
| exporter.containerSecurityContext.enabled | bool | `true` |  |
| exporter.containerSecurityContext.readOnlyRootFilesystem | bool | `false` |  |
| exporter.containerSecurityContext.runAsNonRoot | bool | `true` |  |
| exporter.containerSecurityContext.runAsUser | int | `1001` |  |
| exporter.image.imagePullPolicy | string | `"IfNotPresent"` |  |
| exporter.image.repository | string | `"penpotapp/exporter"` |  |
| exporter.image.tag | string | `"2.0.3"` |  |
| exporter.nodeSelector | object | `{}` |  |
| exporter.persistence.accessModes[0] | string | `"ReadWriteOnce"` |  |
| exporter.persistence.annotations | object | `{}` |  |
| exporter.persistence.enabled | bool | `false` |  |
| exporter.persistence.existingClaim | string | `""` |  |
| exporter.persistence.size | string | `"10Gi"` |  |
| exporter.persistence.storageClass | string | `""` |  |
| exporter.podSecurityContext.enabled | bool | `true` |  |
| exporter.podSecurityContext.fsGroup | int | `1001` |  |
| exporter.replicaCount | int | `1` |  |
| exporter.resources.limits | object | `{}` |  |
| exporter.resources.requests | object | `{}` |  |
| exporter.service.port | int | `6061` |  |
| exporter.service.type | string | `"ClusterIP"` |  |
| exporter.tolerations | list | `[]` |  |
| frontend.affinity | object | `{}` |  |
| frontend.image.pullPolicy | string | `"IfNotPresent"` |  |
| frontend.image.repository | string | `"penpotapp/frontend"` |  |
| frontend.image.tag | string | `"2.0.3"` |  |
| frontend.nodeSelector | object | `{}` |  |
| frontend.replicaCount | int | `1` |  |
| frontend.resources.limits | object | `{}` |  |
| frontend.resources.requests | object | `{}` |  |
| frontend.service.port | int | `80` |  |
| frontend.service.type | string | `"ClusterIP"` |  |
| frontend.tolerations | list | `[]` |  |
| fullnameOverride | string | `""` |  |
| global.imagePullSecrets | list | `[]` |  |
| global.postgresqlEnabled | bool | `false` |  |
| global.redisEnabled | bool | `false` |  |
| ingress.annotations | object | `{}` |  |
| ingress.className | string | `""` |  |
| ingress.enabled | bool | `false` |  |
| ingress.hosts[0].host | string | `"penpot.example.com"` |  |
| ingress.path | string | `"/"` |  |
| ingress.tls | list | `[]` |  |
| nameOverride | string | `""` |  |
| persistence.accessModes[0] | string | `"ReadWriteOnce"` |  |
| persistence.annotations | object | `{}` |  |
| persistence.enabled | string | `"fals"` |  |
| persistence.existingClaim | string | `""` |  |
| persistence.size | string | `"20Gi"` |  |
| persistence.storageClass | string | `""` |  |
| postgresql.auth.database | string | `"penpot"` |  |
| postgresql.auth.password | string | `"penpot"` |  |
| postgresql.auth.username | string | `"penpot"` |  |
| redis.auth.enabled | bool | `false` |  |
| serviceAccount.annotations | object | `{}` |  |
| serviceAccount.enabled | bool | `true` |  |
| serviceAccount.name | string | `"penpot"` |  |

# Penpot Helm Chart: local development with kind

## Requirements

- [docker](https://docs.docker.com/engine/install/)
- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)
- [helm](https://helm.sh/docs/intro/install/)
- [helm-doc](https://github.com/norwoodj/helm-docs/tree/master)
- [pre-commit](https://pre-commit.com/)

## Set the environment

```shell
pre-commit install --install-hooks -f
```

## Usage

- Create the local cluster, namespace, ingress and local dependencies:
  ```shell
  ./scripts/create_cluster.sh
  ```

- Create a local copy of the chart values:
  ```shell
  cp devel/penpot.values.yaml local.penpot.values.yaml
  ```

- Install the chart:
  ```shell
  helm install penpot ./charts/penpot -n penpot -f local.penpot.values.yaml
  ```

- Upgrade after changing local values:
  ```shell
  helm upgrade --install penpot ./charts/penpot -n penpot -f local.penpot.values.yaml
  ```

- Check status:
  ```shell
  kubectl get all,pvc,ingress,pdb -n penpot -o wide
  ```

- Access the application at [http://penpot.example.com/](http://penpot.example.com/)

> [!NOTE]
> Add the following entry to `/etc/hosts`:
>
> ```text
> 127.0.1.1 penpot.example.com
> ```

> [!TIP]
> If you disable ingress, you can expose the app on port 8888 with:
>
> ```shell
> kubectl port-forward service/penpot 8888:8080 -n penpot
> ```

#### Local development dependencies

The local setup (using `create_cluster.sh` script) installs the following services inside the `penpot` namespace:

- PostgreSQL
- Valkey

Default service discovery names:

- PostgreSQL: `postgresql.penpot.svc.cluster.local`
- Valkey: `valkey.penpot.svc.cluster.local`

Default development credentials:

- PostgreSQL
  * database: `penpot`
  * username: `penpot`
  * password: `penpot`
- Valkey
  * database: `0`

These values are intended for local development only.


If needed, you can re-apply local dependencies manually:

```shell
./scripts/setup_dependencies.sh
```

### Delete the cluster

```shell
./scripts/delete_cluster.sh
```

### Troubleshooting

If ingress-nginx admission webhook is not ready yet, you may see an error like:

```text
Error: INSTALLATION FAILED: 1 error occurred:
      * Internal error occurred: failed calling webhook "validate.nginx.ingress.kubernetes.io": failed to call webhook: Post "https://ingress-nginx-controller-admission.ingress-nginx.svc:443/networking/v1/ingresses?timeout=10s": dial tcp <ip>:443: connect: connection refused
```

Wait a few seconds and try again, or delete the validating webhook in local development:

```shell
kubectl delete ValidatingWebhookConfiguration ingress-nginx-admission
```

Check dependency resources with:

```shell
kubectl get pods,svc,pvc -n penpot
```

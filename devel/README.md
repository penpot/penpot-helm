# Penpot Helm Chart: Devel doc

### Requirements:

- [docker](https://docs.docker.com/engine/install/)
- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)
- [helm](https://helm.sh/docs/intro/install/)
- [helm-doc](https://github.com/norwoodj/helm-docs/tree/master)
- [pre-commit](https://pre-commit.com/)

### Set the environment:

```shell
# Enable  precommit in the repository
pre-commit install --install-hooks -f
```

### Usage:

- Create the cluster `penpot-cluster` with a namespace `penpot`:
  ```shell
  ./scripts/cluster_create.sh
  ```

- Download dependencies
  ```shell
  helm repo add bitnami https://charts.bitnami.com/bitnami
  helm dependency build ./charts/penpot
  ```

- Install the chart
  ```shell
  helm install penpot ./charts/penpot -f devel/penpot.values.yaml
  ```

- Access to [http://penpot.example.com/](http://penpot.example.com/) (
> [!NOTE]
> You need to add `127.0.1.1  penpot.example.com` to `/etc/hosts`

> [!TIP]
> if you disable ingress, you can exposing the app in the port 8888 with:
> ```shell
> kubectl port-forward service/penpot 8888:8080
> ```

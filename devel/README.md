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
> kubectl port-forward service/penpot 8888:80
> ```

### Troubleshooting:

- ```
  Error: INSTALLATION FAILED: 1 error occurred:
  	  * Internal error occurred: failed calling webhook "validate.nginx.ingress.kubernetes.io": failed to call webhook: Post "https://ingress-nginx-controller-admission.ingress-nginx.svc:443/networking/v1/ingresses?timeout=10s": dial tcp 10.96.81.208:443: connect: connection refused
  ```
  This error appears after install penpot helm. Tu ignore it, run:
  ```
  kubectl delete ValidatingWebhookCOnfiguration ingress-nginx-admission
  ```

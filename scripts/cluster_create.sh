#!/usr/bin/bash

# Create a kind cluster
kind create cluster --name penpot-cluster --config devel/kind.config.yml

# Create a namespace for Penpot
kubectl apply -f devel/penpot-namespace.yml
kubectl config set-context penpot --namespace=penpot --cluster=kind-penpot-cluster --user=kind-penpot-cluster
kubectl config use-context penpot

# Setup ingress
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

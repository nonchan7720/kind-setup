# Kind Kubernetes Cluster Setup Guide

This repository contains setup configurations for a local Kubernetes cluster using Kind (Kubernetes IN Docker) and deployment settings for specific services (Dashboard, Traefik, Jaeger).

[日本語版はこちら / Japanese version here](../README.md)

## Table of Contents

- [Kind Kubernetes Cluster Setup Guide](#kind-kubernetes-cluster-setup-guide)
  - [Table of Contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
  - [Kind Cluster Setup](#kind-cluster-setup)
    - [1. Creating the Cluster](#1-creating-the-cluster)
    - [2. Verifying the Cluster](#2-verifying-the-cluster)
  - [Components](#components)
    - [Dashboard](#dashboard)
    - [Traefik](#traefik)
    - [Jaeger](#jaeger)
  - [Troubleshooting](#troubleshooting)

## Prerequisites

Ensure you have the following tools installed:

- Docker
- Kind
- kubectl
- Helm v3

## Kind Cluster Setup

### 1. Creating the Cluster

Use `kind.yaml` to create a Kind cluster with properly configured port mappings and node settings:

```bash
kind create cluster --config kind.yaml --name local-cluster

# To delete the cluster
# kind delete cluster --name local-cluster
```

This configuration includes the following port mappings:
- HTTP (80) -> Container port 30080
- HTTPS (443) -> Container port 30443

It also includes settings necessary for the Ingress controller to function properly.

### 2. Verifying the Cluster

Verify that the cluster has been created successfully:

```bash
kubectl cluster-info
kubectl get nodes
```

## Components

### Dashboard

Configuration files for deploying Kubernetes Dashboard.

**Setup Method**:

```bash
# Apply resources including Helm charts using Kustomize
kubectl kustomize --enable-helm dashboard/ | kubectl apply -f -

# To delete
# kubectl kustomize --enable-helm dashboard/ | kubectl delete -f -
```

**Main Components**:

- Kubernetes Dashboard Helm chart (kubernetes.github.io/dashboard/)
- Admin access permissions (admin.yaml) - ServiceAccount with cluster-admin role
- Namespace configuration (namespace.yaml) - kubernetes-dashboard namespace

Kubernetes Dashboard provides a web-based UI to monitor and manage the state of your cluster visually.

**Access Method**:

```bash
# Port forward to access the Dashboard
kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443

# Generate a token for the admin user
kubectl -n kubernetes-dashboard create token admin-user

# Access the following URL in your browser
# https://localhost:8443/
# Log in using the generated token
```

When accessing the Dashboard, authenticate using the generated token. The token expires after a certain period, so regenerate it as needed.

### Traefik

Deployment configuration for Traefik.

**Setup Method**:

```bash
# Apply resources including Helm charts using Kustomize
kubectl kustomize --enable-helm traefik/ | kubectl apply -f -

# To delete
# kubectl kustomize --enable-helm traefik/ | kubectl delete -f -
```

**Main Components**:

- Traefik Helm chart (traefik.github.io/charts) - using version v35.2.0
- Custom values configuration (values.yaml) - JSON log format, DEBUG level logging, default IngressClass settings, etc.
- Ingress configuration (ingress.yaml) - Dashboard Ingress resource
- Namespace configuration (namespace.yaml) - ingress-traefik namespace

Traefik is a modern cloud-native reverse proxy and load balancer used for traffic management in Kubernetes environments.

**Verification**:

```bash
# Access the Traefik dashboard through Ingress
# Visit the following URL in your browser
# http://traefik-dashboard.127.0.0.1.nip.io/
```

The Traefik dashboard can be accessed through the Ingress hostname (`traefik-dashboard.127.0.0.1.nip.io`).

### Jaeger

Configuration files for deploying Jaeger, a distributed tracing system.

**Setup Method**:

```bash
# Apply resources including Helm charts using Kustomize
kubectl kustomize --enable-helm jaeger/ | kubectl apply -f -

# To delete
# kubectl kustomize --enable-helm jaeger/ | kubectl delete -f -
```

**Main Components**:

- Jaeger Helm chart (jaegertracing.github.io/helm-charts) - using version v3.4.1
- Custom values configuration (values.yaml) - badger storage type, All-in-One mode, UI Ingress settings
- OTLP Ingress configuration (ingress.yaml) - endpoints for OpenTelemetry Protocol
- Namespace configuration (namespace.yaml) - jaeger namespace

Jaeger enables distributed tracing in microservice architectures, helping to analyze service dependencies and performance issues.

**UI Access Method**:

```bash
# Access Jaeger UI through Ingress
# Visit the following URL in your browser
# http://jaeger-ui.127.0.0.1.nip.io/

# Access to OTLP endpoint
# http://jaeger-otlp.127.0.0.1.nip.io/
```

To send trace data using the OTLP protocol, use the `jaeger-otlp.127.0.0.1.nip.io` endpoint.

## Troubleshooting

If you encounter issues with the cluster or services, you can check their status using the following commands:

```bash
kubectl get pods --all-namespaces
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

## Sending Traces from Docker Compose Applications to Jaeger

Here's a configuration example for sending trace data from applications running in Docker Compose to Jaeger deployed on your Kind cluster.

### Docker Compose Configuration

Add the following settings to your `docker-compose.yml` file:

```yaml
version: '3'
services:
  your-app:
    # Your application configuration
    environment:
      # OpenTelemetry Collector export settings
      OTEL_EXPORTER_OTLP_ENDPOINT: "http://jaeger-otlp.127.0.0.1.nip.io"
      OTEL_SERVICE_NAME: "your-service-name"
    # Host resolution configuration
    extra_hosts:
      - "jaeger-otlp.127.0.0.1.nip.io:host-gateway"
```

Your application should use the OpenTelemetry SDK to send trace data to Jaeger. It's important to set the correct hostname in the `OTEL_EXPORTER_OTLP_ENDPOINT` environment variable and ensure the same hostname is mapped to the host machine's IP in the `extra_hosts` setting.

To send trace data using the OTLP protocol, use the `jaeger-otlp.127.0.0.1.nip.io` endpoint that was configured in your Kind cluster directly.

### Verification

You can verify that trace data is being sent correctly by checking the Jaeger UI:

```bash
# Access the following URL in your browser
# http://jaeger-ui.127.0.0.1.nip.io/
```

Select your service name (the value set in `OTEL_SERVICE_NAME`) from the service dropdown to view your trace data.

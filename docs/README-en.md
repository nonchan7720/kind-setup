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
  - [Base Infrastructure Setup](#base-infrastructure-setup)
    - [Recommended Deployment Order](#recommended-deployment-order)
  - [Components](#components)
    - [Dashboard](#dashboard)
    - [Traefik](#traefik)
    - [Local Storage](#local-storage)
    - [LocalStack](#localstack)
    - [Jaeger](#jaeger)
    - [MySQL Operator](#mysql-operator)
    - [Temporal DB](#temporal-db)
    - [Temporal](#temporal)
  - [Troubleshooting](#troubleshooting)
  - [Sending Traces from Docker Compose Applications to Jaeger](#sending-traces-from-docker-compose-applications-to-jaeger)
    - [Docker Compose Configuration](#docker-compose-configuration)
    - [Verification](#verification)

## Prerequisites

Ensure you have the following tools installed:

- Docker
- Kind
- kubectl
- Helm v3
- helmfile (required for Temporal manifest generation)

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

## Base Infrastructure Setup

After creating the cluster, you need to set up the following base infrastructure components **first** before deploying other components:

### Recommended Deployment Order

1. **Dashboard** - Provides UI for cluster monitoring and management
2. **Traefik (Ingress Controller)** - Required to handle Ingress resources (LocalStack, Jaeger, etc. depend on this)
3. **Local Storage (local-path-provisioner)** - Required to handle PersistentVolumeClaims (LocalStack, etc. depend on this)

After setting up these base infrastructure components, you can deploy other components (LocalStack, Jaeger, MySQL Operator, etc.).

**Setup Commands**:

```bash
# 1. Dashboard
kubectl kustomize --enable-helm dashboard/ | kubectl apply -f -

# 2. Traefik (Ingress Controller)
kubectl kustomize --enable-helm traefik/ | kubectl apply -f -

# 3. Local Storage
kubectl apply -k local-path-provisioner

# Wait for all pods to start
kubectl get pods --all-namespaces
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

### Local Storage

Configuration files for deploying local storage provisioner to handle PVCs.

**Setup Method**:

```bash
# Apply resources using Kustomize
kubectl apply -k local-path-provisioner

# To delete
# kubectl delete -k local-path-provisioner
```

### LocalStack

Configuration files for deploying LocalStack, a local emulator for AWS services.

**Prerequisites**:
- Traefik must be deployed beforehand (to handle Ingress resources)
- local-path-provisioner must be deployed beforehand (to handle PVC)

**Setup Method**:

```bash
# Apply resources using Kustomize
kubectl apply -k localstack

# To delete
# kubectl delete -k localstack
```

**Main Components**:

- LocalStack StatefulSet configuration (statefulset.yaml) - LocalStack image (version 4.12.0), persistent volume settings
- Service configuration (service.yaml) - access via port 4566
- Ingress configuration (ingress.yaml) - access via localhost.localstack.cloud hostname
- PVC configuration (pvc.yaml) - storage for data persistence
- ConfigMap configuration (kustomization.yaml) - ConfigMap generation for environment variables (env-localstack) and initialization scripts (init-localstack)
- Namespace configuration (namespace.yaml) - localstack namespace

LocalStack emulates AWS services such as S3, SQS, SNS, and DynamoDB in a local environment for development and testing purposes.

**Environment Variables**:

The following services are enabled by default:
- S3 (Object Storage)
- SQS (Message Queue)
- SNS (Notification Service)
- DynamoDB (NoSQL Database)

The default region is set to `ap-northeast-1`.

**Access Method**:

```bash
# Access LocalStack through Ingress
# Access the following endpoint in your browser or AWS CLI
# http://localhost.localstack.cloud/

# AWS CLI usage example
AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test aws --endpoint-url=http://localhost.localstack.cloud s3 ls

# Examples of using specific services
# Create an S3 bucket
aws --endpoint-url=http://localhost.localstack.cloud s3 mb s3://my-bucket --region ap-northeast-1

# Create an SQS queue
aws --endpoint-url=http://localhost.localstack.cloud sqs create-queue --queue-name my-queue --region ap-northeast-1

# Create a DynamoDB table
aws --endpoint-url=http://localhost.localstack.cloud dynamodb create-table \
  --table-name my-table \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-northeast-1
```

**Initialization Scripts**:

Initialization scripts are mounted at `/etc/localstack/init/ready.d`. If you need custom initialization processes, edit `localstack/base/files/init-scripts.sh`.

### Jaeger

Configuration files for deploying Jaeger, a distributed tracing system.

**Prerequisites**:
- Traefik must be deployed beforehand (to expose UI and OTLP endpoints via Ingress resources)

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

### MySQL Operator

Configuration files for deploying Oracle MySQL Operator for Kubernetes.

**Setup Method**:

```bash
# Apply resources using Kustomize
kubectl apply -k mysql-operator

# To delete
# kubectl delete -k mysql-operator
```

**Main Components**:

- MySQL Operator CRDs (version 9.5.0-2.2.6)
- MySQL Operator deployment
- Namespace configuration - mysql-operator namespace

MySQL Operator manages high-availability MySQL clusters in Kubernetes. It automates operations such as InnoDBCluster provisioning, scaling, and backups.

### Temporal DB

Configuration files for deploying a MySQL database cluster for Temporal.

**Prerequisites**:
- mysql-operator must be deployed beforehand

**Setup Method**:

```bash
# Apply resources using Kustomize
kubectl apply -k temporal-db

# To delete
# kubectl delete -k temporal-db
```

**Main Components**:

- InnoDBCluster configuration (db-cluster.yaml) - 3-instance cluster with 1 router instance
- MySQL secret configuration (via mysql.env)
- Namespace configuration (namespace.yaml) - temporal-db namespace

This cluster is used as the metadata store for the Temporal workflow engine.

**Connecting to the Database**:

```bash
# Connect to the database using MySQL Shell
kubectl run -n temporal-db --rm -it myshell --image=container-registry.oracle.com/mysql/community-operator -- mysqlsh

# Connect within MySQL Shell
MySQL  SQL > \connect root@temporal-db-cluster

# Enter the password to log in
# Execute queries from files/query.sql as needed
```

### Temporal

Configuration files for deploying Temporal, a workflow orchestration engine.

**Prerequisites**:
- temporal-db must be deployed and running properly

**Setup Method**:

```bash
# Generate manifest files (optional)
cd temporal
./helm.sh

# Apply resources using Kustomize
kubectl apply -k temporal

# To delete
# kubectl delete -k temporal
```

**Main Components**:

- Temporal Helm chart (temporalio/temporal) - using version 1.29.2
- Custom values configuration (values-base.yaml, values-local.yaml) - database connection settings, replica counts, etc.
- Manifest generation script (helm.sh) - generates manifests using Helmfile
- Namespace configuration (namespace.yaml) - temporal namespace

Temporal provides reliable workflow orchestration for distributed systems. It simplifies complex asynchronous processing, long-running tasks, and error handling.

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

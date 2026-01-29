# Kind Kubernetes クラスタセットアップガイド

このリポジトリには、Kind（Kubernetes IN Docker）を使用したローカルKubernetesクラスタのセットアップと、特定のサービス（Dashboard、Traefik、Jaeger）のデプロイメント設定が含まれています。

[English version here](docs/README-en.md)

## 目次

- [Kind Kubernetes クラスタセットアップガイド](#kind-kubernetes-クラスタセットアップガイド)
  - [目次](#目次)
  - [前提条件](#前提条件)
  - [Kindクラスタのセットアップ](#kindクラスタのセットアップ)
    - [1. クラスタの作成](#1-クラスタの作成)
    - [2. クラスタの確認](#2-クラスタの確認)
  - [コンポーネント一覧](#コンポーネント一覧)
    - [dashboard](#dashboard)
    - [traefik](#traefik)
    - [local storage](#local-storage)
    - [localstack](#localstack)
    - [jaeger](#jaeger)
    - [mysql-operator](#mysql-operator)
    - [temporal-db](#temporal-db)
    - [temporal](#temporal)
  - [トラブルシューティング](#トラブルシューティング)
  - [Docker ComposeアプリケーションからJaegerへのトレース送信](#docker-composeアプリケーションからjaegerへのトレース送信)
    - [Docker Composeの設定](#docker-composeの設定)
    - [動作確認](#動作確認)

## 前提条件

以下のツールがインストールされていることを確認してください：

- Docker
- Kind
- kubectl
- Helm v3
- helmfile

## Kindクラスタのセットアップ

### 1. クラスタの作成

`kind.yaml` を使用して、ポートマッピングとノード設定が適切に構成されたKindクラスタを作成します：

```bash
kind create cluster --config kind.yaml --name local-cluster

# 削除する場合
# kind delete cluster --name local-cluster
```

この設定では、以下のポートマッピングが設定されています：
- HTTP (80) -> コンテナポート 30080
- HTTPS (443) -> コンテナポート 30443

また、Ingressコントローラが適切に機能するための設定も含まれています。

### 2. クラスタの確認

クラスタが正常に作成されたことを確認します：

```bash
kubectl cluster-info
kubectl get nodes
```

## コンポーネント一覧

### dashboard

Kubernetes Dashboardをデプロイするための設定ファイルが含まれています。

**セットアップ方法**:

```bash
# Kustomizeを使用してHelmチャートを含むリソースを適用
kubectl apply -k dashboard

# 削除する場合
# kubectl delete dashboard
```

**主な構成**:

- Kubernetes Dashboard Helmチャート（kubernetes.github.io/dashboard/）
- 管理者アクセス権限設定（admin.yaml）- cluster-admin権限を持つServiceAccount
- 名前空間設定（namespace.yaml）- kubernetes-dashboard名前空間

Kubernetes Dashboardは、クラスタの状態を視覚的に監視・管理するためのWebインターフェースを提供します。

**アクセス方法**:

```bash
# ポートフォワーディングを使用してDashboardにアクセス
kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443

# 管理者ユーザー用のトークンを生成
kubectl -n kubernetes-dashboard create token admin-user

# ブラウザで以下のURLにアクセス
# https://localhost:8443/
# 生成されたトークンを使用してログイン
```

Dashboardにアクセスする際は、生成されたトークンを使用して認証を行います。トークンは一定期間で有効期限が切れるため、必要に応じて再生成してください。

### traefik

Traefikのデプロイメント設定が含まれています。

**セットアップ方法**:

```bash
# Kustomizeを使用してHelmチャートを含むリソースを適用
kubectl apply -k traefik

# 削除する場合
# kubectl delete -k traefik
```

**主な構成**:

- Traefik Helmチャート（traefik.github.io/charts）- バージョンv35.2.0を使用
- カスタム値設定（values.yaml）- JSONログフォーマット、DEBUGレベルのログ、デフォルトIngressClass等の設定
- Ingress設定（ingress.yaml）- ダッシュボード用Ingressリソース
- 名前空間設定（namespace.yaml）- ingress-traefik名前空間

Traefikは、モダンなクラウドネイティブなリバースプロキシおよびロードバランサーで、Kubernetes環境でのトラフィック管理に使用されます。

**動作確認**:

```bash
# Ingressを通じてTraefikダッシュボードにアクセス
# ブラウザで以下のURLにアクセス
# http://traefik-dashboard.127.0.0.1.nip.io/
```

Traefikダッシュボードは、Ingressで設定されたホスト名（`traefik-dashboard.127.0.0.1.nip.io`）を通じてアクセスできます。

### local storage

local storage を pvc として扱うためのデプロイメント設定が含まれています。

**セットアップ方法**:

```bash
# Kustomizeを使用してHelmチャートを含むリソースを適用
kubectl apply -k local-path-provisioner

# 削除する場合
# kubectl delete -k local-path-provisioner
```
### localstack

AWSサービスのローカルエミュレーターであるLocalStackのデプロイメント設定が含まれています。

**セットアップ方法**:

```bash
# Kustomizeを使用してリソースを適用
kubectl apply -k localstack

# 削除する場合
# kubectl delete -k localstack
```

**主な構成**:

- LocalStack StatefulSet設定（statefulset.yaml）- LocalStackイメージ（バージョン4.12.0）、永続ボリューム設定
- サービス設定（service.yaml）- ポート4566でのアクセス
- Ingress設定（ingress.yaml）- localhost.localstack.cloudホスト名でのアクセス
- PVC設定（pvc.yaml）- データ永続化用ストレージ
- ConfigMap設定（configuration.yaml）- 環境変数と初期化スクリプト
- 名前空間設定（namespace.yaml）- localstack名前空間

LocalStackは、S3、SQS、SNS、DynamoDBなどのAWSサービスをローカル環境でエミュレートし、開発・テスト用途に使用できます。

**環境変数**:

デフォルトで以下のサービスが有効化されています：
- S3（オブジェクトストレージ）
- SQS（メッセージキュー）
- SNS（通知サービス）
- DynamoDB（NoSQLデータベース）

デフォルトリージョンは `ap-northeast-1` に設定されています。

**アクセス方法**:

```bash
# Ingressを通じてLocalStackにアクセス
# ブラウザまたはAWS CLIで以下のエンドポイントにアクセス
# http://localhost.localstack.cloud/

# AWS CLIの使用例
AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test aws --endpoint-url=http://localhost.localstack.cloud s3 ls

# 特定のサービスを使用する例
# S3バケットの作成
aws --endpoint-url=http://localhost.localstack.cloud s3 mb s3://my-bucket --region ap-northeast-1

# SQSキューの作成
aws --endpoint-url=http://localhost.localstack.cloud sqs create-queue --queue-name my-queue --region ap-northeast-1

# DynamoDBテーブルの作成
aws --endpoint-url=http://localhost.localstack.cloud dynamodb create-table \
  --table-name my-table \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-northeast-1
```

**初期化スクリプト**:

初期化スクリプトは `/etc/localstack/init/ready.d` にマウントされます。カスタム初期化処理が必要な場合は、`localstack/base/files/init-scripts.sh` を編集してください。

### jaeger

分散トレーシングシステムであるJaegerのデプロイメント設定が含まれています。

**セットアップ方法**:

```bash
# Kustomizeを使用してHelmチャートを含むリソースを適用
kubectl kustomize --enable-helm jaeger/ | kubectl apply -f -

# 削除する場合
# kubectl kustomize --enable-helm jaeger/ | kubectl delete -f -
```

**主な構成**:

- Jaeger Helmチャート（jaegertracing.github.io/helm-charts）- バージョンv3.4.1を使用
- カスタム値設定（values.yaml）- badgerストレージタイプ、All-in-Oneモード、UIのIngress設定
- OTLPのIngress設定（ingress.yaml）- OpenTelemetry Protocol用のエンドポイント
- 名前空間設定（namespace.yaml）- jaeger名前空間

Jaegerは、マイクロサービスアーキテクチャにおける分散トレーシングを実現し、サービス間の依存関係や性能問題の分析に役立ちます。

**UI アクセス方法**:

```bash
# Ingressを通じてJaeger UIにアクセス
# ブラウザで以下のURLにアクセス
# http://jaeger-ui.127.0.0.1.nip.io/

# OTLPエンドポイントへのアクセス
# http://jaeger-otlp.127.0.0.1.nip.io/
```

OTLPプロトコルを使用してトレースデータを送信する場合は、`jaeger-otlp.127.0.0.1.nip.io`エンドポイントを利用できます。

### mysql-operator

Oracle MySQL Operator for Kubernetesのデプロイメント設定が含まれています。

**セットアップ方法**:

```bash
# Kustomizeを使用してリソースを適用
kubectl apply -k mysql-operator

# 削除する場合
# kubectl delete -k mysql-operator
```

**主な構成**:

- MySQL Operator CRDs（バージョン9.5.0-2.2.6）
- MySQL Operatorデプロイメント
- 名前空間設定 - mysql-operator名前空間

MySQL Operatorは、KubernetesクラスタでMySQLの高可用性クラスタを管理するためのオペレーターです。InnoDBクラスタのプロビジョニング、スケーリング、バックアップなどの操作を自動化します。

### temporal-db

Temporal用のMySQLデータベースクラスタのデプロイメント設定が含まれています。

**前提条件**:
- mysql-operatorが事前にデプロイされていること

**セットアップ方法**:

```bash
# Kustomizeを使用してリソースを適用
kubectl apply -k temporal-db

# 削除する場合
# kubectl delete -k temporal-db
```

**主な構成**:

- InnoDBクラスタ設定（db-cluster.yaml）- 3インスタンスのクラスタ構成、1インスタンスのルーター
- MySQLシークレット設定（mysql.env経由）
- 名前空間設定（namespace.yaml）- temporal-db名前空間

このクラスタは、Temporalワークフローエンジンのメタデータストアとして使用されます。

**データベースへの接続**:

```bash
# MySQL Shellを使用してデータベースに接続
kubectl run -n temporal-db --rm -it myshell --image=container-registry.oracle.com/mysql/community-operator -- mysqlsh

# MySQL Shell内で接続
MySQL  SQL > \connect root@temporal-db-cluster

# パスワードを入力してログイン
# 必要に応じてfiles/query.sqlのクエリを実行
```

### temporal

ワークフローエンジンであるTemporalのデプロイメント設定が含まれています。

**前提条件**:
- temporal-dbが事前にデプロイされ、正常に動作していること

**セットアップ方法**:

```bash
# マニフェストファイルの生成（オプション）
cd temporal
./helm.sh

# Kustomizeを使用してリソースを適用
kubectl apply -k temporal

# 削除する場合
# kubectl delete -k temporal
```

**主な構成**:

- Temporal Helmチャート（temporalio/temporal）- バージョン1.29.2を使用
- カスタム値設定（values-base.yaml, values-local.yaml）- データベース接続設定、レプリカ数等
- マニフェスト生成スクリプト（helm.sh）- Helmfileを使用したマニフェスト生成
- 名前空間設定（namespace.yaml）- temporal名前空間

Temporalは、分散システムにおける信頼性の高いワークフローオーケストレーションを提供します。複雑な非同期処理、長時間実行タスク、エラーハンドリングなどを簡素化します。

## トラブルシューティング

クラスタやサービスに問題が発生した場合は、以下のコマンドで状態を確認できます：

```bash
kubectl get pods --all-namespaces
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

## Docker ComposeアプリケーションからJaegerへのトレース送信

Kindクラスタ上のJaegerにDocker Composeで実行しているアプリケーションからトレースデータを送信するための設定例です。

### Docker Composeの設定

`docker-compose.yml`ファイルに以下のような設定を追加します：

```yaml
version: '3'
services:
  your-app:
    # アプリケーションの設定
    environment:
      # OpenTelemetry Collector へのエクスポート設定
      OTEL_EXPORTER_OTLP_ENDPOINT: "http://jaeger-otlp.127.0.0.1.nip.io"
      OTEL_SERVICE_NAME: "your-service-name"
    # ホスト名解決のための設定
    extra_hosts:
      - "jaeger-otlp.127.0.0.1.nip.io:host-gateway"
```

アプリケーションは、OpenTelemetry SDKを使用してトレースデータをJaegerに送信します。環境変数`OTEL_EXPORTER_OTLP_ENDPOINT`で正しいホスト名を設定し、`extra_hosts`で同じホスト名がホストマシンのIPにマッピングされるようにすることが重要です。

OTLPプロトコルを使用してトレースデータを送信する場合は、Kindクラスタで設定した`jaeger-otlp.127.0.0.1.nip.io`エンドポイントを直接利用します。

### 動作確認

トレースデータが正しく送信されているかは、Jaeger UIで確認できます：

```bash
# ブラウザで以下のURLにアクセス
# http://jaeger-ui.127.0.0.1.nip.io/
```

サービス名ドロップダウンから、設定した`OTEL_SERVICE_NAME`の値を選択して、トレースデータを確認します。

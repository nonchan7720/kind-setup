# Kind Kubernetes クラスタセットアップガイド

このリポジトリには、Kind（Kubernetes IN Docker）を使用したローカルKubernetesクラスタのセットアップと、特定のサービス（Dashboard、Traefik、Jaeger）のデプロイメント設定が含まれています。

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
    - [jaeger](#jaeger)
  - [トラブルシューティング](#トラブルシューティング)

## 前提条件

以下のツールがインストールされていることを確認してください：

- Docker
- Kind
- kubectl
- Helm v3

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
kubectl kustomize --enable-helm dashboard/ | kubectl apply -f -

# 削除する場合
# kubectl kustomize --enable-helm dashboard/ | kubectl delete -f -
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
kubectl kustomize --enable-helm traefik/ | kubectl apply -f -

# 削除する場合
# kubectl kustomize --enable-helm traefik/ | kubectl delete -f -
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

## トラブルシューティング

クラスタやサービスに問題が発生した場合は、以下のコマンドで状態を確認できます：

```bash
kubectl get pods --all-namespaces
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

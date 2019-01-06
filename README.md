# Personal K8s cluster

Personal Kubernetes cluster using Terraform to bring up the GKE cluster and Helm for deploying services.

Services include:

* **ACME CertManager** - Using LetsEncypt
* **ExternalDNS** - Using CloudFlare DNS
* **Mailer** - Using SendGrid
* **Prometheus/Grafana** - Monitoring
* **Nginx Ingress** - HTTPS Ingress
* **Adminer** - DB management

## Prerequisites
### Create GCP project
Create project, make it default and configure billing (assumes you only have one billing account):
```bash
GCP_PROJECT=personal-k8s-cluster
{
gcloud projects create --name $GCP_PROJECT
export GOOGLE_PROJECT=$(gcloud projects list --filter="name='${GCP_PROJECT}'" --format="value(project_id)")
gcloud config set project $(gcloud projects list --filter="name='${GCP_PROJECT}'" --format="value(project_id)")
gcloud alpha billing projects link $(gcloud projects list --filter="name='${GCP_PROJECT}'" --format="value(project_id)") --billing-account $(gcloud alpha billing accounts list --format="value(name)")
}
```

Set default region and zone:

```bash
{
gcloud config set compute/region us-east1
gcloud config set compute/zone us-east1-b
}
```

### Enable GCP APIs:
```bash
{
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
}
```

### Initiate Helm values
```bash
cp values.yaml.example values.yaml
```

### CloudFlare DNS
Need 2 items configured in `values.yaml` for your CloudFlare account:

1. `external-dns.cloudflare.email`: Account e-mail address
2. `external-dns.cloudflare.apiKey`: Global API key from your profile

### SendGrid
#### Sender Authentication
CNAMEs are required for sender authentication. Go to [SendGrid's settings](https://app.sendgrid.com/settings/sender_auth/domain/create) to create your domain entry.

You must then add those records to your CloudFlare domain.

#### API Key
Create an API key that with restricted access to send e-mail. Record the key (should start with `SG`) as `mailer.sendgridApiKey` in `values.yaml`.

### Persistent disks:
Manage these outside of Terraform since I do not want the lifecycle tied to cluster.

```bash
gcloud compute disks create pv-prometheus-alertmanager --size 3GB
gcloud compute disks create pv-prometheus-server --size 9GB
gcloud compute disks create pv-grafana --size 10GB
gcloud compute disks create pv-es-data-0 --size 10GB
gcloud compute disks create pv-es-data-1 --size 10GB
gcloud compute disks create pv-es-master-0 --size 3GB
```

## Setup Cluster
Use Terraform to bring up GKE cluster:
```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

## Kubernetes
### Create Persistent Objects
Modify persistent object manifest:
```bash
cp persistent.yaml.example persistent.yaml
vim persistent.yaml
```

Create objects:
```bash
kubectl create -f persistent.yaml
```

### Install Helm/Tiller
Create account and role binding before installing Tiller:
```bash
{
kubectl create --namespace=kube-system serviceaccount tiller
kubectl create clusterrolebinding tiller-admin-binding --clusterrole=cluster-admin --serviceaccount kube-system:tiller
helm init --service-account tiller
}
```

### Install Helm charts
Deploy infra chart to its own namespace:
```bash
{
helm dep up infra
helm install -f values.yaml --namespace infra -n infra ./infra
}
```

Deploy ingress chart:
```bash
{
helm dep up ingress
helm install -f values.yaml -n ingress ./ingress
}
```

## Upgrading Chart Dependencies
```
helm dep up <CHART>
helm upgrade <RELEASE> <CHART>
```

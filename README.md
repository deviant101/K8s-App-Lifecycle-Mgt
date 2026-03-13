# K8s Application Lifecycle Management

A hands-on lab covering the full lifecycle of an application in Kubernetes –
from first deployment through scaling, rolling updates, rollbacks, and three
ways to customise runtime content (ConfigMap, Secret, Environment Variables).

---

## Repository layout

```
.
├── flask-app/                  # Flask application (Python 3.11 + Gunicorn)
│   ├── app.py
│   ├── requirements.txt
│   ├── templates/index.html
│   └── Dockerfile
│
└── k8s/
    ├── namespace.yaml
    ├── 01-create/              # Task 1 – Create Deployment + Service
    ├── 02-scale/               # Task 2 – Scale up / down
    ├── 03-update/              # Task 3 – RollingUpdate & Recreate
    ├── 04-rollback/            # Task 4 – Roll back
    ├── 05-configmap/           # Task 5 – ConfigMap-based welcome page
    ├── 06-secret/              # Task 6 – Secret-based welcome page
    └── 07-envvar/              # Task 7 – Env-var-based welcome page
```

---

## Prerequisites

| Tool | Where | Notes |
|------|-------|-------|
| SSH client | Local machine | To log in to the master node |
| kubectl | **Master node** | Already available after kubeadm setup |
| Docker | **Master node** | Required only for Task 7-B (Flask image build) |
| git | Master node (optional) | To clone this repo onto the master |

### Workflow

All `kubectl` commands are run **directly on the master node** after SSH-ing in.
No local kubectl installation or kubeconfig setup is needed.

```bash
# 1. SSH into the master node
ssh <user>@<azure-vm-ip>

# 2. Verify kubectl works (kubeadm already placed the config at ~/.kube/config)
kubectl cluster-info
kubectl get nodes

# 3. Copy this repository onto the master
git clone https://github.com/deviant101/K8s-App-Lifecycle-Mgt.git

cd K8s-App-Lifecycle-Mgt
```

---

## Quick start

> All commands below are run **on the master node** after SSH-ing in.

```bash
# From the repo directory on the master node:
cd K8s-App-Lifecycle-Mgt

# 1. Create the namespace
kubectl apply -f k8s/namespace.yaml

# 2. Run all tasks in order (or follow individual task sections below)
kubectl apply -f k8s/01-create/
kubectl apply -f k8s/05-configmap/
kubectl apply -f k8s/06-secret/
kubectl apply -f k8s/07-envvar/
```

---

## Task 1 – Create the Deployment

Deploy Nginx 1.24 with 1 replica and expose it on NodePort 30080.

```bash
kubectl apply -f k8s/01-create/deployment.yaml
kubectl apply -f k8s/01-create/service.yaml

# Verify
kubectl get deployment nginx-deployment -n webapp
kubectl get pods -n webapp -l app=nginx
kubectl get svc nginx-service -n webapp

# Test the NodePort directly from the master node (loopback always works)
curl http://localhost:30080

# Or curl using the node's internal IP
curl http://$(hostname -I | awk '{print $1}'):30080
```

---

## Task 2 – Scale the Deployment

### Scale up to 5 replicas

```bash
kubectl scale deployment nginx-deployment --replicas=5 -n webapp
kubectl rollout status deployment/nginx-deployment -n webapp
kubectl get pods -n webapp -l app=nginx
```

### Scale down to 2 replicas

```bash
kubectl scale deployment nginx-deployment --replicas=2 -n webapp
kubectl rollout status deployment/nginx-deployment -n webapp
kubectl get pods -n webapp -l app=nginx
```

### Using the helper script

```bash
bash k8s/02-scale/scale.sh
```

### Declarative alternative (kubectl patch)

```bash
kubectl patch deployment nginx-deployment -n webapp \
  -p '{"spec":{"replicas":3}}'
```

---

## Task 3 – Rolling Update & Recreate Strategies

### 3-A  RollingUpdate (zero-downtime)

```bash
# Apply the updated deployment (nginx:1.24 → nginx:1.25, RollingUpdate strategy)
kubectl apply -f k8s/03-update/rolling-update.yaml

# Watch pods being replaced one at a time
kubectl get pods -n webapp -w

# Follow the rollout
kubectl rollout status deployment/nginx-deployment -n webapp
```

*Expected behaviour:* New pods come up before old ones are removed. The service
is always available.

### 3-B  Recreate (brief downtime)

```bash
# Apply the Recreate-strategy deployment
kubectl apply -f k8s/03-update/recreate.yaml

# Watch ALL old pods terminate before new ones start
kubectl get pods -n webapp -w
```

*Expected behaviour:* A gap exists between the old pods terminating and the new
pods becoming ready. Use this only when old and new versions cannot run
concurrently (e.g. incompatible database schemas).

### Compare strategies

| | RollingUpdate | Recreate |
|-|---|---|
| Downtime | None | Brief |
| Old + new pods simultaneously | Yes | No |
| Use case | Stateless services | Version-incompatible upgrades |

---

## Task 4 – Roll Back

```bash
# Show the full history (change-cause annotations appear here)
kubectl rollout history deployment/nginx-deployment -n webapp

# Inspect a specific revision
kubectl rollout history deployment/nginx-deployment --revision=1 -n webapp

# Roll back to the previous revision (nginx:1.25 → nginx:1.24)
kubectl rollout undo deployment/nginx-deployment -n webapp

# Roll back to a specific revision number
kubectl rollout undo deployment/nginx-deployment --to-revision=1 -n webapp

# Confirm the active image
kubectl get deployment nginx-deployment -n webapp \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

Or use the helper script:

```bash
bash k8s/04-rollback/rollback.sh
```

---

## Task 5 – Customise the Welcome Page via ConfigMap

The ConfigMap holds a complete `index.html`.  The Deployment mounts it into
Nginx's web root.  **No custom Docker image is required.**

```bash
kubectl apply -f k8s/05-configmap/

# Verify ConfigMap
kubectl describe configmap nginx-html-config -n webapp

# Test from the master node
curl http://localhost:30080   # if you also apply service.yaml with NodePort
# or use the pod IP directly
kubectl get pod -n webapp -l app=nginx-configmap -o wide
curl http://<POD_IP>:80
```

### How it works (volume mount)

```
ConfigMap key: index.html
       ↓  volumeMount
/usr/share/nginx/html/index.html  (inside the Nginx container)
```

### Live-update (no pod restart needed)

```bash
kubectl edit configmap nginx-html-config -n webapp
# Changes propagate to the mounted file within ~60 seconds.
```

---

## Task 6 – Customise the Welcome Page via Secret

Secrets work identically to ConfigMaps for file mounts, but the data is
base64-encoded and treated with stricter RBAC by default.

```bash
kubectl apply -f k8s/06-secret/

# Verify (data is base64-encoded in the output)
kubectl get secret nginx-html-secret -n webapp -o yaml

# Decode to inspect
kubectl get secret nginx-html-secret -n webapp \
  -o jsonpath='{.data.index\.html}' | base64 -d

# Test from the master node using the pod IP
kubectl get pod -n webapp -l app=nginx-secret -o wide
curl http://<POD_IP>:80
```

> **Security note:** Kubernetes Secrets are only base64-encoded, not encrypted,
> by default.  Enable [EncryptionConfiguration](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/)
> or use an external secrets manager in production.

---

## Task 7 – Customise the Welcome Page via Environment Variables

Two approaches are provided in `k8s/07-envvar/deployment.yaml`:

### Approach A – initContainer + emptyDir  *(no custom image)*

An `initContainer` (busybox) reads `env:` variables and writes `index.html` to
a shared `emptyDir` volume before Nginx starts.

```bash
kubectl apply -f k8s/07-envvar/deployment.yaml

# Test from the master node using the pod IP
kubectl get pod -n webapp -l app=nginx-envvar -o wide
curl http://<POD_IP>:80
```

To change a value:

```bash
kubectl set env deployment/nginx-envvar-demo -n webapp \
  WELCOME_MESSAGE="Updated message from Environment Variables!" \
  APP_VERSION="2.0"
# The pod restarts and the initContainer regenerates index.html.
```

### Approach B – Flask app  *(requires building the custom image)*

The Flask app reads env vars **at request time** – no restart needed when
values change, provided the pod is recycled.

```bash
# Build the Flask image directly on the master node
cd ~/3-K8s-App-Lifecycle-Mgt/flask-app
docker build -t flask-nginx-app:1.0 .
cd ..

# NOTE: imagePullPolicy is already set to IfNotPresent in the manifest,
# so K8s uses the locally built image without pulling from a registry.

# Deploy
kubectl apply -f k8s/07-envvar/deployment.yaml

# Test using the pod IP
kubectl get pod -n webapp -l app=flask-envvar -o wide
curl http://<POD_IP>:5000

# Update env vars (triggers a rolling restart)
kubectl set env deployment/flask-envvar-demo -n webapp \
  PAGE_TITLE="K8s Flask App v2" \
  APP_VERSION="2.0" \
  BG_COLOR="#f0fdf4" \
  ACCENT_COLOR="#10b981"
```

---

## Useful one-liners

```bash
# List all resources in the webapp namespace
kubectl get all -n webapp

# Describe a deployment
kubectl describe deployment nginx-deployment -n webapp

# Tail logs from all nginx pods
kubectl logs -l app=nginx -n webapp --follow

# Get events (useful for debugging)
kubectl get events -n webapp --sort-by='.lastTimestamp'

# Delete everything in the namespace
kubectl delete all --all -n webapp
```

---

## Comparison: three customisation methods

| Method | How content is stored | Live update without restart? | Use-case |
|---|---|---|---|
| **ConfigMap** | Plain text in etcd | Yes (~60 s propagation) | Non-sensitive config, HTML, files |
| **Secret** | Base64 in etcd | Yes (~60 s propagation) | TLS certs, tokens, sensitive config |
| **Env Vars** | Pod spec | No (requires pod restart) | Simple scalar values |

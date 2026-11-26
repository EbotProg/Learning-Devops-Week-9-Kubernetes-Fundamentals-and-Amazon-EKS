# Week 9 Notes: Kubernetes Fundamentals + Amazon EKS

> **Goal:** understand what Kubernetes actually solves, then run it for real on AWS.
> **Milestone:** move the app (Next.js frontend + Parse backend + Atlas) onto **EKS** (**Amazon Elastic Kubernetes Service**: AWS's service that runs Kubernetes for you; see Part 0 below, and Part 8 in depth). That means:
>
> - Deployments, Services and an **Ingress with HTTPS**.
> - Secrets pulled from **AWS Secrets Manager via IRSA**.
> - A **Horizontal Pod Autoscaler**, shown scaling under load.
>
> These notes replace the resources (roadmap.sh Kubernetes, eksworkshop.com, kubernetes.io docs). Everything you need is here, explained from zero. **Every bold word above is explained in Part 0, right below.**

**How to read this**

- Parts 1–7 are **Kubernetes itself**. Practise them locally with `kind` (a free tool that runs a practice Kubernetes cluster inside Docker on your laptop; Part 6), which needs no AWS account.
- Parts 8–12 are **Kubernetes on AWS (EKS)**, which costs money.
- Part 13 is the **milestone, step by step**.
- Part 14 has the **cheat sheets**: commands, errors, glossary, and the ECS/Swarm comparison.

Wherever possible, a new idea is compared to something you already know from **Week 8 (ECS)** or the **scenario (Swarm)**.

## **New words.** Every new word is explained the first time it appears (often in brackets right after it), and **every one of them is also in the glossary, Part 14.4**, sorted A–Z with _what it is_ and _what it's used for_. If you meet a word you don't understand, look there first.

# PART 0: The words you need before starting

These are the big words of Week 9. Read this table once; every other new word is explained where it appears and in the **glossary (Part 14.4)**.

| Word                                            | What it is, in plain words                                                                                                   | What it's used for this week                                                            |
| ----------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| **Kubernetes** (K8s)                            | Free, open-source software (started at Google, now run by a neutral foundation) that manages containers across many machines | Runs our frontend and backend: keeps them alive, connects them, scales and updates them |
| **Cluster**                                     | A group of machines that Kubernetes runs as one system                                                                       | Where everything runs: on your laptop with `kind`, then on AWS with EKS                 |
| **Node**                                        | One machine in the cluster                                                                                                   | Our containers run on 2 nodes (EC2 instances) on AWS                                    |
| **Pod**                                         | Kubernetes' wrapper around a running container (≈ an ECS task)                                                               | Each copy of the backend or frontend is one pod                                         |
| **Control plane**                               | The "brain" of the cluster: the programs that store what you want and make it happen                                         | AWS runs it for us on EKS                                                               |
| **EKS** (**Amazon Elastic Kubernetes Service**) | AWS's paid service that runs the Kubernetes control plane for you; you add worker machines                                   | The AWS home of our cluster (Part 8). Costs about $0.10/hour, plus the machines         |
| **kubectl**                                     | The command-line tool for talking to any Kubernetes cluster                                                                  | Every command you'll type: create, list, debug                                          |
| **Manifest**                                    | A YAML file describing Kubernetes objects ("2 copies of this image")                                                         | How you tell Kubernetes what you want                                                   |
| **Helm**                                        | The package manager for Kubernetes: bundles many manifests into one installable, configurable package (a **chart**)          | Installing add-ons, and packaging our app (a deliverable)                               |
| **kind**                                        | A tool that runs a practice cluster inside Docker on your laptop                                                             | Free practice before paying for EKS                                                     |
| **Ingress**                                     | Kubernetes rules saying which web address/path goes to which app                                                             | One public HTTPS address for frontend + backend                                         |
| **HTTPS / TLS certificate**                     | The encryption and identity proof behind the browser padlock                                                                 | The app must be reachable over HTTPS                                                    |
| **AWS Secrets Manager**                         | An AWS service that stores passwords and keys encrypted and controls who can read them                                       | Holds the database URI and Parse master key                                             |
| **IRSA** (**IAM Roles for Service Accounts**)   | The way a specific pod gets its own AWS permissions, with no stored keys (same idea as Week 8's GitHub OIDC login)           | Lets in-cluster helpers read Secrets Manager and create the load balancer               |
| **HPA** (**Horizontal Pod Autoscaler**)         | Automatically adds or removes pods based on CPU use ("horizontal" = more copies, not bigger copies)                          | The scaling demo                                                                        |
| **eksctl**                                      | A command-line tool that creates a whole EKS cluster from one config file                                                    | Creating the cluster quickly (Part 8.6)                                                 |

---

## Table of contents

0. [The words you need before starting](#part-0-the-words-you-need-before-starting)
1. [Why Kubernetes exists](#part-1-why-kubernetes-exists)
2. [How a cluster is built (architecture)](#part-2-how-a-cluster-is-built)
3. [Talking to the cluster: kubectl and YAML](#part-3-talking-to-the-cluster-kubectl-and-yaml)
4. [The core objects, one by one](#part-4-the-core-objects)
5. [Health, resources and autoscaling](#part-5-health-resources-and-autoscaling)
6. [Local lab with kind](#part-6-local-lab-with-kind)
7. [Helm](#part-7-helm)
8. [Amazon EKS](#part-8-amazon-eks)
9. [IAM for pods: IRSA](#part-9-iam-for-pods-irsa)
10. [Secrets Manager → Kubernetes (External Secrets)](#part-10-secrets-manager--kubernetes)
11. [Ingress on EKS + HTTPS](#part-11-ingress-on-eks--https)
12. [Scaling on EKS](#part-12-scaling-on-eks)
13. [The milestone, step by step](#part-13-the-milestone-step-by-step)
14. [Cheat sheets: commands, errors, glossary, comparisons](#part-14-cheat-sheets)

---

# PART 1: Why Kubernetes exists

## 1.1 The problem, in your own history

| Week     | How the app ran                   | What was missing                                                                                         |
| -------- | --------------------------------- | -------------------------------------------------------------------------------------------------------- |
| 5–7      | One EC2 server + `docker compose` | Nothing watches the containers. Single server. No scaling. Downtime on deploy                            |
| Scenario | Docker Swarm                      | Self-healing and rolling updates, but a small ecosystem that few companies use at scale                  |
| 8        | ECS Fargate                       | Excellent, but **AWS-only**: your task definitions don't work on Google Cloud, Azure or your own servers |
| **9**    | **Kubernetes (EKS)**              | The same ideas, but an **open standard** that runs everywhere, with a huge ecosystem                     |

**Kubernetes** (written **K8s**: the 8 stands for the 8 letters between K and s) is a **container orchestrator**. _Orchestrator_ = the thing that decides where containers run, keeps them alive, connects them, scales them and updates them.

**Analogy.** Containers are musicians. Docker can make one musician play. Kubernetes is the **conductor**: it decides who plays where, replaces anyone who stops, adds more violins when the hall is bigger, and swaps sheet music section by section without stopping the concert.

## 1.2 What Kubernetes gives you

1. **Self-healing:** a container crashes, and it's restarted; a whole server dies, and its containers are recreated elsewhere.
2. **Scheduling:** you say "this needs 0.25 CPU and 256 MB", and Kubernetes finds a server with room.
3. **Service discovery + load balancing:** containers find each other by **name** (`backend`), not IP, and traffic is spread across copies.
4. **Rolling updates and rollbacks:** new versions replace old ones gradually; one command undoes it.
5. **Autoscaling:** more copies when busy, fewer when quiet.
6. **Config and secrets** kept separate from images.
7. **Portability:** the same YAML runs on your laptop, EKS (AWS), GKE (Google) or AKS (Azure). These three are each cloud's **managed Kubernetes** service, meaning the cloud company runs the hard parts of Kubernetes for you: **EKS** = Amazon Elastic Kubernetes Service, **GKE** = Google Kubernetes Engine, **AKS** = Azure Kubernetes Service (Microsoft).

You already know 1–5 from ECS and Swarm. **The new things this week** are mostly _the Kubernetes way of expressing them_, plus the AWS glue (IRSA, Load Balancer Controller, Secrets Manager), which connects Kubernetes to AWS services. Each of those is explained in Parts 9–11.

## 1.3 The single most important idea: desired state

You never tell Kubernetes _"start a container"_. You tell it **what you want to exist**:

> "I want 2 copies of `backend:v5` running, each with 256 MB of memory."

Kubernetes stores that wish (the **desired state**). Then little programs called **controllers** run a loop forever:

```
 ┌─────────────────────────────────────────────┐
 │ 1. OBSERVE  what actually runs (actual state)│
 │ 2. COMPARE  with what you asked (desired)    │
 │ 3. ACT      to close the gap                 │
 └──────────────── repeat forever ──────────────┘
```

- One copy crashes → actual = 1, desired = 2 → it starts one.
- You change the image to `v6` → actual = v5, desired = v6 → it rolls out v6.

This is called **reconciliation**, and the style is called **declarative** (you declare the result) as opposed to **imperative** (you give step-by-step commands). Terraform works the same way. ECS services also did this; Kubernetes applies it to _everything_.

**Remember:** if something keeps "coming back" after you delete it, a controller is reconciling it. Delete or change the **owner** (usually the Deployment), not the pod.

---

# PART 2: How a cluster is built

A **cluster** = a group of machines run as one system by Kubernetes. It has two halves.

```
                     ┌──────────── CONTROL PLANE (the brain) ────────────┐
   you ──kubectl──►  │  API server ◄──► etcd (database of desired state) │
                     │  scheduler        controller-manager              │
                     └───────────────────────┬───────────────────────────┘
                                             │ instructions
          ┌──────────────────────────────────┼──────────────────────────────────┐
          ▼                                  ▼                                  ▼
   ┌── NODE 1 ──────────┐            ┌── NODE 2 ──────────┐             (more nodes)
   │ kubelet            │            │ kubelet            │
   │ kube-proxy         │            │ kube-proxy         │
   │ containerd         │            │ containerd         │
   │ [pod] [pod] [pod]  │            │ [pod] [pod]        │
   └────────────────────┘            └────────────────────┘
          WORKER NODES (the muscles: where your containers actually run)
```

## 2.1 Control plane: the brain

| Component                         | What it does                                                                                                                                                                               | Analogy                                                                 |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------- |
| **API server** (`kube-apiserver`) | The **only front door**. kubectl, controllers and nodes all talk to it over HTTPS. It checks who you are and whether you're allowed                                                        | The receptionist: every request goes through them                       |
| **etcd** (say "et-see-dee")       | A small, very reliable **key-value database** (it stores simple pairs like `name → value`, like a dictionary, rather than tables) holding **all desired state** (every object you created) | The company's filing cabinet. Lose it and you lose the cluster's memory |
| **Scheduler**                     | When a new pod has no node yet, it picks a node with enough free CPU/memory                                                                                                                | The person who assigns desks to new employees                           |
| **Controller manager**            | Runs the reconciliation loops (Deployment controller, ReplicaSet controller, Node controller…)                                                                                             | Supervisors who keep checking "is reality what we planned?"             |

On **EKS, AWS runs the whole control plane for you**: it's **highly available** (it keeps working even if a machine or a whole data centre fails, because copies run in 3 AZs), **patched** (security updates applied for you), and you never see those machines. You pay $0.10/hour for it (Part 8).

## 2.2 Worker nodes: the muscles

A **node** = one machine (on EKS, an EC2 instance) that runs your containers. Each node runs:

| Component                                                   | What it does                                                                                                                                                                                                |
| ----------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **kubelet**                                                 | The node's agent. It asks the API server "which pods should be on me?", tells the container runtime to start them, runs health checks, and reports back                                                     |
| **Container runtime** (**containerd**, say "container-dee") | The low-level program that actually pulls images and runs containers. Kubernetes doesn't use Docker Engine itself; it uses containerd, which Docker is also built on. **Your Docker images work unchanged** |
| **kube-proxy**                                              | Programs the node's networking rules so a Service's address reaches the right pods (Part 4.4)                                                                                                               |

**Fargate vs nodes.** In Week 8 (Fargate) there were no servers to manage. With EKS **managed node groups**, you _do_ have EC2 instances (you pick the size, AWS handles creating, updating and replacing them). EKS can also run pods on Fargate, or in **"Auto Mode"** (an EKS option where AWS also chooses, creates and manages the worker machines for you), but the brief asks for **managed node groups**, and they teach you more.

---

# PART 3: Talking to the cluster: kubectl and YAML

## 3.1 kubectl

`kubectl` (say "kube-control" or "kube-cuddle") is the command-line tool. Every command becomes an HTTPS call to the API server. (`-it` on `exec` = interactive terminal, so you can type inside the container, like `docker exec -it`.)

```bash
kubectl get pods                 # list
kubectl describe pod <name>      # details + recent events (the #1 debugging command)
kubectl apply -f file.yaml       # create or update from a file (declarative)
kubectl delete -f file.yaml      # delete what the file describes
kubectl logs <pod>               # container output
kubectl exec -it <pod> -- sh     # shell inside the container
```

**kubeconfig.** kubectl needs to know _which cluster_ and _who you are_. That's stored in `~/.kube/config`. It can hold many clusters; each pairing of cluster + user + default namespace is a **context**.

```bash
kubectl config get-contexts           # list (the * is the current one)
kubectl config use-context kind-w9    # switch
```

**Always check your context before `delete`.** It's easy to be pointed at the wrong cluster.

## 3.2 The anatomy of every Kubernetes YAML file

Every object has the same four top-level parts:

```yaml
apiVersion: apps/v1          # 1. which API "group/version" defines this kind (Kubernetes groups its object types into families, each with a version)
kind: Deployment             # 2. what type of object
metadata:                    # 3. identity: name, namespace, labels
  name: backend
  namespace: crud
  labels:
    app: backend
spec:                        # 4. YOUR DESIRED STATE (what you want)
  replicas: 2
  ...
```

After you apply it, Kubernetes adds a fifth part, **`status`** (the actual state), which you see with `kubectl get ... -o yaml`. **`spec` = wish, `status` = reality.** The controllers work to make status match spec.

Which `apiVersion` goes with which kind (no need to memorise; `kubectl explain <kind>` tells you):

| kind                                                       | apiVersion             |
| ---------------------------------------------------------- | ---------------------- |
| Pod, Service, ConfigMap, Secret, Namespace, ServiceAccount | `v1`                   |
| Deployment, ReplicaSet, StatefulSet, DaemonSet             | `apps/v1`              |
| Ingress, IngressClass                                      | `networking.k8s.io/v1` |
| HorizontalPodAutoscaler                                    | `autoscaling/v2`       |

`kubectl explain deployment.spec.strategy` prints the documentation for any field, so you never need to guess.

## 3.3 Labels and selectors: how objects find each other

This confuses everyone at first, and it's how everything is wired together. (A **manifest** = a YAML file describing Kubernetes objects; the word is used all through these notes.)

- A **label** is a sticker on an object: `app: backend`, `tier: api`, `env: prod`.
- A **selector** is a query: "all pods with `app: backend`".

Objects in Kubernetes **don't point at each other by name**. They find each other by **labels**:

- A **Deployment** manages the pods matching its selector.
- A **Service** sends traffic to the pods matching its selector.
- An **HPA** targets a Deployment by name; the Deployment then finds its pods by label.

```yaml
# Deployment                                   # Service
spec:                                           spec:
  selector:                                       selector:
    matchLabels: { app: backend }  ◄── same ──►     app: backend
  template:
    metadata:
      labels: { app: backend }      ← the sticker put on every pod
```

**Classic bug:** the Service selector says `app: back-end` and the pods say `app: backend`. Nothing errors, but the Service has **no endpoints** and requests hang or fail. Check with `kubectl get endpoints <service>` (empty = selector mismatch).

**Analogy.** Labels are like WhatsApp group membership: you don't list people by name each time; you message "everyone in group _backend_", and whoever has that label receives it, even new members.

---

# PART 4: The core objects

## 4.1 Pod: the smallest unit

**What it is.** A **pod** is one or more containers that are **always placed together on the same node**, share **one IP address** and can share files. In practice, **usually one container per pod**.

**Analogy.** A container is a person; a pod is the apartment they live in, with its own address. Occasionally two people share an apartment (e.g. an app plus a helper container called a **sidecar**, named after a motorbike sidecar because it rides alongside the main container, that ships its logs somewhere), and they reach each other at `localhost`.

**Compared to before:** a pod ≈ an **ECS task** ≈ a **Swarm task**.

Key facts:

- **Pods are disposable (mortal).** When a pod dies, it's not repaired: a **new pod** with a **new name and new IP** replaces it. That's why you never connect to a pod's IP directly (Services solve that).
- Each pod gets an IP from the cluster network. On EKS it's a **real VPC IP** (Part 8.4).
- You almost **never create pods directly**. If you do and it dies, nothing recreates it. You create a **Deployment**, which creates pods for you.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hello
  labels: { app: hello }
spec:
  containers:
    - name: web
      image: nginx:1.27
      ports:
        - containerPort: 80
```

## 4.2 ReplicaSet: keeps N copies alive

A **ReplicaSet** has one job: "make sure exactly N pods matching this label exist". Kill one, and it creates another. **You don't write ReplicaSets yourself**; Deployments create them. You'll just see them in `kubectl get rs`.

## 4.3 Deployment: what you actually write for stateless apps

**What it is.** A **Deployment** = "run N copies of this pod template, and when I change the template, **roll it out safely**". It's the Kubernetes version of an **ECS service** or a **Swarm service**.

**How a rolling update works internally.** When you change the image:

1. The Deployment creates a **new ReplicaSet** (v2) at 0 pods.
2. It scales v2 **up** and the old ReplicaSet (v1) **down**, a few pods at a time.
3. A new pod only counts once it's **Ready** (passes its readiness probe, Part 5.1).
4. At the end, v1 has 0 pods but is **kept**, so rolling back = scaling v1 back up.

```
v1 RS: ●●●●   →  ●●●   →  ●●   →  ●   →  (0, kept for rollback)
v2 RS:        →  ●     →  ●●   →  ●●● →  ●●●●
```

Two knobs control the speed:

- **`maxSurge`**: how many _extra_ pods may exist above `replicas` during the rollout (like Swarm's `start-first`).
- **`maxUnavailable`**: how many may be missing below `replicas`.

`maxSurge: 1, maxUnavailable: 0` = "always start a new one before removing an old one". That's zero-downtime, the same idea as `start-first` in the scenario.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: crud
  labels: { app: backend }
spec:
  replicas: 2
  revisionHistoryLimit: 5 # keep 5 old ReplicaSets for rollback
  selector:
    matchLabels: { app: backend } # MUST match the template labels below
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template: # the pod "recipe" (like an ECS task definition)
    metadata:
      labels: { app: backend }
    spec:
      containers:
        - name: backend
          image: <account>.dkr.ecr.eu-north-1.amazonaws.com/crud-parse-server-backend:abc123
          ports:
            - containerPort: 1337
```

Rollout commands:

```bash
kubectl set image deployment/backend backend=<repo>:newtag -n crud   # change image
kubectl rollout status deployment/backend -n crud                    # watch until done
kubectl rollout history deployment/backend -n crud                   # list revisions
kubectl rollout undo deployment/backend -n crud                      # back to previous
kubectl rollout undo deployment/backend --to-revision=3 -n crud
kubectl rollout restart deployment/backend -n crud                   # recreate all pods (e.g. to pick up a new secret)
```

**Rolling vs blue/green.** A Deployment does **rolling** updates: for a while, old and new run side by side. Blue/green (Week 8) isn't built in; you'd add tools like **Argo Rollouts** (an add-on that gives Kubernetes blue/green and **canary** deployments, where canary = send a small percentage of users to the new version first and increase it gradually; a later week's topic).

**Other workload types** (just know they exist):

- **StatefulSet**: for databases. Stable names (`mongo-0`, `mongo-1`) and each pod gets its own permanent disk (a **PersistentVolume**: storage that survives when the pod is replaced). We use Atlas, so we don't need one.
- **DaemonSet**: exactly one pod **on every node** (log collectors, monitoring **agents** (small helper programs that run on each machine), the EKS networking pod `aws-node`).
- **Job / CronJob**: run to completion once, or on a schedule (database **migrations**, i.e. scripts that change the database structure; backups). "Cron" is the classic Linux scheduler, the same time format you'd use in a GitLab scheduled pipeline.

## 4.4 Service: a stable address for changing pods

**The problem.** Pods come and go with new IPs. How does the frontend reach "the backend" reliably?

**What it is.** A **Service** is a **permanent name + virtual IP** (an IP address that doesn't belong to any one machine; the nodes' networking rules catch traffic to it and forward it to a real pod) in front of a set of pods (chosen by label selector). It load-balances across whichever matching pods are **Ready** right now.

**Analogy.** A company's switchboard number. Employees (pods) change desks and phone extensions, but customers always dial the same main number and get connected to whoever is available.

**Built-in DNS.** Every Service gets a DNS name automatically (provided by **CoreDNS**, a small DNS server that runs as pods inside the cluster and answers "what IP is `backend`?"):

```
backend                          ← from a pod in the same namespace
backend.crud                     ← from another namespace
backend.crud.svc.cluster.local   ← the full name
```

So the frontend can call `http://backend:1337/parse`, with no IPs anywhere.

**The four Service types:**

| type                    | Reachable from                                                                                                                                                        | Use it for                                                                                                                                                                                                                  |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **ClusterIP** (default) | Inside the cluster only                                                                                                                                               | App-to-app traffic. **Most Services**                                                                                                                                                                                       |
| **NodePort**            | Every node's IP on a port 30000–32767                                                                                                                                 | Testing, or as a building block                                                                                                                                                                                             |
| **LoadBalancer**        | The internet, via a cloud load balancer created **per Service**                                                                                                       | Quick exposure of one service. On AWS it creates an **NLB** (**Network Load Balancer**: AWS's other load balancer type; it forwards raw connections and can't route by URL path like the ALB). Expensive with many services |
| ExternalName            | n/a: gives something **outside** the cluster (e.g. a managed database's hostname) an in-cluster name. It's a DNS **alias** (a second name pointing to the same place) | Rare                                                                                                                                                                                                                        |

**For the milestone:** both services are **ClusterIP**. The internet reaches them through **one Ingress** (one ALB), not one load balancer each.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: crud
spec:
  type: ClusterIP
  selector: { app: backend } # which pods receive traffic
  ports:
    - name: http
      port: 1337 # the port OTHERS call: backend:1337
      targetPort: 1337 # the containerPort inside the pod
```

`port` vs `targetPort`: `port` is what callers use; `targetPort` is where the container listens. They can differ (e.g. `port: 80` → `targetPort: 3000`).

**Endpoints.** Behind the scenes, Kubernetes keeps a list of the IPs of the Ready pods matching the selector. `kubectl get endpointslices -n crud` (or `kubectl get endpoints`) shows it. **Empty list = no Ready pods or wrong selector.**

## 4.5 Namespace: folders for objects

**What it is.** A **namespace** groups objects inside one cluster: `crud` for our app, `kube-system` for Kubernetes' own components, `external-secrets` for the secrets operator.

- Names only need to be unique **inside** a namespace.
- Permissions (**RBAC**, Role-Based Access Control: Kubernetes' own permission system, "user X may read pods in namespace Y") and **quotas** (limits like "this namespace may use at most 4 CPUs in total") can be set per namespace.
- It's **not** a strong security wall by default: pods in different namespaces can still talk over the network unless you add **NetworkPolicies** (firewall rules between pods, like security groups but inside the cluster).

```bash
kubectl create namespace crud
kubectl get pods -n crud            # -n = which namespace
kubectl get pods -A                 # all namespaces
kubectl config set-context --current --namespace=crud   # stop typing -n
```

## 4.6 ConfigMap: non-secret settings

**What it is.** Key-value settings kept **outside the image**, so the same image runs in dev and prod with different config. Like the `environment:` section of `docker-compose.yml`, but as its own object.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-config
  namespace: crud
data:
  PORT: "1337"
  APP_ID: "myAppId"
  SERVER_URL: "http://localhost:1337/parse"
```

Use it in a container:

```yaml
containers:
  - name: backend
    envFrom:
      - configMapRef: { name: backend-config } # every key becomes an env var
```

or mount it as files for config files like `nginx.conf`. A **volume** is storage attached to a pod; **volumeMounts** says at which folder path inside the container it appears (like `-v` in `docker run`).

**Gotcha.** Changing a ConfigMap does **not** restart pods. Env vars are read only when the container starts, so run `kubectl rollout restart deployment/backend`.

## 4.7 Secret: sensitive settings (and why it's not as secret as it sounds)

**What it is.** The same idea as a ConfigMap, for passwords, keys and connection strings (`DATABASE_URI`, `MASTER_KEY`).

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: backend-secrets
  namespace: crud
type: Opaque
stringData: # write plain text here; K8s stores it base64-encoded
  DATABASE_URI: "mongodb+srv://..."
  MASTER_KEY: "..."
```

**Critical understanding: base64 is NOT encryption.**

- **base64** is an **encoding**: a way of rewriting any data using only safe text characters (A–Z, a–z, 0–9, `+`, `/`), so it can travel inside YAML or JSON. Anyone can reverse it, with no key needed.
- **Encryption** scrambles data so it can only be read with a secret **key**.

`echo bXlwYXNz | base64 -d` gives back the password instantly. A Secret only differs from a ConfigMap in that:

- It can be locked down separately with permissions (RBAC).
- It's not printed by default in some commands.
- On EKS, it can be **encrypted in etcd with a KMS key** (an option you turn on).

> **What is KMS?** **AWS KMS (Key Management Service)** is the AWS service that creates and guards **encryption keys**. The key itself never leaves AWS's secure hardware; you never see or download it. Other services ask KMS to encrypt or decrypt data for them, and IAM decides who's allowed to ask.
>
> **Used for:** encrypting data "at rest" (stored on disk), e.g. S3 objects, EBS disks, Secrets Manager secrets, and here the Secrets inside EKS's etcd database.
>
> **Why it matters here:** with KMS encryption turned on, even someone who got a copy of the etcd database files would only see scrambled data.
>
> **Analogy:** KMS is a bank vault that holds the only key. You hand the bank a box to lock or unlock; you never take the key home.
>
> **Cost:** about $1/month per key, plus a tiny fee per use. **Not needed for this milestone.** It's a production hardening step to mention in your write-up.

So **never commit a Secret YAML with real values to Git**. That's the whole reason for **Part 10**: the real value lives in **AWS Secrets Manager** (an AWS service that stores passwords and keys encrypted, controls who can read them and can change them on a schedule), and a controller _creates_ the Kubernetes Secret inside the cluster. Git only contains a pointer ("fetch `crud/backend` from Secrets Manager").

Use it like a ConfigMap:

```yaml
envFrom:
  - secretRef: { name: backend-secrets }
```

## 4.8 Ingress: one front door, HTTP routing by host/path

**The problem.** You have two Services and want **one** public address with HTTPS: `/` → frontend, `/parse` → backend. Creating a `LoadBalancer` Service for each means two load balancers and no path routing.

**What it is.** An **Ingress** is a set of **HTTP routing rules**:

> "requests for host `w9.ebotprog.ink` path `/parse` → Service `backend:1337`; everything else → Service `frontend:3000`; use this TLS certificate."

(A **TLS certificate** is what makes HTTPS work: the padlock in the browser. Explained fully in Part 11.2.)

**The part everyone misses: an Ingress object does nothing on its own.** It's just a rule sheet. You need an **Ingress controller**, a program running in the cluster that **reads** Ingress objects and **builds a real load balancer** from them.

| Ingress controller               | What it builds                                                                                                                                                    | Note                                                                                                               |
| -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| **AWS Load Balancer Controller** | A real **AWS ALB** (the same thing as Week 8)                                                                                                                     | **What we use on EKS**                                                                                             |
| ingress-nginx                    | An **NGINX** (a popular web server) **proxy** (a middleman server that receives requests and forwards them to the right place) running as pods inside the cluster | **Retired**: no updates or security fixes since March 2026. Many old tutorials still use it; avoid it for new work |
| Traefik, HAProxy, Kong, etc.     | Their own proxies                                                                                                                                                 | Other open-source proxy products that also work as Ingress controllers                                             |

**Analogy.** The Ingress is the **floor plan** of the reception desk ("visitors for accounting → 2nd floor"). The Ingress controller is the **builder** who reads the plan and actually builds the reception.

**Mapping to Week 8:**

| Week 8 (Terraform)        | Week 9 (Kubernetes)                                                        |
| ------------------------- | -------------------------------------------------------------------------- |
| `aws_lb` (ALB)            | Created **automatically** by the Load Balancer Controller from the Ingress |
| `aws_lb_listener` + rules | The Ingress `rules` (host/path)                                            |
| `aws_lb_target_group`     | Created automatically per Service                                          |
| Target registration       | Automatic: pod IPs are registered as they become Ready                     |

The Ingress YAML for our app is in Part 11.

**What comes after Ingress.** **Gateway API** is the newer, more powerful replacement standard. It splits the job into separate objects: a **Gateway** (the entry point itself, owned by the platform team) and **HTTPRoute**s (the routing rules, owned by each app team). That lets different teams share one load balancer safely, and it supports things Ingress can't express cleanly, like sending 10% of traffic to a new version. The AWS Load Balancer Controller supports it too. The brief asks for Ingress, and it's still everywhere, so learn Ingress first and just know Gateway API is the future.

---

# PART 5: Health, resources and autoscaling

## 5.1 Probes: how Kubernetes knows a container is OK

The kubelet checks your container periodically. There are three kinds of check, each with a **different consequence**:

| Probe              | Question it asks                      | If it fails…                                                           | Analogy                                                   |
| ------------------ | ------------------------------------- | ---------------------------------------------------------------------- | --------------------------------------------------------- |
| **readinessProbe** | "Can you take traffic **right now**?" | Pod is **removed from the Service** (no traffic) but **not restarted** | A cashier puts up a "closed" sign while counting the till |
| **livenessProbe**  | "Are you still alive, or stuck?"      | Container is **killed and restarted**                                  | The manager sees a frozen cashier and replaces them       |
| **startupProbe**   | "Have you finished starting?"         | Liveness/readiness wait until this passes; if it never passes, restart | Give new staff time to settle before judging them         |

```yaml
readinessProbe:
  httpGet: { path: /parse/health, port: 1337 }
  initialDelaySeconds: 5
  periodSeconds: 10
  failureThreshold: 3
livenessProbe:
  httpGet: { path: /parse/health, port: 1337 }
  initialDelaySeconds: 30 # don't kill it while it boots
  periodSeconds: 20
  failureThreshold: 3
```

**Rules of thumb**

- **Always set readiness.** Without it, a pod gets traffic the moment its process starts, before it's actually ready. That causes errors during every rollout.
- Make liveness **more forgiving** than readiness. An over-eager liveness probe causes endless restarts (**CrashLoopBackOff**: Kubernetes' status for "this container keeps crashing, so I wait longer and longer between restarts": 10 s, 20 s, 40 s… up to 5 minutes) under load.
- Don't make liveness depend on the database: if Atlas blips, Kubernetes would restart all your healthy pods, which doesn't help.

Compared to before: ALB target group health checks (Week 8) and the Swarm `healthcheck` (scenario). In Kubernetes, **readiness** feeds the Service _and_ the ALB, because the Load Balancer Controller registers only Ready pods.

## 5.2 Requests and limits: telling Kubernetes how big a container is

```yaml
resources:
  requests: { cpu: "250m", memory: "256Mi" } # reserved: used for scheduling
  limits: { memory: "512Mi" } # hard ceiling
```

- **CPU units:** `1` = one **vCPU** (virtual CPU: one processor core's worth of computing, as AWS sells it); `250m` = 250 **millicores** (thousandths of a core) = a quarter of a core.
- **Memory units:** `Mi` = **mebibytes** (1 Mi = 1024 × 1024 = 1,048,576 bytes), `Gi` = **gibibytes** (1024 Mi). `M` (megabyte) means 1,000,000 bytes, about 5% less. Use `Mi`/`Gi`, the way Kubernetes examples do, to avoid confusion.

|                   | request                                                              | limit                                                                                                                 |
| ----------------- | -------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Meaning           | "Guarantee me at least this much"                                    | "Never let me use more than this"                                                                                     |
| Used by           | The **scheduler**, to pick a node with this much **unreserved** room | The **kubelet/kernel** (the **kernel** is the core of the Linux operating system; it enforces the limits), at runtime |
| CPU over limit    | n/a                                                                  | **Throttled** (slowed down, not killed)                                                                               |
| Memory over limit | n/a                                                                  | **Killed** (`OOMKilled`: **OOM** = Out Of Memory; the kernel's "OOM killer" ends the process), then restarted         |

**Connection to the scenario fire drill.** That was the memory leak you contained with a 512M limit in Swarm. Exactly the same idea: the leak gets `OOMKilled` inside its own container instead of eating the node.

**Why requests matter so much:**

1. **Scheduling:** if no node has enough unreserved room for the request, the pod stays **Pending**.
2. **The HPA calculates CPU % relative to the request.** No CPU request means the HPA **can't work** (it shows `<unknown>`).

Common practice: set CPU and memory **requests**, and a memory **limit**. Many teams skip the CPU limit to avoid throttling. Either is acceptable for this milestone.

## 5.3 Horizontal Pod Autoscaler (HPA)

**What it is.** A controller that changes a Deployment's `replicas` based on a metric, usually average CPU. It's the same idea as Week 8's ECS **target tracking** (keep CPU around 60%).

**What it needs:**

1. **metrics-server** installed in the cluster. It collects CPU/memory usage from every kubelet. Check with `kubectl top pods`; if that errors, the HPA can't work.
2. **CPU requests** on the containers.

**The formula** (worth understanding, because you'll explain it in a demo):

```
desiredReplicas = ceil( currentReplicas × currentUtilization / targetUtilization )
```

(`ceil` = **ceiling**: round **up** to the next whole number, so 3.2 becomes 4. You can't run 3.2 pods.)

Example: 2 pods at 120% of their CPU request, target 60% → `ceil(2 × 120/60)` = **4 pods**.

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: frontend
  namespace: crud
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: frontend
  minReplicas: 2
  maxReplicas: 6
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 60 # % of the CPU *request*
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 120 # wait 2 min of low load before removing pods
```

- **Scale-up** reacts within about 15–30 seconds (metrics-server collects every ~15 s; the HPA checks every 15 s). That's faster than ECS's 3-minute alarm in Week 8.
- **Scale-down** waits for the stabilization window (default **5 minutes**) to avoid **flapping** (scaling up and down over and over as the load wobbles, which wastes effort and disturbs users).
- **Don't set `replicas:` in the Deployment once an HPA manages it**, or every `kubectl apply` resets the count. (In Helm, leave `replicas` out when autoscaling is enabled.)

**HPA vs node scaling.** The HPA adds **pods**. If the nodes are full, new pods sit in **Pending**. Adding **nodes** is a different tool (**Cluster Autoscaler** or **Karpenter**, both add EC2 machines when pods can't fit; see Part 12).

---

# PART 6: Local lab with kind

**kind** = **K**ubernetes **in D**ocker. Each "node" is a Docker container on your laptop. It's free and starts in about a minute, so it's perfect for learning. **minikube** is the alternative (another local-cluster tool; it runs the cluster in a **VM**, a virtual machine, or a container); the brief allows either, and these notes use kind.

## 6.1 Install (Windows + Git Bash, or Linux)

You need Docker Desktop running. Then install the three tools. **winget** is Windows' built-in command-line app installer (like `apt` on Ubuntu):

```bash
# kubectl
winget install -e --id Kubernetes.kubectl        # Windows
# kind
winget install -e --id Kubernetes.kind           # Windows
# helm
winget install -e --id Helm.Helm                 # Windows

# Linux alternatives:
# curl -Lo kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64 && chmod +x kind && sudo mv kind /usr/local/bin/
# kubectl/helm: see their official install pages, or use your package manager

kubectl version --client && kind version && helm version
```

## 6.2 Create a cluster

`kind-config.yaml`, one control plane + two workers (so you see scheduling across nodes):

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: w9
nodes:
  - role: control-plane
    extraPortMappings: # opens port 8080 on your laptop → port 80 in the cluster (optional, for testing an ingress later)
      - containerPort: 80
        hostPort: 8080
  - role: worker
  - role: worker
```

```bash
kind create cluster --config kind-config.yaml
kubectl get nodes -o wide          # 3 nodes, STATUS Ready
kubectl get pods -A                # system pods: coredns, kube-proxy, etcd, apiserver...
```

## 6.3 Exercise 1: feel self-healing and scaling (10 minutes)

```bash
kubectl create namespace lab
kubectl create deployment web --image=nginx:1.27 --replicas=3 -n lab
kubectl get pods -n lab -o wide                  # 3 pods spread across workers

kubectl delete pod -n lab <one-pod-name>         # kill one
kubectl get pods -n lab -w                       # watch a NEW one appear (Ctrl+C to stop)

kubectl scale deployment web --replicas=5 -n lab
kubectl expose deployment web --port=80 -n lab   # creates a ClusterIP Service
kubectl port-forward -n lab svc/web 8081:80      # open http://localhost:8081
```

**`port-forward`** creates a temporary **tunnel** (a private connection that carries traffic from one place to another) from your laptop into the cluster. It's for testing only; it's not how users reach apps.

`expose` creates a Service for the Deployment; `-w` means **watch** (keep the list open and print changes live).

## 6.4 Exercise 2: rolling update and rollback

```bash
kubectl set image deployment/web nginx=nginx:1.27-alpine -n lab
kubectl rollout status deployment/web -n lab
kubectl get rs -n lab                            # old RS at 0, new RS at 5
kubectl set image deployment/web nginx=nginx:does-not-exist -n lab
kubectl get pods -n lab                          # new pods: ErrImagePull / ImagePullBackOff
                                                 # old pods still running → users unaffected (maxUnavailable)
kubectl rollout undo deployment/web -n lab       # back to the last good version
```

The failed rollout **stalls** and doesn't remove the healthy old pods, because the new ones never become Ready. Unlike ECS's circuit breaker, a Deployment **does not roll back automatically**: it waits (and reports `ProgressDeadlineExceeded`, meaning "the rollout didn't make progress within the deadline", after 10 minutes). You or your pipeline run `rollout undo`.

## 6.5 Exercise 3: your real app on kind

Use your own images. Build them locally and **load** them into kind (kind nodes can't see your laptop's Docker images otherwise):

```bash
docker build -t crud-backend:dev ./backend
docker build -t crud-frontend:dev ./frontend
kind load docker-image crud-backend:dev crud-frontend:dev --name w9
```

In the Deployment, use `image: crud-backend:dev` with `imagePullPolicy: IfNotPresent` ("only download the image if the node doesn't already have it"). Otherwise Kubernetes tries to download it from Docker Hub and fails.

For the database locally, use your **Atlas** connection string. Your home IP must be allow-listed in Atlas, so add it temporarily. Then apply the manifests from Part 13 (without the AWS-only pieces: the Ingress annotations, ExternalSecret and IRSA) and use `port-forward` to test.

Finally, practise the HPA locally. Install metrics-server; kind needs one extra flag because its kubelets use **self-signed certificates** (certificates the machine created for itself instead of getting one from a trusted authority, so other programs refuse to trust them by default). The `patch` command edits one field of an existing object in place, here adding the `--kubelet-insecure-tls` flag ("accept those certificates"; fine on a laptop, never in production):

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
kubectl top nodes          # works after ~1 minute
```

## 6.6 Delete when done

```bash
kind delete cluster --name w9
```

---

# PART 7: Helm

## 7.1 Why Helm exists

After Part 6, you'll have ~8 YAML files with values repeated everywhere: image tag, namespace, replica counts, ports. For staging vs production you'd copy them all and edit by hand. Helm fixes this.

**Helm = the package manager for Kubernetes** (like `apt` or `npm`), plus a **templating** system. **Templating** = writing a file once with blanks (placeholders), then filling the blanks with different values to produce different final files, like a letter template with `{name}` in it.

| Word                  | Meaning                                                                      | Analogy                                          |
| --------------------- | ---------------------------------------------------------------------------- | ------------------------------------------------ |
| **Chart**             | A folder of **templated** YAML + default values                              | A recipe with blanks: "use \_\_\_ cups of sugar" |
| **values.yaml**       | The values that fill the blanks                                              | Your shopping list                               |
| **Release**           | One **installed** copy of a chart in a cluster, with a name                  | One cake baked from the recipe                   |
| **Repository** (repo) | A website you download charts from (e.g. `https://aws.github.io/eks-charts`) | A recipe website                                 |
| **Revision**          | Each install/upgrade of a release gets a number, so you can roll back        | Versions of the cake                             |

You'll use Helm **two ways** this week:

1. **To install other people's software**: the AWS Load Balancer Controller, External Secrets, metrics-server.
2. **To package your own app** as a chart (the milestone deliverable).

## 7.2 Using existing charts

```bash
helm repo add eks https://aws.github.io/eks-charts     # add a repository
helm repo update                                        # refresh its index
helm search repo eks/aws-load-balancer-controller       # find a chart
helm show values eks/aws-load-balancer-controller | less   # see what you can configure (less = scrollable viewer; q to quit)

helm install <release-name> <chart> -n <namespace> --create-namespace \
  --set key=value  -f my-values.yaml

helm list -A                       # installed releases
helm upgrade <release> <chart> -f my-values.yaml
helm history <release> -n <ns>
helm rollback <release> <revision> -n <ns>
helm uninstall <release> -n <ns>
```

`helm upgrade --install` = "install if missing, upgrade if present". That's what pipelines use.

## 7.3 Your own chart: structure

```bash
helm create crud      # generates a sample; delete most of templates/ and write your own
```

```
crud/
├── Chart.yaml            # name, chart version, app version
├── values.yaml           # default values (the blanks' defaults)
├── values-prod.yaml      # overrides for production (optional, you create it)
└── templates/            # YAML with {{ placeholders }}
    ├── _helpers.tpl      # reusable snippets (names, labels)
    ├── backend.yaml      # Deployment + Service
    ├── frontend.yaml
    ├── ingress.yaml
    ├── hpa.yaml
    ├── externalsecret.yaml
    └── serviceaccount.yaml
```

## 7.4 Template syntax (the 6 things you need)

Helm uses **Go templates** (the template language of the Go programming language, which Helm and Kubernetes are written in). Everything between `{{ }}` is replaced when Helm renders the chart.

```yaml
# values.yaml
backend:
  image:
    repository: 123456789012.dkr.ecr.eu-north-1.amazonaws.com/crud-parse-server-backend
    tag: "abc123"
  replicas: 2
  port: 1337
  resources:
    requests: { cpu: 250m, memory: 256Mi }
    limits: { memory: 512Mi }
autoscaling:
  enabled: true
```

```yaml
# templates/backend.yaml (excerpt)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  labels: {{- include "crud.labels" . | nindent 4 }}           # 6. reuse a helper
spec:
  {{- if not .Values.autoscaling.enabled }}                      # 3. if/else
  replicas: {{ .Values.backend.replicas }}                       # 1. insert a value
  {{- end }}
  template:
    spec:
      containers:
        - name: backend
          image: "{{ .Values.backend.image.repository }}:{{ .Values.backend.image.tag }}"
          ports:
            - containerPort: {{ .Values.backend.port }}
          resources: {{- toYaml .Values.backend.resources | nindent 12 }}   # 4. dump a YAML block
          env:
            - name: RELEASE
              value: {{ .Release.Name | quote }}                 # 2. built-ins + 5. pipe to a function
```

1. `{{ .Values.x.y }}`: a value from values.yaml.
2. `.Release.Name`, `.Release.Namespace`, `.Chart.Version`: built-in information.
3. `{{- if ... }} ... {{- end }}`: conditionals. The `-` trims whitespace (removing it causes blank lines and indentation bugs).
4. `toYaml ... | nindent 12`: insert a whole YAML block, indented 12 spaces.
5. `| quote`, `| default "x"`: functions applied with a **pipe** (`|` passes the value on the left into the function on the right, like in a shell). `quote` wraps it in quotes; `default` supplies a value if none is set.
6. `include "name" .`: reuse a snippet from `_helpers.tpl`.

**Indentation is the #1 Helm bug.** Always render before installing:

```bash
helm lint ./crud                                    # syntax checks (a "linter" checks files for mistakes without running them)
helm template crud ./crud -f values-prod.yaml       # print the final YAML: read it!
helm install crud ./crud -n crud --create-namespace --dry-run=server   # dry run = rehearse without changing anything; the API server validates
```

Deploying a new version from CI then becomes one line:

```bash
helm upgrade --install crud ./crud -n crud -f values-prod.yaml --set backend.image.tag=$GIT_SHA --wait
```

`--wait` makes Helm wait until the pods are Ready, so the pipeline fails if the rollout fails. Add `--atomic` to **automatically roll back** if it fails. That's like ECS's circuit breaker.

---

# PART 8: Amazon EKS

## 8.1 What EKS is (and isn't)

**EKS (Elastic Kubernetes Service)** = AWS runs the **control plane** (API server, etcd, scheduler, controllers) for you. It's redundant across 3 AZs, patched and backed up. **You** provide the worker nodes and everything you deploy.

| AWS manages                                                                  | You manage                                                        |
| ---------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| Control plane availability, etcd backups, API server scaling                 | Node groups (size, count, when to upgrade)                        |
| Kubernetes version upgrades of the control plane (when **you** trigger them) | Everything in the cluster: your apps, Ingress controller, add-ons |
| Integration with IAM, VPC, CloudWatch                                        | Upgrading the nodes and add-ons after a control-plane upgrade     |

**Versions.** Kubernetes versions look like `1.36`. The second number is the **minor version**, and a new one comes out about 3 times a year. EKS supports each one for **14 months (standard support**: normal price, security fixes**)**, then **12 more months (extended support**: still fixed, but the control plane costs 6× more, to push you to upgrade**)**. After that, AWS upgrades the cluster for you automatically. As of late 2026, the newest on EKS is **1.36** (released on EKS June 2026). Create new clusters on the latest version.

## 8.2 What it costs (read this before creating anything)

| Item                    | Approx. price                               | Notes                                                                                  |
| ----------------------- | ------------------------------------------- | -------------------------------------------------------------------------------------- |
| EKS control plane       | **$0.10/hour** (≈ $73/month)                | Charged even if no pods run. **$0.60/hour** if the version falls into extended support |
| 2 × t3.medium nodes     | ≈ $0.09/hour together                       | Region-dependent                                                                       |
| NAT gateway             | ≈ $0.05/hour + data                         | For nodes in private subnets                                                           |
| ALB (from the Ingress)  | ≈ $0.025/hour + usage                       |                                                                                        |
| **Total while running** | **roughly $0.25–0.30/hour, about $6–7/day** |                                                                                        |

**So:** practise everything locally on kind (free). Create EKS only when ready to do the milestone, finish in one sitting or two, take your screenshots, then **delete it the same day**. Leaving it on for a month costs about $200.

## 8.3 Managed node groups

A **node group** = a set of identical EC2 instances that act as worker nodes. **Managed** means AWS:

- creates them in an **Auto Scaling Group** (ASG: an AWS feature that keeps a set number of EC2 instances running, replaces failed ones, and can add or remove instances between a min and a max);
- uses the right **EKS-optimised AMI** (**AMI** = Amazon Machine Image, the disk template an EC2 instance boots from, i.e. its operating system plus pre-installed software; the EKS-optimised one already has kubelet and containerd);
- joins them to the cluster;
- replaces or upgrades them gracefully, moving pods off a node before removing it. That's called **draining** the node.

You choose:

- **Instance type**: `t3.medium` (2 vCPU, 4 GiB) is the usual learning choice. Don't use t3.small (see 8.4).
- **min / desired / max** size, e.g. 2 / 2 / 4.
- **Subnets**: private subnets (like Week 8's tasks).

Alternatives you'll hear about: **Fargate on EKS** (one pod = one Fargate **micro-VM**, a tiny, fast-starting virtual machine just for that pod; no nodes for you to manage) and **EKS Auto Mode** (AWS also manages the nodes and the main add-ons). Both hide what you're meant to learn this week.

## 8.4 Networking: the VPC CNI (pods get real VPC IPs)

On EKS, the network add-on is the **Amazon VPC CNI** (it shows up as the `aws-node` DaemonSet). **CNI** = **Container Network Interface**: the standard "plug-in socket" through which Kubernetes hands all pod networking (giving IPs, connecting pods) to a **plugin**. Different plugins do it differently; AWS's plugin uses real VPC addresses. It gives **every pod a real IP address from your VPC subnet**, just like each Fargate task had its own IP in Week 8 (`awsvpc` mode).

Why that matters:

- The **ALB can send traffic straight to pod IPs** (`target-type: ip`), the same as Week 8's target groups.
- Security groups and **VPC flow logs** (AWS's optional record of which IPs talked to which, used for security investigations) see pods as normal VPC addresses.
- **Limit: pods per node.** IPs come from the instance's **ENIs** (**Elastic Network Interfaces**: virtual network cards attached to an EC2 instance; each one holds a few IP addresses), and each instance type supports a limited number of ENIs and IPs. **t3.medium = 17 pods max, t3.small = 11.**
  - That count includes system pods: aws-node, kube-proxy, CoreDNS ×2, Load Balancer Controller ×2, External Secrets ×3, metrics-server…
  - On small nodes, your own pods get stuck **Pending** with "Too many pods". That's why we use t3.medium.

Also add-ons by default: **kube-proxy** and **CoreDNS** (cluster DNS). Together with the VPC CNI, these are installed as **EKS add-ons** (versions of these components that AWS packages, tests and lets you install or upgrade with one click or command).

## 8.5 Who can use the cluster: access entries

Two different permission systems meet in EKS:

- **AWS IAM** decides _who you are_ (your IAM user or role).
- **Kubernetes RBAC** decides _what you may do inside the cluster_ (read pods, create deployments…).

**Access entries** (the current EKS feature for this) connect the two: "IAM principal X gets Kubernetes policy Y". An **IAM principal** = anything that can log in to AWS and make requests: an IAM user, or an IAM role (like your GitHub OIDC role). The person who creates the cluster (with eksctl) is automatically given **cluster admin**.

To give someone else access, or your CI role later:

```bash
aws eks create-access-entry --cluster-name w9 --principal-arn arn:aws:iam::<acct>:role/<role>
aws eks associate-access-policy --cluster-name w9 --principal-arn arn:aws:iam::<acct>:role/<role> \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy --access-scope type=cluster
```

Older guides edit a ConfigMap called **`aws-auth`**. That's the **deprecated** method (still works, but officially being phased out); use access entries.

**Connecting kubectl to EKS:**

```bash
aws eks update-kubeconfig --region eu-north-1 --name w9
kubectl get nodes
```

## 8.6 eksctl: create a cluster from one file

**eksctl** is the official command-line tool for EKS. One config file creates the VPC (public + private subnets, NAT), the control plane, the node group, the IAM roles and the OIDC provider (for IRSA). It uses **CloudFormation** underneath. CloudFormation is AWS's own infrastructure-as-code service (AWS's built-in alternative to Terraform). Each group of resources it creates is called a **stack**, and you can watch the stacks being built in the AWS console (CloudFormation → Stacks).

Install: `winget install -e --id eksctl.eksctl` (Windows) or see eksctl.io.

`cluster.yaml`:

```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: w9
  region: eu-north-1
  version: "1.36" # use the newest version EKS offers when you create it
iam:
  withOIDC: true # REQUIRED for IRSA (Part 9)
managedNodeGroups:
  - name: ng-default
    instanceType: t3.medium
    minSize: 2
    desiredCapacity: 2
    maxSize: 4
    privateNetworking: true # nodes in private subnets (like Week 8 tasks)
    volumeSize: 20
    labels: { role: general }
addons:
  - name: vpc-cni
  - name: coredns
  - name: kube-proxy
  - name: metrics-server # needed by the HPA
```

```bash
eksctl create cluster -f cluster.yaml     # ~15–20 minutes
kubectl get nodes                         # 2 nodes Ready
kubectl get pods -A
```

eksctl also **tags the subnets** so the Load Balancer Controller knows where to put ALBs (`kubernetes.io/role/elb=1` on public, `kubernetes.io/role/internal-elb=1` on private). If you build the VPC yourself (Terraform), **you must add these tags**, or the controller fails with "couldn't auto-discover subnets".

Delete (removes everything eksctl created, including the NAT):

```bash
eksctl delete cluster -f cluster.yaml --disable-nodegroup-eviction
```

`--disable-nodegroup-eviction` = don't bother moving pods gracefully to other nodes before deleting, because everything is being deleted anyway. That's faster, and it avoids getting stuck.

**Delete the Ingress first** (`kubectl delete ingress --all -A`) so the controller removes its ALB. Otherwise the ALB is orphaned, keeps costing money, and can block the VPC deletion.

## 8.7 "Then codify it in Terraform"

The brief says: eksctl to start, **then Terraform**. The common approach is the **community modules**. A **Terraform module** is a ready-made, reusable package of Terraform code (like a function): you pass it a few inputs, and it creates dozens of resources correctly. The `terraform-aws-modules` collection is open-source and maintained by the community; it's the most widely used:

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  # ... 2 AZs, public + private subnets, single NAT,
  # public_subnet_tags  = { "kubernetes.io/role/elb" = 1 }
  # private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1 }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  # cluster name + version, vpc_id, subnet_ids (private),
  # enable_cluster_creator_admin_permissions = true
  # eks_managed_node_groups = { default = { instance_types = ["t3.medium"], min_size = 2, max_size = 4, desired_size = 2 } }
  # cluster addons: coredns, kube-proxy, vpc-cni, metrics-server
}
```

Use the same **remote state** pattern as Week 8: the S3 bucket `ebotprog-terraform-state`, a new key `week9/terraform.tfstate`, and the `terraform-locks` table. **Pin the module versions** (write an exact `version = "..."`, so a future release can't silently change your infrastructure) and read each module's README for the exact input names, because they change between major versions.

**A reasonable split:**

- **Terraform:** VPC, EKS, node group, IAM roles for IRSA, the Secrets Manager secret, the ACM certificate.
- **Helm:** everything _inside_ the cluster (controllers + your app).

Mixing in-cluster objects into Terraform works, but makes destroy and upgrades fragile.

---

# PART 9: IAM for pods: IRSA

## 9.1 The problem

Some pods need to call AWS APIs:

- The **Load Balancer Controller** must create ALBs.
- **External Secrets** must read Secrets Manager.

How do they get AWS permissions?

| Bad option                                   | Why it's bad                                                                                            |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| Put AWS access keys in a Secret              | Long-lived keys that leak and never expire. Exactly what we avoided with OIDC in Week 8                 |
| Give the **node's** IAM role the permissions | **Every** pod on that node inherits them: your frontend could create load balancers or read all secrets |

We want: **this specific pod gets this specific role, and nothing else gets it.**

## 9.2 You already know the answer from Week 8

In Week 8, **GitHub Actions** got AWS credentials without stored keys:

1. GitHub issued a signed token: "I am repo X, branch Y".
2. AWS trusted GitHub's **OIDC provider**.
3. The IAM role's **trust policy** said "allow tokens whose `sub` is `repo:EbotProg/...`".
4. AWS returned **temporary credentials** (`AssumeRoleWithWebIdentity`).

(That last call belongs to **AWS STS**, **Security Token Service**: the AWS service that hands out temporary credentials when someone "assumes" (temporarily takes on) an IAM role. "Web identity" = the caller proves who they are with a token from an outside identity provider, like GitHub or your cluster.)

**IRSA (IAM Roles for Service Accounts) is the same mechanism**, with the EKS cluster playing GitHub's role:

| Week 8 (GitHub OIDC)                                     | Week 9 (IRSA)                                                                                   |
| -------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| Identity provider: `token.actions.githubusercontent.com` | Identity provider: **your cluster's OIDC issuer** (`oidc.eks.eu-north-1.amazonaws.com/id/ABC…`) |
| Who: a GitHub repo/branch                                | Who: a **Kubernetes ServiceAccount** in a namespace                                             |
| `sub` = `repo:EbotProg/<repo>:ref:refs/heads/main`       | `sub` = `system:serviceaccount:<namespace>:<serviceaccount-name>`                               |
| Temporary credentials                                    | Temporary credentials, refreshed automatically                                                  |

## 9.3 The pieces

1. **ServiceAccount**: a Kubernetes identity for pods (not for humans). Every pod runs as one; by default it's the `default` ServiceAccount of its namespace.
2. **OIDC provider in IAM**: tells AWS to trust tokens signed by this cluster. eksctl does this with `withOIDC: true`.
3. **IAM role with a trust policy** that only accepts one ServiceAccount. How to read it:
   - `Principal.Federated` = "trust tokens from this outside identity provider". **Federated** means the identity comes from outside AWS.
   - `sub` = **subject**, i.e. _who_ the token is for.
   - `aud` = **audience**, i.e. _which service_ the token was issued for (STS).

   Both must match exactly:

```json
{
  "Effect": "Allow",
  "Principal": {
    "Federated": "arn:aws:iam::<acct>:oidc-provider/oidc.eks.eu-north-1.amazonaws.com/id/<ID>"
  },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "oidc.eks.eu-north-1.amazonaws.com/id/<ID>:sub": "system:serviceaccount:external-secrets:external-secrets",
      "oidc.eks.eu-north-1.amazonaws.com/id/<ID>:aud": "sts.amazonaws.com"
    }
  }
}
```

4. **An annotation on the ServiceAccount** pointing at the role:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-secrets
  namespace: external-secrets
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::<acct>:role/w9-external-secrets
```

## 9.4 What happens at runtime (the magic, explained)

1. A pod starts with `serviceAccountName: external-secrets`.
2. An EKS component (a **mutating webhook**) sees the annotation. A **webhook** is an HTTP address that a system calls automatically when something happens. Here the API server calls it every time a pod is created; **mutating** means it's allowed to _change_ the pod before it's saved. The webhook **adds** to the pod:
   - The env var `AWS_ROLE_ARN=<the role>`.
   - The env var `AWS_WEB_IDENTITY_TOKEN_FILE=/var/run/secrets/eks.amazonaws.com/serviceaccount/token`.
   - A mounted, auto-refreshed **signed token** file proving "I am ServiceAccount X in namespace Y of cluster Z".
3. The **AWS SDK** (Software Development Kit: the official AWS code library that apps use to call AWS, e.g. `@aws-sdk` for Node.js) inside the app sees those env vars and calls `AssumeRoleWithWebIdentity` with the token. AWS checks the signature against the OIDC provider and the `sub` against the trust policy, then returns credentials valid for about an hour.
4. The SDK refreshes them automatically. **No keys are stored anywhere.**

## 9.5 The easy way with eksctl

eksctl creates the IAM role (with the correct trust policy) **and** the annotated ServiceAccount in one command:

```bash
eksctl create iamserviceaccount \
  --cluster w9 --region eu-north-1 \
  --namespace external-secrets --name external-secrets \
  --role-name w9-external-secrets \
  --attach-policy-arn arn:aws:iam::<acct>:policy/w9-read-crud-secrets \
  --approve
```

## 9.6 EKS Pod Identity (the newer alternative)

AWS now also offers **EKS Pod Identity**. It's simpler: no OIDC provider and no annotation; you create an "association" (a link) between a ServiceAccount and a role via the EKS API, and an **agent** add-on (a helper pod running on every node) hands out the credentials.

AWS recommends it for new setups. **The brief asks for IRSA**, which is still widely used and works everywhere (including outside EKS-specific tooling), so learn IRSA. If an interviewer asks: _"IRSA uses an OIDC trust per cluster; Pod Identity replaces that with an EKS-managed association. It's easier to reuse roles across clusters."_

---

# PART 10: Secrets Manager → Kubernetes

## 10.1 The goal

- The **real** `DATABASE_URI` and `MASTER_KEY` live in **AWS Secrets Manager**.
- **Git contains no secret values.**
- Inside the cluster, the backend pod receives them as **environment variables**, as before.

(Week 8 used **SSM Parameter Store**, and ECS injected the values. **Secrets Manager** is the paid, more featured sibling: about $0.40 per secret per month. It offers automatic **rotation** (changing a password on a schedule, e.g. every 30 days, without you doing it by hand), **cross-account** sharing (another AWS account can be allowed to read it) and **versioning** (old values are kept, so you can go back). The brief asks for it specifically.)

## 10.2 Two tools exist, and we use External Secrets Operator

| Tool                                    | How it works                                                                                                                                                                                                                             | Gives you                                                     |
| --------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| **External Secrets Operator (ESO)**     | An **operator** (a controller that you install into the cluster to manage one specific kind of thing automatically, here secrets) that **copies** values from Secrets Manager into a normal **Kubernetes Secret** and keeps them in sync | Env vars work normally (`envFrom.secretRef`). Simple for apps |
| Secrets Store CSI Driver + AWS provider | **CSI** = **Container Storage Interface**, Kubernetes' plug-in socket for storage (like CNI for networking). This driver makes a secret look like a disk and mounts it as **files** inside the pod at start time                         | Files by default; env vars need an extra sync step            |

ESO fits our app best, because Parse reads env vars.

## 10.3 How ESO works

```
AWS Secrets Manager                  Cluster
┌──────────────────┐   reads via    ┌────────────────────────────┐
│ crud/backend     │ ◄── IRSA ───── │ ESO controller (pod)       │
│ {DATABASE_URI,   │                │   ▲ reads                  │
│  MASTER_KEY}     │                │   │ SecretStore  (WHERE)   │
└──────────────────┘                │   │ ExternalSecret (WHAT)  │
                                    │   ▼ creates/updates        │
                                    │ Secret "backend-secrets"   │──► backend pods (envFrom)
                                    └────────────────────────────┘
```

Two new object kinds (ESO adds them to Kubernetes; these are **CRDs**, Custom Resource Definitions, i.e. "new kinds of objects" that an add-on teaches the API server):

- **SecretStore** (or **ClusterSecretStore** for all namespaces): **where** and **how** to connect ("AWS Secrets Manager, eu-north-1, authenticate as ServiceAccount X").
- **ExternalSecret**: **what** to fetch and which Kubernetes Secret to create from it.

## 10.4 Step by step

**1. Create the secret in AWS** (one JSON secret with two keys):

```bash
aws secretsmanager create-secret --region eu-north-1 --name crud/backend \
  --secret-string '{"DATABASE_URI":"mongodb+srv://USER:PASS@cluster0.xxxx.mongodb.net/crud","MASTER_KEY":"<random>"}'
```

(Or in Terraform with `aws_secretsmanager_secret` + `aws_secretsmanager_secret_version`, and the values from a `.tfvars` file that's **git-ignored**.)

**2. An IAM policy allowing read access to only that secret:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:eu-north-1:<acct>:secret:crud/backend-*"
    }
  ]
}
```

The `-*` matters: AWS appends 6 random characters to every secret ARN.

**3. IRSA role + ServiceAccount for ESO** (Part 9.5 command, with that policy).

**4. Install ESO with Helm, using the existing ServiceAccount:**

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace \
  --set serviceAccount.create=false --set serviceAccount.name=external-secrets
```

(eksctl created the namespace and ServiceAccount in step 3, so `--create-namespace` is just harmless here.)

**5. The SecretStore and ExternalSecret** (these go in your chart):

```yaml
apiVersion: external-secrets.io/v1 # older ESO versions used v1beta1
kind: ClusterSecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: eu-north-1
      auth:
        jwt: # = authenticate with IRSA (JWT = JSON Web Token: the signed token format IRSA and OIDC use)
          serviceAccountRef:
            name: external-secrets
            namespace: external-secrets
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: backend-secrets
  namespace: crud
spec:
  refreshInterval: 1h # re-check Secrets Manager every hour
  secretStoreRef:
    kind: ClusterSecretStore
    name: aws-secrets-manager
  target:
    name: backend-secrets # the K8s Secret ESO creates
  dataFrom:
    - extract:
        key: crud/backend # every JSON key becomes a Secret key
```

**6. Check it:**

```bash
kubectl get externalsecret -n crud          # STATUS: SecretSynced, READY: True
kubectl get secret backend-secrets -n crud  # exists
kubectl describe externalsecret backend-secrets -n crud   # read errors here if not synced
```

**7. The backend uses it:** `envFrom: [ { secretRef: { name: backend-secrets } } ]`.

**Rotation note.** When the value changes in Secrets Manager, ESO updates the Kubernetes Secret within `refreshInterval`, but **running pods keep the old env var** until they restart (`kubectl rollout restart deployment/backend`). Tools like **Reloader** (a small open-source controller that restarts a Deployment automatically when its Secret or ConfigMap changes) automate that.

**Typical errors:**

| Error                                                                        | Cause                                                                                               |
| ---------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `AccessDeniedException`                                                      | IAM policy resource ARN wrong (forgot `-*`), or the role isn't attached                             |
| `WebIdentityErr` / `not authorized to perform sts:AssumeRoleWithWebIdentity` | Trust policy `sub` doesn't match the namespace/ServiceAccount name, or the OIDC provider is missing |
| `could not find secret`                                                      | Name or region mismatch                                                                             |

---

# PART 11: Ingress on EKS + HTTPS

## 11.1 Install the AWS Load Balancer Controller

It needs AWS permissions to create ALBs, so it uses IRSA too (Part 9).

```bash
# 1. IAM policy (official file from the controller's GitHub releases; pick the version matching the chart)
curl -o lbc-iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
aws iam create-policy --policy-name w9-AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://lbc-iam-policy.json

# 2. IRSA role + ServiceAccount
eksctl create iamserviceaccount --cluster w9 --region eu-north-1 \
  --namespace kube-system --name aws-load-balancer-controller \
  --role-name w9-aws-load-balancer-controller \
  --attach-policy-arn arn:aws:iam::<acct>:policy/w9-AWSLoadBalancerControllerIAMPolicy \
  --approve

# 3. Helm install
helm repo add eks https://aws.github.io/eks-charts && helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system \
  --set clusterName=w9 \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=eu-north-1 \
  --set vpcId=$(aws eks describe-cluster --name w9 --region eu-north-1 --query cluster.resourcesVpcConfig.vpcId --output text)

kubectl get deployment aws-load-balancer-controller -n kube-system   # 2/2 READY
kubectl get ingressclass                                              # "alb" exists
```

(Use CloudShell or Git Bash with `MSYS_NO_PATHCONV=1`, as in Week 8, if paths get mangled.)

## 11.2 TLS options: ACM vs cert-manager

**TLS** (**Transport Layer Security**) = the "S" in HTTPS. It provides two things:

1. **Encryption** between browser and server, so nobody on the network can read passwords or data.
2. **Proof of identity**, via a **certificate**: a small file saying "this public key belongs to `w9.ebotprog.ink`", digitally signed by a **Certificate Authority** (**CA**, an organisation browsers trust to check domain ownership before signing).

The browser's padlock means: the certificate is valid, signed by a trusted CA, and matches the address. Certificates **expire** (usually after 90 days to 1 year), so they must be **renewed**.

|                                                                                           | **ACM (AWS Certificate Manager)**                                     | **cert-manager + Let's Encrypt**                                                                                                                                                   |
| ----------------------------------------------------------------------------------------- | --------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| What it is                                                                                | AWS's own CA issues a **free** certificate and attaches it to the ALB | A controller in the cluster that requests free certificates from **Let's Encrypt** (a free, non-profit Certificate Authority used by millions of sites) and stores them as Secrets |
| Where TLS ends (**TLS termination** = the point where the encrypted traffic is decrypted) | At the **ALB**                                                        | At an in-cluster proxy (e.g. NGINX/Traefik/Gateway)                                                                                                                                |
| Renewal                                                                                   | Automatic, by AWS                                                     | Automatic, by cert-manager (every ~60 days)                                                                                                                                        |
| Works with the ALB?                                                                       | **Yes, natively**                                                     | **No**: an ALB can't use certificates stored in Kubernetes                                                                                                                         |
| Portable to other clouds?                                                                 | No                                                                    | Yes                                                                                                                                                                                |

**Use ACM with the ALB.** It's simpler and is the AWS-native pairing. Mention cert-manager as the portable alternative in your write-up.

**Request the certificate** (you own `ebotprog.ink`):

```bash
aws acm request-certificate --region eu-north-1 \
  --domain-name w9.ebotprog.ink --validation-method DNS
aws acm describe-certificate --region eu-north-1 --certificate-arn <arn> \
  --query 'Certificate.DomainValidationOptions[0].ResourceRecord'
```

**DNS validation**: AWS gives you a **CNAME record** to add at your **DNS provider** (the company where your domain's DNS records are managed, e.g. your registrar like Namecheap, or Cloudflare, or Route 53). A **CNAME** (Canonical Name) record says "this name is an alias for that other name". Only the domain's owner can add records, so this proves you control the domain. Once it's added, the status changes to **ISSUED** (a few minutes). The certificate must be in the **same region** as the ALB (eu-north-1).

## 11.3 The Ingress for our app

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: crud
  namespace: crud
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing # public ALB in public subnets
    alb.ingress.kubernetes.io/target-type: ip # send to pod IPs directly (like Week 8)
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
    alb.ingress.kubernetes.io/ssl-redirect: "443" # http → https
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:eu-north-1:<acct>:certificate/<id>
    alb.ingress.kubernetes.io/healthcheck-path: / # default; override per Service (below)
spec:
  ingressClassName: alb # which controller handles this Ingress
  rules:
    - host: w9.ebotprog.ink
      http:
        paths:
          - path: /parse
            pathType: Prefix
            backend:
              service: { name: backend, port: { number: 1337 } }
          - path: /
            pathType: Prefix
            backend:
              service: { name: frontend, port: { number: 3000 } }
```

The backend needs a different health check path than the frontend. Put this annotation **on the Service** (the controller reads it from there):

```yaml
# on Service "backend"
metadata:
  annotations:
    alb.ingress.kubernetes.io/healthcheck-path: /parse/health
```

The order of paths doesn't matter: the more specific `/parse` wins over `/`.

**What changes from Week 8.** Before, Parse was on its own port `:1337`. Now the frontend and backend share **one hostname and port 443**, split by path:

- `https://w9.ebotprog.ink/` → frontend
- `https://w9.ebotprog.ink/parse` → backend

So set the frontend's `NEXT_PUBLIC_PARSE_SERVER_URL` to `https://w9.ebotprog.ink/parse`. **If your Next.js build bakes `NEXT_PUBLIC_*` values in at build time, you must rebuild the frontend image** after changing it. Same domain also means no browser **CORS** issues. (**CORS**, Cross-Origin Resource Sharing, is the browser rule that blocks a web page from calling a _different_ domain or port unless that server explicitly allows it. In Week 8, `:80` calling `:1337` counted as different.)

**Then:**

```bash
kubectl apply -f ingress.yaml        # or via the Helm chart
kubectl get ingress -n crud -w       # ADDRESS appears after ~2–3 minutes: k8s-crud-...elb.amazonaws.com
```

Point DNS at it: at your DNS provider, create a **CNAME** `w9` → that ALB hostname. (If your DNS were in **Route 53**, AWS's DNS service, you could use an **alias record**, Route 53's AWS-aware version of a CNAME that follows the ALB's IPs automatically. The **ExternalDNS** controller is an add-on that can create these DNS records automatically from your Ingress.)

Test:

```bash
# -I = show only the response headers (status code), not the page
curl -I https://w9.ebotprog.ink/                 # 200 (or a 3xx redirect to /login)
curl https://w9.ebotprog.ink/parse/health        # {"status":"ok"}
curl -I http://w9.ebotprog.ink/                  # 301 → https
```

**Debugging the Ingress:** `kubectl describe ingress crud -n crud` shows events from the controller. Then `kubectl logs -n kube-system deploy/aws-load-balancer-controller` has the detailed reason:

- Subnets not found → subnet tags missing.
- `AccessDenied` → IRSA policy problem.
- Certificate not found → wrong ARN or wrong region.

**Atlas.** The nodes, and therefore the pods, leave the VPC through the **new** NAT gateway eksctl created. Add **its** **Elastic IP** (a fixed public IP address that you reserve in AWS, so it doesn't change; the NAT gateway uses one) to the Atlas allow-list (VPC → NAT gateways → Elastic IP), the same as in Week 8.

---

# PART 12: Scaling on EKS

## 12.1 Two layers of scaling

```
 load ↑  →  HPA adds PODS  →  nodes full?  →  pods PENDING  →  node autoscaler adds NODES
```

| Layer | Tool                                    | Scales              |
| ----- | --------------------------------------- | ------------------- |
| Pods  | **HPA** (Part 5.3)                      | Deployment replicas |
| Nodes | **Cluster Autoscaler** or **Karpenter** | EC2 instances       |

- **Cluster Autoscaler**: watches for Pending pods and increases the node group's Auto Scaling Group (within its min/max).
- **Karpenter**: AWS's newer, faster open-source node autoscaler. It looks at what the Pending pods need and launches the best-fitting, cheapest instance types directly, without node groups.

**For the milestone**, only the **HPA** is required. Choose `maxReplicas` so the extra pods fit on 2 × t3.medium (with requests of 250m CPU, about 6 app pods fit comfortably). Mentioning node-level scaling as a next step shows understanding.

## 12.2 Load test demo (what to capture)

Make sure `kubectl top pods -n crud` works first (metrics-server). Then, in **terminal 1**:

```bash
kubectl get hpa -n crud -w
```

In **terminal 2**, generate load **from inside the cluster**. (`kubectl run` starts a one-off pod; `--rm` deletes it when you exit, `-it` shows its output in your terminal, `--restart=Never` makes it a single run.) Running it inside the cluster means your internet speed isn't the limit (the same reasoning as using CloudShell in Week 8):

```bash
kubectl run load -n crud --rm -it --image=httpd:2.4-alpine --restart=Never -- \
  ab -n 200000 -c 100 http://frontend.crud.svc.cluster.local:3000/
```

`ab` is ApacheBench, as in Week 8; the `httpd` image (the official image of the Apache web server) includes it. It calls the frontend's **Service DNS name**.

Or test through the ALB from CloudShell: `ab -n 200000 -c 200 https://w9.ebotprog.ink/`.

What you should see in terminal 1:

```
NAME       REFERENCE             TARGETS          MINPODS MAXPODS REPLICAS
frontend   Deployment/frontend   cpu: 12%/60%     2       6       2
frontend   Deployment/frontend   cpu: 187%/60%    2       6       2
frontend   Deployment/frontend   cpu: 187%/60%    2       6       6     ← scaled up
...after the test, ~2–5 min...
frontend   Deployment/frontend   cpu: 3%/60%      2       6       2     ← scaled down
```

**Evidence for the deliverable:** the HPA watch output, `kubectl get pods -n crud` showing the new pods, `kubectl describe hpa frontend -n crud` (its **Events** say "New size: 6; reason: cpu resource utilization above target"), and the ab summary.

If `TARGETS` shows `<unknown>`, metrics-server isn't working or the container has **no CPU request**.

---

# PART 13: The milestone, step by step

**Deliverable:**

- A Helm chart/manifests repo.
- The app reachable over **HTTPS on EKS**.
- An **HPA scaling demo**.

### Phase 0: locally, free (do this first)

1. Work through Part 6 exercises 1–2 on kind.
2. Write raw manifests for backend + frontend (Deployment + Service + ConfigMap + Secret) and run your app on kind (exercise 3).
3. Convert them into a Helm chart (Part 7). `helm template` until it looks right; install on kind.
4. HPA on kind with metrics-server; run a load test with the `kubectl run load` command.

### Phase 1: the cluster

5. `eksctl create cluster -f cluster.yaml` (Part 8.6). Verify `kubectl get nodes`.
6. Add the new NAT gateway IP to the Atlas allow-list.

### Phase 2: AWS glue

7. Secrets Manager secret `crud/backend` (Part 10.4, step 1).
8. IRSA + Helm install of **External Secrets** (Part 10).
9. IRSA + Helm install of the **AWS Load Balancer Controller** (Part 11.1).
10. ACM certificate for `w9.ebotprog.ink`, validated via DNS (Part 11.2).

### Phase 3: the app

11. Images: reuse the **ECR** repos from Week 8 (the nodes' role can pull from ECR by default). Rebuild the frontend if its Parse URL is baked in.
12. `helm upgrade --install crud ./chart -n crud --create-namespace -f values-prod.yaml --wait`
13. `kubectl get externalsecret,pods,svc,ingress,hpa -n crud`: everything synced, Running and Ready.
14. CNAME `w9` → ALB hostname. Test HTTPS (Part 11.3).

### Phase 4: prove it

15. Self-healing: delete a pod and watch it come back, while a `curl` loop keeps returning 200.
16. Rolling update: `--set backend.image.tag=<new>` and `kubectl rollout status`; then `helm rollback`.
17. HPA demo (Part 12.2).

### Phase 5: codify + clean up

18. Terraform version of the VPC + EKS + IAM (Part 8.7), with remote state. You can do this **instead of** eksctl on a second run: `terraform apply`, re-install the Helm releases, confirm it works, then `terraform destroy`.
19. **Cleanup, the same day:**

```bash
helm uninstall crud -n crud                          # removes the Ingress → controller deletes the ALB
kubectl get ingress -A                               # must be empty; wait ~1 min
eksctl delete cluster -f cluster.yaml --disable-nodegroup-eviction   # or terraform destroy
aws secretsmanager delete-secret --secret-id crud/backend --region eu-north-1 --force-delete-without-recovery
aws acm delete-certificate --certificate-arn <arn> --region eu-north-1     # optional (free)
aws iam delete-policy --policy-arn arn:aws:iam::<acct>:policy/w9-AWSLoadBalancerControllerIAMPolicy
aws iam delete-policy --policy-arn arn:aws:iam::<acct>:policy/w9-read-crud-secrets
```

Then check the console: **EC2 → Load Balancers** (none left from w9), **VPC → NAT gateways** (deleted), **CloudFormation** (no `eksctl-w9-*` stacks), **Elastic IPs** (released).

### Suggested repo layout

```
week9-k8s/
├── README.md                 # what, why, how, screenshots, decisions, lessons
├── kind/kind-config.yaml
├── eksctl/cluster.yaml
├── terraform/                # vpc, eks, iam (irsa), secrets manager, acm, backend.tf
├── manifests/                # raw YAML from Phase 0 (shows you learned it before Helm)
└── charts/crud/              # the Helm chart: Chart.yaml, values.yaml, values-prod.yaml, templates/
```

### Screenshots worth taking

- `kubectl get nodes -o wide` (2 nodes, private IPs, 2 AZs)
- `kubectl get pods -n crud -o wide` (pods spread across nodes)
- `kubectl get externalsecret -n crud` (SecretSynced) and the Secrets Manager console (secret name only, **never the value**)
- `kubectl get ingress -n crud` + the ALB in the EC2 console + its listeners (80 → redirect, 443 → rules)
- The browser on `https://w9.ebotprog.ink` with the padlock, and `/parse/health`
- The pod deletion → replacement, with the curl loop staying at 200
- `helm history crud -n crud` after an upgrade and a rollback
- The HPA watch output, scaling up and back down, plus `kubectl describe hpa` events
- The eksctl/Terraform output, and the cleanup proof (empty load balancers)

As before: **redact the AWS account ID** in screenshots.

---

# PART 14: Cheat sheets

## 14.1 kubectl daily commands

```bash
# where am I
kubectl config current-context
kubectl get nodes -o wide

# look
kubectl get pods -n crud -o wide             # which node, which IP
kubectl get all -n crud                      # deploy, rs, pods, svc
kubectl get pods -n crud -l app=backend      # filter by label
kubectl get pods -n crud -w                  # watch live
kubectl get deploy backend -n crud -o yaml   # full spec + status

# investigate
kubectl describe pod <pod> -n crud           # read the Events at the bottom FIRST
kubectl get events -n crud --sort-by=.lastTimestamp
kubectl logs <pod> -n crud                   # add -f to follow, --previous for the crashed container
kubectl logs deploy/backend -n crud          # logs of one pod of the deployment
kubectl exec -it <pod> -n crud -- sh
kubectl top pods -n crud                     # CPU/memory (needs metrics-server)

# test networking from inside
kubectl run tmp -n crud --rm -it --image=curlimages/curl --restart=Never -- \
  curl -s http://backend:1337/parse/health
kubectl port-forward -n crud svc/frontend 8080:3000

# change
kubectl apply -f file.yaml
kubectl scale deploy backend --replicas=3 -n crud
kubectl rollout restart|status|undo|history deploy/backend -n crud
kubectl delete -f file.yaml

# learn
kubectl explain deployment.spec.strategy.rollingUpdate
kubectl api-resources                         # every kind + its short name (po, svc, deploy, ing, hpa)
```

## 14.2 Pod status → what it means → what to do

| Status / reason                           | Meaning                                                                                                                                          | First thing to check                                                                                                                |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------- |
| **Pending**                               | Not placed on a node yet                                                                                                                         | `describe pod` → events: "Insufficient cpu/memory" (requests too big / nodes full), "Too many pods" (ENI pod limit), unbound volume |
| **ContainerCreating** (stuck)             | Pulling the image or mounting volumes/secrets                                                                                                    | `describe pod`: a missing Secret or ConfigMap is a classic cause (e.g. ESO hasn't synced yet)                                       |
| **ErrImagePull / ImagePullBackOff**       | Can't download the image                                                                                                                         | Wrong name/tag, private registry without permission, `kind load` forgotten, typo in the ECR URL                                     |
| **CrashLoopBackOff**                      | Container starts, exits, and restarts with growing delays                                                                                        | `kubectl logs <pod> --previous`: app error, missing env var, bad DB connection string, liveness probe too strict                    |
| **Running but 0/1 READY**                 | Readiness probe failing → no traffic                                                                                                             | Probe path/port wrong, app not listening on `0.0.0.0`, slow startup                                                                 |
| **OOMKilled** (in `describe`, Last State) | Exceeded its memory limit                                                                                                                        | Raise the limit or fix the leak (the scenario fire drill)                                                                           |
| **Evicted**                               | The node ran low on memory/disk and removed the pod                                                                                              | Node pressure; set requests properly                                                                                                |
| **Terminating** (stuck)                   | Waiting for shutdown or a **finalizer** (a "don't delete me until this cleanup is done" marker; e.g. the Ingress waits until its ALB is deleted) | Usually wait; on Ingress objects, check the LB controller logs                                                                      |
| Service works by IP, not by name          | DNS issue                                                                                                                                        | `kubectl get pods -n kube-system -l k8s-app=kube-dns`                                                                               |
| Service has no endpoints                  | Selector ≠ pod labels, or no Ready pods                                                                                                          | `kubectl get endpointslices -n crud`, compare labels                                                                                |
| Ingress has no ADDRESS                    | Controller didn't build the ALB                                                                                                                  | `describe ingress`, LB controller logs (subnet tags, IAM, cert ARN)                                                                 |
| HPA TARGETS `<unknown>`                   | No metrics                                                                                                                                       | metrics-server not running, or no CPU **request** set                                                                               |

**The debugging order that solves 90% of problems:** `get` → `describe` (events) → `logs` (`--previous`) → `exec` / `run tmp` to test from inside.

## 14.3 Week 8 ECS ↔ Scenario Swarm ↔ Week 9 Kubernetes

| Concept                           | ECS (Week 8)                                | Swarm (scenario)            | Kubernetes (Week 9)                                        |
| --------------------------------- | ------------------------------------------- | --------------------------- | ---------------------------------------------------------- |
| One running copy                  | Task                                        | Task                        | **Pod**                                                    |
| Recipe                            | Task definition                             | Service spec in `stack.yml` | **Pod template** in a Deployment                           |
| Keep N copies, update them        | Service                                     | Service                     | **Deployment** (+ ReplicaSet)                              |
| Group of things deployed together | Terraform files                             | Stack                       | **Helm release** / namespace                               |
| Internal name for other apps      | Service Connect / ALB                       | Service name (built-in DNS) | **Service** (ClusterIP) + CoreDNS                          |
| Public entry + routing            | ALB listener rules                          | Routing mesh (port)         | **Ingress** + AWS LB Controller → ALB                      |
| Health                            | Target group health check                   | `healthcheck`               | **readiness / liveness probes**                            |
| Config                            | env in task def                             | `environment`               | **ConfigMap**                                              |
| Secrets                           | SSM via execution role                      | Docker secrets / env        | **Secret** (synced from Secrets Manager by ESO)            |
| AWS permissions for the app       | Task role                                   | n/a                         | **IRSA** (ServiceAccount → IAM role)                       |
| Zero-downtime update              | Blue/green with bake time                   | `start-first` rolling       | **RollingUpdate**, `maxSurge 1 / maxUnavailable 0`         |
| Rollback                          | `stop-service-deployment` / circuit breaker | `failure_action: rollback`  | `kubectl rollout undo` / `helm rollback` / `helm --atomic` |
| Memory cap                        | Task memory                                 | `resources.limits`          | `resources.limits` (OOMKilled)                             |
| Autoscaling                       | Target tracking (CPU 60%)                   | none built-in               | **HPA** (pods) + Cluster Autoscaler/Karpenter (nodes)      |
| Machines                          | None (Fargate)                              | Your VMs                    | **Managed node group** (EC2)                               |
| Control plane cost                | Free                                        | Free (on your VM)           | **$0.10/hour**                                             |

## 14.4 Glossary (A–Z)

Every new word in these notes, with **what it is** and **what it's used for**. Words marked _(Week 8)_ or _(scenario)_ you met before; they're here so nothing is missing.

**A**

- **ACM (AWS Certificate Manager)**: AWS's service that gives free TLS certificates and renews them automatically, for use on ALBs. _Used for:_ HTTPS on our Ingress (Part 11.2).
- **Access entry (EKS)**: a record that links an AWS IAM user or role to permissions inside the cluster. _Used for:_ deciding who can run `kubectl` against the EKS cluster (Part 8.5).
- **Add-on (EKS)**: a cluster component (VPC CNI, CoreDNS, kube-proxy, metrics-server) that AWS packages, tests and lets you install or upgrade with one command. _Used for:_ the cluster's basic networking, DNS and metrics.
- **Agent**: a small helper program that runs on each machine, doing one job (collecting logs, handing out credentials…).
- **AKS (Azure Kubernetes Service)**: Microsoft Azure's managed Kubernetes. Only mentioned for comparison.
- **ALB (Application Load Balancer)** _(Week 8)_: AWS's HTTP load balancer. _Used for:_ the public entry point, created automatically from our Ingress.
- **Alias record (Route 53)**: Route 53's AWS-aware version of a CNAME that can point a domain at an ALB. _Used for:_ DNS, if your domain is in Route 53.
- **AMI (Amazon Machine Image)**: the disk template an EC2 instance boots from (operating system + pre-installed software). _Used for:_ nodes boot from the **EKS-optimised AMI**, which already has kubelet and containerd.
- **Annotation**: a note attached to a Kubernetes object that tools read (unlike labels, it's not used for selecting). _Used for:_ configuring the Load Balancer Controller (`alb.ingress.kubernetes.io/...`) and IRSA (`eks.amazonaws.com/role-arn`).
- **API server (kube-apiserver)**: the cluster's single front door; everything talks to it over HTTPS. _Used for:_ every kubectl command goes here.
- **apiVersion**: the first line of every manifest; says which family and version of the Kubernetes API defines that object type (`v1`, `apps/v1`…).
- **Argo Rollouts**: an add-on that adds blue/green and canary deployments to Kubernetes. Not used this week.
- **ARN (Amazon Resource Name)** _(Week 8)_: the unique ID of any AWS resource, like `arn:aws:iam::123456789012:role/x`.
- **AssumeRoleWithWebIdentity**: the AWS STS call that swaps an outside identity token for temporary AWS credentials. _Used for:_ IRSA (and Week 8's GitHub OIDC).
- **aud (audience)**: a field in a token saying _which service_ it was issued for. In IRSA it must be `sts.amazonaws.com`.
- **Auto Mode (EKS)**: an EKS option where AWS also manages the worker machines and core add-ons. Not used: it hides what we're learning.
- **Auto Scaling Group (ASG)**: an AWS feature that keeps a number of EC2 instances running between a min and a max, and replaces failed ones. _Used for:_ a managed node group is an ASG underneath.
- **AWS Load Balancer Controller (LBC)**: an Ingress controller made by AWS; it reads Ingress objects and creates real ALBs, listeners and target groups. _Used for:_ exposing our app (Part 11).
- **AWS SDK (Software Development Kit)**: AWS's official code library for calling AWS from an app. _Used for:_ inside ESO and the LBC; it automatically picks up IRSA credentials.
- **aws-auth**: the old ConfigMap way of giving IAM users access to EKS. **Deprecated**; use access entries.
- **aws-node**: the name of the VPC CNI's DaemonSet pods (one per node). _Used for:_ giving pods VPC IP addresses.

**B**

- **base64**: an **encoding** that rewrites any data using only safe text characters. Anyone can decode it; it is **not** encryption. _Used for:_ how Kubernetes stores Secret values.

**C**

- **Canary deployment**: send a small share of users (e.g. 5%) to the new version, watch it, then increase.
- **ceil (ceiling)**: round **up** to the next whole number (3.2 → 4). _Used for:_ the HPA formula.
- **Certificate (TLS certificate)**: a small file proving "this website really is `w9.ebotprog.ink`", signed by a Certificate Authority. _Used for:_ HTTPS.
- **Certificate Authority (CA)**: an organisation that browsers trust to check domain ownership and sign certificates (e.g. Let's Encrypt, Amazon's CA behind ACM).
- **cert-manager**: an add-on that obtains certificates (often from Let's Encrypt) and stores them as Kubernetes Secrets. The portable alternative to ACM; it doesn't work with the ALB.
- **Chart (Helm)**: a Helm package: templated manifests + default values. _Used for:_ installing add-ons, and our app's deliverable.
- **CloudFormation / stack**: AWS's own infrastructure-as-code service (AWS's alternative to Terraform); a **stack** is one group of resources it created. _Used for:_ eksctl uses it underneath.
- **Cluster**: a group of machines that Kubernetes runs as one system.
- **Cluster Autoscaler**: adds EC2 nodes (via the node group's ASG) when pods can't fit. Next step after the HPA.
- **ClusterIP**: the default Service type; reachable only inside the cluster. _Used for:_ both our Services.
- **ClusterSecretStore / SecretStore**: ESO objects saying _where and how_ to fetch secrets (Cluster… = usable from all namespaces).
- **CNAME (Canonical Name) record**: a DNS record saying "this name is an alias for that name". _Used for:_ `w9` → the ALB's hostname, and ACM's ownership check.
- **CNI (Container Network Interface)**: Kubernetes' plug-in socket for pod networking. On EKS the plugin is the **VPC CNI**.
- **ConfigMap**: a Kubernetes object holding non-secret settings. _Used for:_ env vars like `PORT`, `APP_ID`.
- **Container orchestrator**: software that decides where containers run and keeps them healthy (Kubernetes, Swarm, ECS).
- **Container runtime (containerd)**: the low-level program on each node that pulls images and runs containers. Docker is built on it, so Docker images work unchanged.
- **Context (kubeconfig)**: a saved combination of cluster + user + default namespace. _Used for:_ switching between kind and EKS.
- **Control plane**: the cluster's brain (API server, etcd, scheduler, controller manager). AWS runs it on EKS.
- **Controller**: a program that loops forever making reality match what you asked for.
- **Controller manager**: the control-plane process that runs the built-in controllers.
- **CoreDNS**: the DNS server running inside the cluster. _Used for:_ `backend` resolving to the backend Service's IP.
- **CORS (Cross-Origin Resource Sharing)**: the browser rule that blocks a page from calling another domain or port unless allowed. Avoided by putting frontend and backend on one domain.
- **CrashLoopBackOff**: the pod status meaning "this container keeps crashing; I'm waiting longer between restarts".
- **CRD (Custom Resource Definition)**: lets an add-on teach Kubernetes a new kind of object. _Used for:_ ESO's `ExternalSecret` and `SecretStore`.
- **CronJob / Job**: a Job runs a pod to completion once; a CronJob runs one on a schedule. Not used in the milestone.
- **Cross-account**: letting another AWS account use a resource. A Secrets Manager feature.
- **CSI (Container Storage Interface)**: Kubernetes' plug-in socket for storage. _Seen in:_ the Secrets Store CSI Driver alternative.

**D**

- **DaemonSet**: runs exactly one pod on every node. _Example:_ `aws-node`, `kube-proxy`.
- **Declarative vs imperative**: describe the end result (declarative: Kubernetes, Terraform) vs give step-by-step commands (imperative).
- **Deployment**: the object you write for a stateless app: "keep N copies of this pod, update them safely". ≈ ECS service.
- **Deprecated**: still works, but officially being phased out; don't build on it.
- **Desired state / reconciliation**: what you asked for / the endless loop that makes reality match it.
- **DNS provider**: where your domain's DNS records are managed (registrar, Cloudflare, Route 53…). _Used for:_ adding the ACM CNAME and the `w9` CNAME.
- **DNS validation (ACM)**: proving you own a domain by adding a record AWS gives you.
- **Draining**: moving pods off a node gracefully before it's removed or upgraded.
- **Dry run**: rehearse a command without changing anything (`--dry-run=server`).

**E**

- **EKS (Amazon Elastic Kubernetes Service)**: AWS's managed Kubernetes. AWS runs the control plane; you add nodes. _Used for:_ the milestone's production cluster (Part 8).
- **eksctl**: the official CLI that creates EKS clusters (VPC, nodes, IAM, OIDC) from one YAML file. _Used for:_ Part 8.6.
- **Elastic IP**: a fixed public IPv4 address you reserve in AWS. _Used for:_ the NAT gateway's IP, which goes in the Atlas allow-list.
- **Encoding vs encryption**: encoding changes the format, and anyone can reverse it (base64); encryption needs a secret key to read (KMS).
- **Endpoints / EndpointSlice**: the live list of Ready pod IPs behind a Service. Empty = nothing will receive traffic.
- **ENI (Elastic Network Interface)**: a virtual network card on an EC2 instance; each holds a few IPs. _Why it matters:_ it limits pods per node (t3.medium = 17).
- **ErrImagePull / ImagePullBackOff**: the pod status meaning "can't download the image" (wrong name/tag or no permission).
- **etcd**: the key-value database holding all cluster state. AWS runs and backs it up on EKS.
- **Evicted**: a pod removed because its node ran low on memory or disk.
- **Extended support (EKS)**: the 12 months after standard support when an old Kubernetes version still gets fixes, at 6× the control-plane price.
- **ExternalDNS**: an add-on that creates DNS records automatically from Ingresses. Optional.
- **ExternalName**: a Service type that gives an outside hostname an in-cluster name. Rare.
- **ExternalSecret**: an ESO object saying _what_ secret to fetch and which Kubernetes Secret to create from it.
- **External Secrets Operator (ESO)**: an add-on that copies secrets from Secrets Manager into Kubernetes Secrets and keeps them in sync. _Used for:_ Part 10.

**F**

- **Fargate on EKS**: running each pod in its own AWS micro-VM, with no nodes. An alternative; not used.
- **Federated (identity)**: the identity comes from an outside provider (GitHub, the cluster's OIDC issuer), not from an IAM user.
- **Finalizer**: a "don't delete me until this cleanup is done" marker on an object. Why an Ingress can sit in Terminating until its ALB is gone.
- **Flapping**: scaling up and down repeatedly as load wobbles. Prevented by the stabilization window.

**G**

- **Gateway API / Gateway / HTTPRoute**: the newer replacement for Ingress. A **Gateway** is the entry point; **HTTPRoute**s are the routing rules. Good to know; the brief uses Ingress.
- **GKE (Google Kubernetes Engine)**: Google Cloud's managed Kubernetes. Comparison only.
- **Go templates**: the template language Helm uses (`{{ .Values.x }}`).

**H**

- **Helm**: the package manager for Kubernetes. _Used for:_ installing the LBC, ESO, and our own chart.
- **Highly available (HA)**: keeps working when a machine or data centre fails, because copies run in several places.
- **HPA (Horizontal Pod Autoscaler)**: changes a Deployment's replica count based on CPU (or other metrics). _Used for:_ the scaling demo.
- **HTTPRoute**: see Gateway API.

**I**

- **IAM principal**: anything that can authenticate to AWS: an IAM user or an IAM role.
- **imagePullPolicy**: when a node should download the image. `IfNotPresent` = only if it doesn't have it already (needed with kind).
- **Ingress**: HTTP routing rules (host/path → Service, plus TLS). _Used for:_ one HTTPS entry for both apps.
- **Ingress controller**: the program that reads Ingress rules and builds a real load balancer. _Ours:_ the AWS Load Balancer Controller.
- **IngressClass**: says which Ingress controller handles an Ingress (`ingressClassName: alb`).
- **ingress-nginx**: a once-popular NGINX-based Ingress controller, **retired in March 2026** (no security fixes). Don't use it for new work.
- **Instance type**: the size of an EC2 machine (`t3.medium` = 2 vCPU, 4 GiB RAM).
- **IRSA (IAM Roles for Service Accounts)**: gives a specific pod its own IAM role via OIDC, with no stored keys. _Used for:_ ESO and the LBC (Part 9).

**J**

- **JWT (JSON Web Token)**: a signed token format (header.payload.signature). IRSA and OIDC tokens are JWTs.

**K**

- **K8s**: short for Kubernetes (8 letters between K and s).
- **Karpenter**: AWS's newer node autoscaler; launches the best-fitting EC2 instances for Pending pods. A next step.
- **Kernel**: the core of the Linux operating system; enforces CPU/memory limits and kills processes that run out of memory.
- **Key-value database**: stores simple `key → value` pairs (like a dictionary). etcd is one.
- **kind (Kubernetes in Docker)**: runs a practice cluster in Docker on your laptop. _Used for:_ free practice (Part 6).
- **KMS (AWS Key Management Service)**: the AWS service that creates and guards encryption keys; the keys never leave AWS. _Used for:_ encrypting data at rest (S3, disks, Secrets Manager, and optionally EKS Secrets in etcd). About $1/month per key. Not required for this milestone.
- **kube-proxy**: runs on every node and programs the networking rules that make Service IPs reach pods.
- **kube-system**: the namespace where Kubernetes' own components and system add-ons live.
- **kubeconfig**: the file (`~/.kube/config`) telling kubectl which clusters exist and how to log in.
- **kubectl**: the Kubernetes command-line tool.
- **kubelet**: the agent on each node that starts pods and runs their health checks.
- **Kubernetes**: the open-source container orchestrator these notes are about.

**L**

- **Label / selector**: a `key: value` sticker on an object / a query that matches stickers. How Services and Deployments find their pods.
- **Let's Encrypt**: a free, non-profit Certificate Authority, used with cert-manager.
- **Linter (`helm lint`)**: a tool that checks files for mistakes without running them.
- **Liveness probe**: "are you alive?". If it fails, the container is restarted.
- **LoadBalancer (Service type)**: makes the cloud create a load balancer (an NLB on AWS) for one Service. Not used: we use one Ingress instead.

**M**

- **Managed Kubernetes**: a cloud runs the control plane for you (EKS, GKE, AKS).
- **Managed node group**: EC2 worker nodes whose creation, updates and replacement AWS handles. _Used for:_ our 2 × t3.medium nodes.
- **Manifest**: a YAML file describing Kubernetes objects.
- **maxSurge / maxUnavailable**: during a rolling update, how many extra pods may exist / how many may be missing.
- **Mebibyte (Mi) / gibibyte (Gi)**: 1 Mi = 1,048,576 bytes; 1 Gi = 1024 Mi. Kubernetes' memory units.
- **metrics-server**: collects CPU/memory usage from all nodes. _Used for:_ `kubectl top` and the HPA.
- **Micro-VM**: a tiny, fast-starting virtual machine (what Fargate runs each task/pod in).
- **Migration (database)**: a script that changes the database structure; often run as a Job.
- **Millicore (m)**: one-thousandth of a CPU core. `250m` = a quarter core.
- **minikube**: another local-cluster tool (an alternative to kind).
- **Minor version**: the middle number of a version (`1.36`); Kubernetes releases one about 3 times a year.
- **Module (Terraform)**: a reusable package of Terraform code with inputs. _Used for:_ `terraform-aws-modules/vpc` and `/eks` (Part 8.7).
- **Mutating webhook**: an HTTP service the API server calls when an object is created, allowed to change it. _Used for:_ IRSA injects credentials into pods this way.

**N**

- **Namespace**: a folder for objects inside a cluster (`crud`, `kube-system`).
- **NAT gateway** _(Week 8)_: lets private-subnet machines reach the internet through one fixed IP.
- **NetworkPolicy**: firewall rules between pods (like security groups inside the cluster). Not used in the milestone.
- **NGINX**: a popular web server and proxy (behind ingress-nginx).
- **NLB (Network Load Balancer)**: AWS's connection-level load balancer; can't route by URL path. Created by `type: LoadBalancer` Services.
- **Node**: a worker machine in the cluster (an EC2 instance on EKS).
- **Node group**: a set of identical nodes.
- **NodePort**: a Service type that opens the same port (30000–32767) on every node. Mainly for testing.

**O**

- **OIDC provider / issuer** _(Week 8)_: an identity system AWS can trust. Every EKS cluster has its own issuer URL. _Used for:_ IRSA.
- **OOMKilled**: killed by the kernel for exceeding its memory limit (OOM = Out Of Memory).
- **Operator**: a controller you install to manage one specific kind of thing automatically (e.g. External Secrets Operator).

**P**

- **Patch (`kubectl patch`)**: edit one field of an existing object in place.
- **Pending**: the pod status meaning "not placed on a node yet" (usually not enough room).
- **PersistentVolume**: storage that survives pod replacement. Used by StatefulSets; not needed (we use Atlas).
- **Pin (a version)**: write an exact version so updates can't change things silently.
- **Pipe (`|`)**: passes the output of one thing into the next (shell, and Helm templates).
- **Pod**: one or more containers sharing an IP; the smallest thing Kubernetes runs. ≈ ECS task.
- **Pod Identity (EKS)**: AWS's newer, simpler alternative to IRSA. The brief uses IRSA.
- **Pod template**: the "recipe" for pods inside a Deployment (≈ ECS task definition).
- **port / targetPort**: the Service's port that callers use / the container's port it forwards to.
- **port-forward**: a temporary tunnel from your laptop into the cluster, for testing.
- **Probe**: a health check run by the kubelet (liveness, readiness, startup).
- **ProgressDeadlineExceeded**: a Deployment's message when a rollout hasn't progressed for 10 minutes.
- **Proxy**: a middleman server that receives requests and forwards them elsewhere.

**Q**

- **Quota (ResourceQuota)**: a limit on the total resources a namespace may use.

**R**

- **RBAC (Role-Based Access Control)**: Kubernetes' permission system (who may do what, where).
- **Readiness probe**: "can you take traffic now?". If it fails, the pod is removed from the Service and the ALB, but not restarted.
- **Ready**: a pod that passes its readiness probe and therefore receives traffic.
- **Release / revision (Helm)**: one installed copy of a chart / each numbered version of it (for `helm rollback`).
- **Reloader**: an add-on that restarts Deployments when their Secret/ConfigMap changes.
- **Replica**: one copy of a pod. `replicas: 2` = two copies.
- **ReplicaSet**: keeps N identical pods running; Deployments create them for you.
- **Repository (Helm repo)**: a website hosting charts.
- **Requests / limits**: the guaranteed amount (used for scheduling and HPA %) / the hard maximum (CPU throttled, memory OOMKilled).
- **Rolling update**: replacing pods gradually, old and new side by side for a while.
- **Rotation (secret)**: changing a password on a schedule automatically.
- **Route 53**: AWS's DNS service.

**S**

- **Scheduler**: the control-plane part that picks a node for each new pod.
- **Secret (Kubernetes)**: an object for sensitive values; base64-encoded, **not** encrypted unless KMS encryption is enabled.
- **Secrets Manager (AWS)**: AWS's service for storing secrets encrypted (with KMS), with access control, rotation and versioning. About $0.40/secret/month. _Used for:_ `crud/backend`.
- **Secrets Store CSI Driver**: an alternative to ESO that mounts secrets as files. Not used.
- **Self-signed certificate**: a certificate a machine signed itself, not trusted by default.
- **Service**: a stable name + virtual IP that load-balances to Ready pods. _Used for:_ `backend`, `frontend`.
- **ServiceAccount**: the identity a pod runs as inside Kubernetes. _Used for:_ IRSA maps one to an IAM role.
- **Sidecar**: a helper container in the same pod as the main one.
- **spec / status**: the part of an object you write (what you want) / the part Kubernetes fills in (what's real).
- **Stabilization window**: how long the HPA waits before scaling down (prevents flapping).
- **Standard support (EKS)**: the first 14 months of a Kubernetes version on EKS, at the normal price.
- **Startup probe**: gives slow-starting apps time before liveness/readiness checks begin.
- **StatefulSet**: like a Deployment, but for databases (stable names, own disks).
- **STS (AWS Security Token Service)**: the AWS service that issues temporary credentials when a role is assumed.
- **sub (subject)**: a token field saying _who_ it's for. In IRSA: `system:serviceaccount:<namespace>:<name>`.
- **Subnet tags (`kubernetes.io/role/elb`)**: labels on subnets telling the LBC where public/internal ALBs may go.

**T**

- **Taint / toleration**: a node-level "keep out" sign / a pod's permission to ignore it. Later topic.
- **Templating**: writing a file with blanks, then filling them with values (Helm).
- **Throttled (CPU)**: slowed down for using more CPU than its limit; not killed.
- **TLS (Transport Layer Security)**: the encryption and identity check behind HTTPS.
- **TLS termination**: the point where HTTPS traffic is decrypted (for us: the ALB).
- **Traefik / HAProxy / Kong**: other proxy products that can act as Ingress controllers.
- **Trust policy** _(Week 8)_: the part of an IAM role saying _who_ may assume it.
- **Tunnel**: a private connection carrying traffic from one place to another (port-forward, SSH).

**V**

- **values.yaml**: the file of settings that fill a Helm chart's blanks.
- **vCPU (virtual CPU)**: one processor core's worth of compute as AWS sells it.
- **Versioning (secret)**: keeping old values so you can go back.
- **Virtual IP**: an IP that doesn't belong to one machine; networking rules forward its traffic (a Service's ClusterIP).
- **Volume / volumeMount**: storage attached to a pod / where it appears inside the container (like `docker run -v`).
- **VPC CNI**: the EKS networking plugin; gives each pod a real VPC IP.
- **VPC flow logs**: AWS's optional record of network connections in a VPC.

**W**

- **Webhook**: an HTTP address a system calls automatically when something happens.
- **winget**: Windows' built-in command-line app installer.

## 14.5 Test yourself (answers below)

1. You delete a pod and it comes back with a different name. Why, and how do you make it stay gone?
2. Your Service has no endpoints. Name the two most likely causes.
3. What's the difference between a failing readiness probe and a failing liveness probe?
4. Your HPA shows `<unknown>/60%`. Name two causes.
5. Why is a Kubernetes Secret in Git a security problem even though it looks encoded?
6. What does the AWS Load Balancer Controller do with an Ingress object?
7. Explain IRSA using the Week 8 GitHub OIDC comparison.
8. A pod is `Pending` with "Too many pods" on t3.small nodes. Why?
9. Why does an ALB use ACM rather than cert-manager?
10. You changed a ConfigMap but the app still uses the old value. Why, and what's the fix?

<details><summary>Answers</summary>

1. Its Deployment/ReplicaSet reconciles back to N replicas. Scale the Deployment down or delete the Deployment.
2. The selector doesn't match the pod labels, or no pod is Ready (readiness failing).
3. Readiness failure: pod removed from traffic, not restarted. Liveness failure: container restarted.
4. metrics-server isn't installed/working; the container has no CPU request.
5. base64 is reversible encoding, not encryption; anyone with repo access can read it.
6. It reads the rules and creates/updates an AWS ALB, listeners, rules and target groups, registering Ready pod IPs.
7. The cluster is an OIDC identity provider (like GitHub). A ServiceAccount token (like the GitHub job token) is exchanged via `AssumeRoleWithWebIdentity` for temporary credentials of a role whose trust policy only accepts that ServiceAccount's `sub`.
8. The VPC CNI gives each pod a VPC IP, and t3.small supports only 11 pod IPs, including system pods.
9. An ALB terminates TLS itself and can only use ACM (or IAM) certificates, not Kubernetes Secrets.
10. Env vars are read at container start. Run `kubectl rollout restart deployment/<name>`.
</details>

---

## Sources these notes are based on

- [Kubernetes documentation](https://kubernetes.io/docs/): concepts (Pods, Deployments, Services, Ingress, ConfigMaps/Secrets, probes, HPA)
- [EKS Workshop](https://www.eksworkshop.com/) and the [Amazon EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [roadmap.sh DevOps](https://roadmap.sh/devops), Kubernetes section
- [EKS Kubernetes version lifecycle](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html) and [Kubernetes 1.36 on EKS](https://aws.amazon.com/about-aws/whats-new/2026/06/amazon-eks-distro-kubernetes-version-1-36)
- [EKS pricing](https://aws.amazon.com/eks/pricing/) and [extended support pricing](https://aws.amazon.com/blogs/containers/amazon-eks-extended-support-for-kubernetes-versions-pricing)
- [Ingress NGINX retirement (Kubernetes blog)](https://kubernetes.io/blog/2025/11/11/ingress-Nginx-retirement/)
- [Grant workloads access to AWS: IRSA and Pod Identity](https://docs.aws.amazon.com/en_us/eks/latest/userguide/service-accounts.html)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/) and [External Secrets Operator](https://external-secrets.io/)

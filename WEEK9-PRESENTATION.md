# Week 9 presentation sheet: Kubernetes + Amazon EKS

## Opening (say this)
> "In Week 8 the app ran on ECS, AWS's own container service. This week I moved it to **Kubernetes on Amazon EKS**, the open standard that runs on any cloud. I packaged it as a **Helm chart**, put it behind **HTTPS**, pulled its secrets from **AWS Secrets Manager** without storing a single key, and proved it **heals itself** and **scales under load**."

## The story in 6 steps (one screenshot each)

| # | Say | Show |
|---|---|---|
| 1 | "eksctl built the cluster from one file: network, control plane, 2 worker nodes in **private subnets**, and two **IRSA** roles." | W9-01a (nodes, private IPs) |
| 2 | "Secrets live in **Secrets Manager**, encrypted with KMS. Git only has a pointer. **External Secrets** reads it using its own IAM role, which can read only that one secret." | W9-03, W9-04 (`Valid`), W9-05 (`SecretSynced`) |
| 3 | "The **Helm chart** has one set of templates and a values file per environment. Same chart on my laptop and on EKS." | `charts/crud` in the repo |
| 4 | "The **Ingress** became a real **ALB** with an ACM certificate: HTTP redirects to HTTPS, `/parse` goes to the backend, everything else to the frontend." | W9-07, W9-08, W9-09 |
| 5 | "**Self-healing:** I deleted a backend pod while hitting the site every second. Every response was 200; a replacement was Ready in 11 seconds." | W9-10a |
| 6 | "**Autoscaling:** under load, frontend CPU went to 732% of its request and the HPA scaled **2 → 6**, then back to 2 after a 2-minute calm-down." | W9-11, W9-12, W9-13 |

## Words you'll use, in one line each
- **EKS:** AWS runs the Kubernetes "brain" (control plane); I provide worker machines (nodes).
- **Pod / Deployment / Service:** one running copy / "keep N copies and update them safely" / a stable name + load balancing for the pods.
- **Helm chart:** templates with blanks + a values file per environment.
- **Ingress + Load Balancer Controller:** routing rules + the program that builds a real AWS ALB from them.
- **IRSA:** gives one specific pod its own IAM role through the cluster's OIDC identity, the same idea as Week 8's GitHub-to-AWS login, with no keys stored.
- **External Secrets:** copies a secret from Secrets Manager into a Kubernetes Secret.
- **HPA:** adds or removes pods to keep average CPU around 60% of what each pod requested.

## Numbers to remember
- **2 nodes** m7i-flex.large · Kubernetes **1.37** · eu-north-1
- Self-heal: **0 failed requests**, replacement Ready in **~11 s**
- HPA: CPU **2% → 732%**, replicas **2 → 6 → 2**, **~2,600 req/s**, **p95 81 ms**, 0 failures
- Cost: about **$0.35–0.40/hour**, about **$3** for the session; deleted the same day

## Problems I solved (pick 2 or 3)
1. **The Free plan blocked t3.medium:** read the CloudFormation error, listed the allowed types, and switched to m7i-flex.large (more memory, fewer nodes).
2. **The domain was suspended by the registrar:** the certificate wouldn't validate. A DNS lookup showed Namecheap's "verify your email" nameservers. I verified, and made HTTPS optional in the chart as a Plan B.
3. **Credentials expiring during cleanup:** a retry loop with fresh temporary keys finished the delete safely.

## Likely questions
| Q | A |
|---|---|
| Why EKS when ECS worked? | Kubernetes is portable (any cloud or on-prem) and has a huge ecosystem (Helm, ArgoCD, Prometheus). ECS is simpler but AWS-only |
| Why IRSA and not keys in a Secret? | Keys never expire and leak. IRSA gives short-lived credentials to **one** ServiceAccount only, not the whole node |
| Isn't a Kubernetes Secret secure? | Only base64-encoded by default. That's why the real value lives in Secrets Manager (KMS-encrypted) and Git only has a pointer |
| Why didn't the HPA touch the backend? | The backend has a fixed count in Git (used in Week 10's self-heal demo); the HPA is on the frontend, which is CPU-heavy |
| Why `maxUnavailable: 0`? | A new pod must be Ready before an old one stops, so there's never less capacity during a rollout |
| Why did the deleted pod show "Error"? | Node.js had no SIGTERM handler, so it exited with code 143. No user impact; the fix is a graceful-shutdown handler |
| Is it in Terraform? | Built with eksctl (declarative file, CloudFormation underneath). Terraform modules are the next step |

## Honest gaps (say before they ask)
- **Terraform** version of the cluster not done yet (eksctl only).
- Only **pod** autoscaling; no node autoscaling (Karpenter / Cluster Autoscaler).
- Worked as the **root user** in CloudShell. Flagged in my Week 11 IAM audit.

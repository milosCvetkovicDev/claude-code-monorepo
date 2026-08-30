---
name: bitnami-secure-image-deprecation
description: Bitnami moved most charts/images behind a paid subscription in 2025 — pinned-tag images on the free-tier `docker.io/bitnami/*` namespace now 404. Affects every Bitnami chart consideration going forward.
type: project
originSessionId: 00000000-0000-0000-0000-000000000046
---
Bitnami's "Secure Images" rebrand (mid-2025) removed pinned-tag images from the free-tier `docker.io/bitnami/*` registry. Helm charts at `https://charts.bitnami.com/bitnami` still install (Application syncs, CRDs land) but pods enter `ImagePullBackOff` because the referenced `docker.io/bitnami/<name>:<pinned-tag>` returns 404. Free tier only gets a limited "developer edition" subset.

**Why:** Surfaced on 2026-05-15 during dev-platform verification of PR #762 (topology-operator install via Bitnami `rabbitmq-cluster-operator` chart). Confirmed via Docker Hub API which now returns: "This image is no longer available for free through Docker Hub … built OCI artifact … through a commercial subscription of Bitnami Secure Images." Pivoted to upstream RabbitMQ manifest in #765 + cert-manager in #766.

**How to apply:**
- Before adopting any Bitnami chart for Platform, check whether the upstream project publishes its own manifests (RabbitMQ, etcd, Redis, Postgres, Kafka — all do). Prefer upstream over Bitnami.
- If a Bitnami chart is already in the repo (search for `repoURL: https://charts.bitnami.com/bitnami`) and it's working, the images were likely pulled when they were still public; do NOT bump versions without verifying the new tag exists on free-tier Docker Hub.
- For new installs, the vendoring pattern from `charts/messaging-topology-operator/` (kustomize wrapper around upstream release manifest + small `*-patch.yaml` for env-var/config) is the established replacement.
- Subscription-based Bitnami Secure Images are an option but require a contractual commitment and an `imagePullSecret`-style auth pattern — not adopted as of 2026-05-15.

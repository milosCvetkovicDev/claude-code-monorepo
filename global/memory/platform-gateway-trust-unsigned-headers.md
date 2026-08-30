---
name: platform-gateway-trust-unsigned-headers
description: "Platform GatewayIdentityGuard trusts gateway-injected identity headers with NO signature — pod-to-pod forgery is blocked ONLY by NetworkPolicy/mTLS, not crypto"
metadata:
  node_type: memory
  type: reference
  originSessionId: 00000000-0000-0000-0000-000000000017
---

Platform's downstream auth is a **header-TRUST** model with **no cryptographic verification**. The BC-side `GatewayIdentityGuard` reads the gateway-injected `x-user-id` / `x-tenant-id` / `x-user-roles` / `x-permissions` headers, builds `request.user`, and **only checks that `x-user-id` + `x-tenant-id` are present** (401 if absent). It does NOT verify a JWT, HMAC, or shared secret — the JWT is verified once at the gateway edge (the gateway's JWT guard), which strips client `x-*` headers and re-injects verified ones.

**Consequence:** where inter-service identity is an unsigned header, the RBAC guards are only as strong as the network boundary — a peer that can reach the service's app port can present whatever identity it likes. Protection against peer forgery is therefore **network isolation** (gateway-only ingress NetworkPolicy, or mTLS/peer identity), NOT anything in the app layer. A service-side header-strip hook cannot help (it would strip the gateway's own legitimate headers); the durable fix is signing the headers or mesh mTLS.

**Closing it (pattern):** a base chart whose default ingress policy admits any same-app pod to a service's app port IS the forgery surface — the chart default, not any one service, is the defect. Make the per-service ingress policy gateway-only from day one rather than opt-in; where it must be opt-in (`networkPolicy.crossNamespaceIngress: platform|gateway`), tighten each service once its cross-namespace callers are verified (grep the values files for who sets its `*_SERVICE_URL`). A rendered NetworkPolicy is configuration, not behaviour — prove it by starting a non-gateway probe pod and confirming the app port is dropped. Tenant DATA isolation is independent of this (ALS `TenantContext` + global ORM `tenant` filter, fail-closed) — see [[platform-identity-epic-prep]].

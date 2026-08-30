# CI/CD Guardrails

## Mandatory Reference Loading

**Before writing or modifying ANY CI/CD related file, you MUST read the relevant reference doc first.**

This includes:
- `.github/workflows/*.yml` → Read `~/.claude/references/cicd/github-actions-patterns.md`
- `Dockerfile*`, `docker-compose*.yml` → Read `~/.claude/references/cicd/docker-patterns.md`
- `charts/**/*.yaml`, any K8s/Helm/ArgoCD config → Read `~/.claude/references/cicd/k8s-helm-argocd-patterns.md`
- Any version bump or new action → Read `~/.claude/references/cicd/verified-versions.md`

## Rules

### 1. Never Invent from Memory
Do NOT write GitHub Actions syntax, Docker commands, Helm templates, or K8s manifests from memory. ALWAYS:
- Read the reference doc first
- Copy patterns from existing working workflows
- Check verified-versions.md for correct versions

### 2. Verify Before Proposing
Before proposing any CI/CD change:
- Read the existing file being modified
- Read at least one similar working file for pattern reference
- Check if a composite action already exists (`.github/actions/`)

### 3. SHA-Pin All Actions
Never use tag references (`actions/checkout@v4`). Always use full SHA pins from verified-versions.md. Include the tag as a comment: `# v6.0.2`

### 4. Respect Existing Patterns
When adding new workflows or modifying existing ones:
- Match the concurrency pattern (PR cancel vs main always-run)
- Match the permissions pattern (least privilege)
- Match the runner pattern (self-hosted with fallback)
- Reuse composite actions — don't reinvent inline

### 5. Validate Changes
After writing CI/CD changes, suggest validation:
- GitHub Actions: `actionlint` or visual review of YAML structure
- Dockerfiles: `docker build --target deps` (test individual stages)
- Helm: `helm template charts/platform-base -f charts/values/{service}.yaml`
- Terraform: `terraform validate && terraform plan`

### 6. Never Guess API Flags
If you're unsure about a GitHub Actions feature, Azure CLI flag, Docker build option, or Helm directive:
- Say "I'm not sure about this flag/syntax" 
- Suggest checking the official docs
- Do NOT hallucinate plausible-looking flags

### 7. Context7 for External Tools
When working with GitHub Actions, Docker, Helm, or ArgoCD features that go beyond the acme patterns:
- Use Context7 to fetch current documentation
- Don't rely on training data for API syntax
- Cross-reference with existing acme patterns

## What Gets Checked

| File Pattern | Required Reference |
|---|---|
| `.github/workflows/*.yml` | github-actions-patterns.md |
| `.github/actions/**` | github-actions-patterns.md |
| `Dockerfile*` | docker-patterns.md |
| `docker-compose*.yml` | docker-patterns.md |
| `charts/**` | k8s-helm-argocd-patterns.md |
| `infra/**` | (existing) infra/CLAUDE.md |
| Any version change | verified-versions.md |

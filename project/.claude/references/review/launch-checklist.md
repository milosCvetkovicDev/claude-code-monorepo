# Launch Readiness Checklist

6-area pre-deploy gate. Each area has pass/fail criteria and verification commands. ALL areas must pass before deploying to production.

## Area 1: Code Quality

| Check | Verification | Pass Criteria |
| ------------------------ | ------------------------------------------------------ | ------------------------ |
| Lint clean | `nx run-many -t lint --projects={affected}`            | Zero errors |
| Type-check passes | `nx run-many -t build --projects={affected}`           | Zero type errors |
| No TODO/FIXME in diff | `git diff main... \| grep -i 'TODO\|FIXME'`            | Zero matches in new code |
| Tests pass | `nx run-many -t test --projects={affected}`            | All tests green |
| No skipped tests in diff | `git diff main... \| grep -i '\.skip\|xit\|xdescribe'` | Zero new skipped tests |

## Area 2: Security

| Check | Verification | Pass Criteria |
| --------------------- | ------------------------------------------------------------ | --------------------------------- |
| npm audit clean | `npm audit --production`                                     | No critical/high vulnerabilities |
| gitleaks clean | `gitleaks detect --source . --no-git`                        | Zero leaks |
| No hardcoded secrets | `grep -rn 'password\|secret\|api_key' --include='*.ts' src/` | Manual review: all are env refs |
| Auth on new endpoints | Code review | All new endpoints have auth guard |
| SQL injection check | Code review | All queries parameterized |

See `.claude/references/review/security-checklist.md` for detailed security review.

## Area 3: Performance

| Check | Verification | Pass Criteria |
| ------------------------- | --------------------------------------------- | --------------------------------- |
| No N+1 queries | Code review of new DB queries | All use eager loading or populate |
| Bundle size delta | `nx run legacy-web:build` — compare output | < 50KB increase |
| No unbounded queries | Code review | All list endpoints paginated |
| Load test (if applicable) | Manual or k6 script | P95 latency < 500ms |

See `.claude/references/review/performance-checklist.md` for detailed performance review.

## Area 4: Accessibility

| Check | Verification | Pass Criteria |
| ------------------- | ------------------------ | ---------------------------------- |
| axe-core scan | `npx axe-core-cli {url}` | Zero critical/serious violations |
| Keyboard navigation | Manual test | All interactive elements reachable |
| Screen reader test | Manual VoiceOver/NVDA    | Core flows understandable |

**Note:** Accessibility checks only required for changes touching `apps/legacy-web/` or `apps/domain-web/`. Backend-only deploys show N/A.

See `.claude/references/review/accessibility-checklist.md` for detailed accessibility review.

## Area 5: Infrastructure

| Check | Verification | Pass Criteria |
| ----------------------- | -------------------------------------------------------------------- | ---------------------------------- |
| Terraform plan clean | `terraform plan` (if infra changes)                                  | No unexpected destroys/recreates |
| Env vars configured | Check Azure App Settings | All new env vars set in target env |
| Health endpoint works | `curl {app_url}/health`                                              | 200 OK                             |
| Database migration safe | Review migration SQL                                                 | No breaking changes, reversible |
| FQDN verified | `az containerapp show --query properties.configuration.ingress.fqdn` | Matches expected URL               |

## Area 6: Documentation

| Check | Verification | Pass Criteria |
| ---------------------------- | --------------------------------- | ------------------------------ |
| ADR for architecture changes | `ls docs/architecture/decisions/` | New ADR exists if applicable |
| API docs updated | Review OpenAPI/Swagger spec | New endpoints documented |
| Deployment notes | PR description | Breaking changes documented |
| Runbook updated | Review `docs/runbooks/`           | Operational changes documented |

## Quick Verification Script

```bash
#!/bin/bash
echo "=== Launch Readiness Check ==="

echo "1. Code Quality..."
nx run-many -t lint -t build -t test --projects=$(nx print-affected --select=projects) 2>&1 | tail -5

echo "2. Security..."
npm audit --production 2>&1 | tail -3
gitleaks detect --source . --no-git 2>&1 | tail -1

echo "3. Performance..."
echo "   (Manual review required)"

echo "4. Accessibility..."
echo "   (Run axe-core if frontend changes present)"

echo "5. Infrastructure..."
echo "   (Check Terraform plan if infra changes present)"

echo "6. Documentation..."
echo "   (Manual review required)"
```

## Override: Hotfix Deploy

For critical hotfixes, use `--force` with a documented reason:

1. Log the override reason in the PR description
2. Create a follow-up issue for any skipped checks
3. Complete full checklist within 24 hours post-deploy

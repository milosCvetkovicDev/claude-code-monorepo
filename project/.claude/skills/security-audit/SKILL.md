---
name: security-audit
description: "Comprehensive security audit: OWASP top 10, dependency vulnerabilities, authentication/authorization, secret handling, and input validation. Use for thorough security reviews of code and configuration. Do not use for general code review (use code-review) or CI security scan failures (use cicd-troubleshoot)."
disable-model-invocation: true
model: sonnet
---

# Security Audit Workflow

You are orchestrating a comprehensive security audit of the codebase.

## Workflow Steps

### Step 1: Automated Scans

Run automated security tools:

```bash
# Secret scanning
gitleaks detect --source . --verbose

# Dependency vulnerabilities
npm audit

# If Docker images exist
trivy image <image-name>
```

### Step 2: Security Code Review

Use the **security-auditor agent** to perform deep analysis:

#### Authentication & Authorization

- [ ] MSAL configuration correct (empty scopes)
- [ ] JWT validation on all protected endpoints
- [ ] Role-based access control enforced
- [ ] Session management secure

#### Multi-Tenant Security (CRITICAL)

- [ ] All queries filter by `tradingCompanyId`
- [ ] No cross-tenant data leakage possible
- [ ] Repository factory pattern enforced
- [ ] User can only access their company's data

#### Input Validation

- [ ] All inputs validated with Zod
- [ ] SQL injection prevented (parameterized queries)
- [ ] XSS prevented (output encoding)
- [ ] Path traversal prevented

#### Secret Management

- [ ] No hardcoded secrets in code
- [ ] Environment variables used correctly
- [ ] Key Vault references in Azure
- [ ] .env files in .gitignore

#### API Security

- [ ] HTTPS enforced
- [ ] CORS configured correctly
- [ ] Rate limiting in place
- [ ] Helmet middleware configured

#### Infrastructure Security

- [ ] WAF enabled on Front Door
- [ ] Private endpoints for databases
- [ ] Managed identities (no stored credentials)
- [ ] Network ACLs configured

### Step 3: OWASP Top 10 Check

Verify protection against:

1. Broken Access Control
2. Cryptographic Failures
3. Injection
4. Insecure Design
5. Security Misconfiguration
6. Vulnerable Components
7. Authentication Failures
8. Data Integrity Failures
9. Logging Failures
10. SSRF

### Step 4: Findings Classification

Classify all findings:

| Severity | Description | Response |
| -------- | ---------------------------------- | ----------------------- |
| Critical | Actively exploitable, data at risk | Fix immediately |
| High | Significant vulnerability | Fix before next release |
| Medium | Potential risk | Plan remediation |
| Low | Minor issue | Address when convenient |
| Info | Best practice suggestion | Consider |

### Step 5: Remediation Plan

For each finding:

- Describe the vulnerability
- Show evidence (code location)
- Explain the risk
- Provide specific fix
- Estimate effort

### Step 6: Verification

After fixes applied:

- Re-run automated scans
- Verify specific vulnerabilities addressed
- Update security documentation

## Output

Provide a security audit report:

```markdown
## Security Audit Report

**Date**: YYYY-MM-DD
**Scope**: [what was audited]
**Overall Risk**: LOW / MEDIUM / HIGH / CRITICAL

### Executive Summary

[Brief overview of findings]

### Critical Findings

1. **[Finding]** - `file:line`
   - Risk: [impact]
   - Fix: [specific remediation]

### High Priority Findings

[...]

### Medium Priority Findings

[...]

### Passed Checks

- [x] Multi-tenant isolation verified
- [x] No hardcoded secrets
- [x] Input validation present

### Recommendations

1. [recommendation]

### Remediation Timeline

| Finding | Severity | Owner | Due Date |
| ------- | -------- | ------ | -------- |
| [issue] | Critical | [name] | [date]   |
```

# SonarQube Scan

Run SonarQube Community analysis locally and summarize results.

## Arguments

`$ARGUMENTS` — optional: `--project <name>` to scan specific project, or empty for full scan.

## Step 1: Check SonarQube is Running

```bash
curl -s http://localhost:9000/api/system/status | jq -r '.status'
# Expected: "UP"
# If not running: docker compose -f docker-compose.platform.yml up -d sonarqube
```

## Step 2: Run Scanner

```bash
# Full Platform scan
npx sonar-scanner \
  -Dsonar.host.url=http://localhost:9000 \
  -Dsonar.login=admin \
  -Dsonar.password=admin

# Or specific project
npx sonar-scanner \
  -Dsonar.host.url=http://localhost:9000 \
  -Dsonar.login=admin \
  -Dsonar.password=admin \
  -Dsonar.projectKey=acme-{project}
```

## Step 3: Wait for Analysis

```bash
# Check task status (scanner outputs task ID)
curl -s "http://localhost:9000/api/ce/task?id={taskId}" | jq '.task.status'
# Wait until status = "SUCCESS"
```

## Step 4: Fetch Results

```bash
# Quality gate status
curl -s "http://localhost:9000/api/qualitygates/project_status?projectKey=acme" | jq '.'

# Issues summary
curl -s "http://localhost:9000/api/issues/search?projectKeys=acme&severities=BLOCKER,CRITICAL&statuses=OPEN" | jq '.total'

# Top issues
curl -s "http://localhost:9000/api/issues/search?projectKeys=acme&severities=BLOCKER,CRITICAL&ps=10" | \
  jq '.issues[] | {severity, type, message, component: .component, line}'
```

## Step 5: Summarize

Report format:

```
SonarQube Analysis: acme

Quality Gate: PASSED / FAILED
  Bugs: {count} (new: {new_count})
  Vulnerabilities: {count}
  Code Smells: {count}
  Security Hotspots: {count}
  Coverage: {percentage}%
  Duplication: {percentage}%

Top Issues:
1. [{severity}] {file}:{line} — {message}
2. [{severity}] {file}:{line} — {message}

Dashboard: http://localhost:9000/dashboard?id=acme
```

## Critical Rules

- SonarQube scans `apps/platform/` and `libs/platform/` only (configured in `sonar-project.properties`)
- Test files are excluded from analysis
- Quality gate must PASS before creating PR
- BLOCKER and CRITICAL issues must be resolved before merge

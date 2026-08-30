# Technical Specification: <Feature>

**Date**: YYYY-MM-DD
**Author**: Claude Code
**Status**: Draft
**Source Design**: <link to design document>

## Overview

### Summary

<Brief description of what will be built>

### Goals

- <Goal 1>
- <Goal 2>

### Non-Goals

- <What's explicitly out of scope>

## Source Design Reference

- **Design Document**: <path>
- **Review Status**: APPROVED
- **Review Date**: YYYY-MM-DD

## Implementation Phases

### Phase 1: <Title> (N days estimated)

**Tasks**:

1. <Task description>
   - Files: `path/to/file.ts`
   - Changes: <what changes>

2. <Task description>
   - Files: `path/to/file.ts`
   - Changes: <what changes>

**Validation**:

- [ ] Build passes
- [ ] Lint passes
- [ ] <Custom validation criteria>

---

### Phase 2: <Title>

**Tasks**:

1. ...

**Validation**:

- [ ] ...

---

### Phase N: Testing & Documentation

**Tasks**:

1. Write unit tests for all services
2. Write integration tests for API endpoints
3. Write E2E tests for critical flows
4. Update README/CLAUDE.md

**Validation**:

- [ ] Test coverage > 80%
- [ ] All E2E tests pass
- [ ] Documentation complete

## Database Changes

### New Tables

| Table | Purpose |
| ------- | --------- |
| <table> | <purpose> |

### Migrations

```sql
-- Migration: Add <feature> tables
CREATE TABLE <table> (
  id SERIAL PRIMARY KEY,
  ...
);
```

## API Changes

### New Endpoints

| Method | Path | Description |
| ------ | ------------------ | ----------------- |
| POST   | /api/v1/<resource> | Create <resource> |
| GET    | /api/v1/<resource> | List <resources>  |

### Modified Endpoints

| Method | Path | Change |
| ------ | ------------------ | ----------------------- |
| GET    | /api/v1/<existing> | Add <field> to response |

## Configuration Changes

### Environment Variables

| Variable | Purpose | Default |
| ---------- | --------- | --------- |
| <VAR_NAME> | <purpose> | <default> |

### Feature Flags

| Flag | Purpose | Default |
| ----------- | --------- | ------- |
| <FLAG_NAME> | <purpose> | false |

## Risks & Mitigations

| Risk | Mitigation |
| ------------------ | ------------ |
| <risk from design> | <mitigation> |

## Open Questions

- [ ] <Question that emerged during spec creation>

## References

- [System Design](path/to/design.md)
- [Related ADR](path/to/adr.md)

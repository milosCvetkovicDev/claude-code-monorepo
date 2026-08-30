---
name: erp-issue
description: 'Troubleshoot the ERP API integration issues: OAuth token problems, sync failures, data mapping errors, and webhook issues. Use when the user reports problems with the ERP accounting integration. Do not use for general API issues (use api-change) or production access (use production-access).'
model: sonnet
disable-model-invocation: true
---

# ERP Integration Troubleshooting Workflow

You are orchestrating the ERP integration issue resolution.

## Workflow Steps

### Step 1: Issue Identification

Use the **erp-integration-specialist agent** to:

- Identify the error type
- Check which entity is affected (Customer, Supplier, Invoice)
- Determine if it's OAuth, validation, or sync issue
- Identify affected TradingCompany

### Step 2: Diagnosis

#### OAuth Token Issues

**Symptoms:** 401 errors, "token expired"

```bash
# Check token refresh logic
grep -rn "refreshToken\|accessToken" apps/legacy-api/src/services/erp/

# Check ERP config for the trading company
grep -rn "ErpConfig" apps/legacy-api/src/
```

**Common causes:**

- Token not refreshed before expiry
- Refresh token revoked
- Clock skew between servers

#### Invoice Posting Failures

**Symptoms:** Invoices stuck in "pending_sync" state

```sql
-- Check pending sync items
SELECT * FROM invoice
WHERE pending_erp_sync = true
ORDER BY created_at DESC
LIMIT 10;

-- Check for ERP IDs
SELECT id, invoice_number, erp_id, pending_erp_sync
FROM invoice
WHERE trading_company_id = '<company-id>';
```

**Common causes:**

- Invalid tax codes
- Customer/Supplier not in ERP
- Currency mismatch
- Duplicate invoice numbers
- Validation errors from ERP API

#### Customer/Supplier Sync Issues

**Symptoms:** Entities not appearing in ERP

**Check:**

- Entity has all required fields
- No validation errors
- ERP ID present after sync

### Step 3: Background Job Status

Check pg-boss job status:

```sql
-- Check job status
SELECT name, state, COUNT(*)
FROM pgboss.job
GROUP BY name, state;

-- Check failed ERP jobs
SELECT * FROM pgboss.job
WHERE name LIKE '%erp%' AND state = 'failed'
ORDER BY createdon DESC
LIMIT 10;

-- Check job errors
SELECT id, name, data, output
FROM pgboss.job
WHERE state = 'failed'
ORDER BY createdon DESC;
```

### Step 4: Fix Implementation

Based on diagnosis:

**For OAuth issues:**

- Check token refresh logic in ErpAuthService
- Verify token storage and retrieval
- Consider re-authorization flow

**For validation issues:**

- Check entity data matches ERP requirements
- Verify tax codes exist in ERP
- Ensure currency codes match

**For sync logic issues:**

- Follow service namespace import pattern
- Ensure TradingCompany context passed correctly
- Use Big.js for decimal conversion

```typescript
// CORRECT - ERP service usage
import * as ErpService from '../services/ErpService';

const syncInvoice = async (invoice: Invoice, tradingCompany: TradingCompany) => {
  const erpConfig = await ErpConfigRepository(tradingCompany).getConfig();

  const erpInvoice = {
    ...mapToErpFormat(invoice),
    netTotal: invoice.netTotal.toString(), // Big → string
    vatTotal: invoice.vatTotal.toString(),
  };

  return ErpService.postInvoice(erpInvoice, erpConfig);
};
```

### Step 5: Testing

Use mock mode for testing:

```typescript
// Set environment for testing
ERP_MODE=mock npm test
```

Write tests that verify:

- Successful sync flow
- Error handling for API failures
- Retry logic works correctly
- Multi-tenancy isolation

### Step 6: Code Review

Use the **review-tech-lead agent** to verify:

- Service namespace imports used
- TradingCompany context correct
- Error handling comprehensive
- Retry logic appropriate

## ERP Entity Mapping

| Acme Entity | ERP Entity | Key Fields |
| ---------------- | ----------- | --------------------------------- |
| Customer | Customer | accountRef, name, address |
| Supplier | Supplier | accountRef, name, address |
| Sale Invoice | SOP Invoice | invoiceNumber, customerRef, lines |
| Purchase Invoice | POP Invoice | invoiceNumber, supplierRef, lines |

## Output

Provide:

- Root cause of ERP issue
- Fix implemented
- Testing verification
- Monitoring recommendations
- Prevention measures

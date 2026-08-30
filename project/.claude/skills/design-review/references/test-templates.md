# Visual Regression & Interaction Test Templates

## Visual Regression Setup

```typescript
// apps/legacy-web-e2e/src/design/visual-regression.spec.ts
import { expect, test } from '@playwright/test';

test.describe('Visual Regression', () => {
  test('Dashboard matches baseline', async ({ page }) => {
    await page.goto('/dashboard');
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveScreenshot('dashboard.png', {
      maxDiffPixels: 100,
      threshold: 0.2,
    });
  });

  test('Invoice list matches baseline', async ({ page }) => {
    await page.goto('/invoices');
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveScreenshot('invoice-list.png', {
      maxDiffPixels: 100,
    });
  });
});
```

## Interaction State Testing

```typescript
test.describe('Component States', () => {
  test('Button states', async ({ page }) => {
    await page.goto('/test-page');

    const button = page.getByRole('button', { name: 'Submit' });
    await button.hover();
    await expect(button).toHaveScreenshot('button-hover.png');

    await button.focus();
    await expect(button).toHaveScreenshot('button-focus.png');

    await page.getByRole('button', { name: 'Disabled' }).screenshot({
      path: 'screenshots/button-disabled.png',
    });
  });

  test('Form validation states', async ({ page }) => {
    await page.goto('/form-page');

    await page.getByRole('button', { name: 'Submit' }).click();

    await expect(page.locator('form')).toHaveScreenshot('form-errors.png');
  });
});
```

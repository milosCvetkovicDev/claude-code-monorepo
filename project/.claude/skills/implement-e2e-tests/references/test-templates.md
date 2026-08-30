# E2E Test Templates

## Page Object Template

```typescript
// apps/legacy-web-e2e/src/pages/<feature>.page.ts
import { Locator, Page } from '@playwright/test';

export class <Feature>Page {
  readonly page: Page;

  // Locators - prefer data-testid
  readonly container: Locator;
  readonly submitButton: Locator;
  readonly table: Locator;
  readonly searchInput: Locator;

  constructor(page: Page) {
    this.page = page;
    this.container = page.getByTestId('<feature>-container');
    this.submitButton = page.getByTestId('<feature>-submit-button');
    this.table = page.getByTestId('<feature>-table');
    this.searchInput = page.getByPlaceholder('Search...');
  }

  // Navigation
  async goto() {
    await this.page.goto('/<feature>');
    await this.container.waitFor({ state: 'visible' });
  }

  // Actions
  async search(query: string) {
    await this.searchInput.fill(query);
    await this.searchInput.press('Enter');
    await this.page.waitForLoadState('networkidle');
  }

  async selectRow(index: number) {
    const row = this.table.locator('tr').nth(index + 1); // Skip header
    await row.click();
  }

  async submit() {
    await this.submitButton.click();
    await this.page.waitForLoadState('networkidle');
  }

  // Assertion helpers
  async getRowCount(): Promise<number> {
    return await this.table.locator('tbody tr').count();
  }

  async hasSuccessMessage(): Promise<boolean> {
    return await this.page.getByRole('alert').filter({ hasText: /success/i }).isVisible();
  }
}
```

## Test File Template

```typescript
// apps/legacy-web-e2e/src/tests/<feature>.spec.ts
import { expect, test } from '../fixtures/auth.fixture';
import { <Feature>Page } from '../pages/<feature>.page';

test.describe('<Feature> Management', () => {
  let featurePage: <Feature>Page;

  test.beforeEach(async ({ authenticatedPage }) => {
    featurePage = new <Feature>Page(authenticatedPage);
    await featurePage.goto();
  });

  test.describe('Smoke Tests @smoke', () => {
    test('should display <feature> list', async () => {
      await expect(featurePage.container).toBeVisible();
      await expect(featurePage.table).toBeVisible();
    });

    test('should allow searching <feature>s', async () => {
      await featurePage.search('test query');
      await expect(featurePage.table).toContainText('test');
    });
  });

  test.describe('Regression Tests', () => {
    test('should create new <feature>', async () => {
      await featurePage.page.getByRole('button', { name: /create/i }).click();
      await featurePage.page.getByLabel('Name').fill('Test <Feature>');
      await featurePage.page.getByRole('button', { name: /save/i }).click();
      await expect(featurePage.page.getByRole('alert')).toContainText('success');
    });

    test('should edit existing <feature>', async ({ authenticatedPage }) => {
      await featurePage.selectRow(0);
      await authenticatedPage.getByRole('button', { name: /edit/i }).click();
      await authenticatedPage.getByLabel('Name').fill('Updated Name');
      await authenticatedPage.getByRole('button', { name: /save/i }).click();
      await expect(featurePage.table).toContainText('Updated Name');
    });

    test('should handle empty state', async ({ authenticatedPage }) => {
      await featurePage.search('zzz-nonexistent-zzz');
      await expect(authenticatedPage.getByText(/no.*found/i)).toBeVisible();
    });

    test('should handle errors gracefully', async ({ authenticatedPage }) => {
      await authenticatedPage.route('**/api/v1/<feature>s/**', (route) => {
        route.fulfill({
          status: 500,
          body: JSON.stringify({ error: 'Internal Server Error' }),
        });
      });
      await featurePage.goto();
      await expect(authenticatedPage.getByRole('alert')).toContainText(/error/i);
    });
  });
});
```

## Auth Fixture Template

```typescript
// apps/legacy-web-e2e/src/fixtures/auth.fixture.ts
import { test as base, Page } from '@playwright/test';

type AuthFixtures = {
  authenticatedPage: Page;
};

export const test = base.extend<AuthFixtures>({
  authenticatedPage: async ({ page }, use) => {
    const cookies = JSON.parse(process.env.AUTH_COOKIES || '[]');
    await page.context().addCookies(cookies);

    await page.route('**/*', (route) => {
      const headers = {
        ...route.request().headers(),
        'X-Trading-Company-Id': '1',
      };
      route.continue({ headers });
    });

    await use(page);
  },
});

export { expect } from '@playwright/test';
```

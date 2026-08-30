# Playwright Scripts for Design Review

## Screenshot Capture

```typescript
// apps/legacy-web-e2e/src/utils/design-capture.ts
import { chromium } from '@playwright/test';

async function captureDesignScreenshots(urls: string[]) {
  const browser = await chromium.launch();
  const context = await browser.newContext({
    viewport: { width: 1920, height: 1080 },
    storageState: '.auth/user.json',
  });

  for (const url of urls) {
    const page = await context.newPage();
    await page.goto(url);
    await page.waitForLoadState('networkidle');

    // Full page screenshot
    await page.screenshot({
      path: `screenshots/design-review/${url.replace(/\//g, '-')}-full.png`,
      fullPage: true,
    });

    // Viewport screenshot (above the fold)
    await page.screenshot({
      path: `screenshots/design-review/${url.replace(/\//g, '-')}-viewport.png`,
    });

    // Mobile viewport
    await page.setViewportSize({ width: 375, height: 667 });
    await page.screenshot({
      path: `screenshots/design-review/${url.replace(/\//g, '-')}-mobile.png`,
    });

    // Tablet viewport
    await page.setViewportSize({ width: 768, height: 1024 });
    await page.screenshot({
      path: `screenshots/design-review/${url.replace(/\//g, '-')}-tablet.png`,
    });
  }

  await browser.close();
}
```

## DOM Inspection

```typescript
async function inspectComponents(page: Page) {
  // Extract all MUI components using page.$$() selectors
  const muiComponents = await page.$$('[class*="Mui"]');
  // Map each element to structured data:
  // tagName, classes, role, aria-label, tabindex

  // Extract color usage from computed styles
  // Collect all unique color and backgroundColor values
  // Filter out transparent values

  // Extract typography from heading and text elements
  // Collect fontSize, fontWeight, lineHeight for:
  // h1, h2, h3, h4, h5, h6, p, span, label

  return { muiComponents, colors, typography };
}
```

## Accessibility Scan

```typescript
async function accessibilityScan(page: Page) {
  // Check for missing alt text on images
  const imagesWithoutAlt = await page.$$('img:not([alt])');

  // Check for missing form labels
  // Query inputs without aria-label or aria-labelledby
  // Verify each has a matching label[for="id"]

  // Count focusable elements
  const focusableElements = await page.$$('button, a, input, select, textarea, [tabindex]');

  // Check color contrast ratios against WCAG thresholds

  return {
    imagesWithoutAlt: imagesWithoutAlt.length,
    focusableElements: focusableElements.length,
  };
}
```

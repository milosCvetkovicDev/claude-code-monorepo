# Additional Tools & Techniques

## Browser DevTools Integration

```bash
npx playwright open --devtools http://localhost:4200
```

## Figma/Design Comparison

```typescript
import pixelmatch from 'pixelmatch';
import { PNG } from 'pngjs';

async function compareToDesign(implementationPath: string, designPath: string) {
  const img1 = PNG.sync.read(fs.readFileSync(implementationPath));
  const img2 = PNG.sync.read(fs.readFileSync(designPath));

  const { width, height } = img1;
  const diff = new PNG({ width, height });

  const numDiffPixels = pixelmatch(img1.data, img2.data, diff.data, width, height, {
    threshold: 0.1,
  });

  fs.writeFileSync('diff.png', PNG.sync.write(diff));

  return {
    totalPixels: width * height,
    diffPixels: numDiffPixels,
    diffPercent: (numDiffPixels / (width * height)) * 100,
  };
}
```

## Lighthouse Integration

```bash
npx lighthouse http://localhost:4200/dashboard \
  --output=json \
  --output-path=./lighthouse-report.json \
  --only-categories=accessibility,best-practices
```

## Storybook Integration (Suggested)

```bash
# Add Storybook to the project
npx nx g @nx/react:storybook-configuration legacy-web

# Run Storybook
nx run legacy-web:storybook
```

Benefits:
- Isolated component development
- Visual testing per component
- Interactive documentation
- Design handoff tool

## Quick Commands

```bash
# Capture screenshots of all main pages
npx playwright test design-capture.spec.ts

# Run accessibility audit
npx playwright test accessibility.spec.ts

# Generate visual regression baselines
npx playwright test visual-regression.spec.ts --update-snapshots

# Open Playwright UI for interactive inspection
npx playwright test --ui
```

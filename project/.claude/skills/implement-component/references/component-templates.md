# Component Implementation Templates

## Component File

```typescript
// apps/legacy-web/src/components/<feature>/<ComponentName>.tsx

import { FC } from 'react';
import {
  Box,
  Paper,
  Typography,
  // ... MUI components
} from '@mui/material';

interface <ComponentName>Props {
  data: <DataType>[];
  onSelect?: (item: <DataType>) => void;
  loading?: boolean;
}

export const <ComponentName>: FC<<ComponentName>Props> = ({
  data,
  onSelect,
  loading = false,
}) => {
  if (loading) {
    return <CircularProgress />;
  }

  return (
    <Paper sx={{ p: 2 }}>
      <Typography variant="h6">
        {/* Title */}
      </Typography>
      <Box>
        {/* Content */}
      </Box>
    </Paper>
  );
};
```

## Component Test File

```typescript
// apps/legacy-web/src/components/<feature>/<ComponentName>.spec.tsx

import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { <ComponentName> } from './<ComponentName>';
import { QueryClientProvider } from '@tanstack/react-query';
import { createTestQueryClient } from '../../../test/utils';

const renderComponent = (props = {}) => {
  const defaultProps = {
    data: [{ id: 1, name: 'Test' }],
    onSelect: jest.fn(),
  };

  return render(
    <QueryClientProvider client={createTestQueryClient()}>
      <<ComponentName> {...defaultProps} {...props} />
    </QueryClientProvider>
  );
};

describe('<ComponentName>', () => {
  it('should render data', () => {
    renderComponent();
    expect(screen.getByText('Test')).toBeInTheDocument();
  });

  it('should call onSelect when item is clicked', async () => {
    const onSelect = jest.fn();
    renderComponent({ onSelect });
    await userEvent.click(screen.getByText('Test'));
    expect(onSelect).toHaveBeenCalledWith({ id: 1, name: 'Test' });
  });

  it('should show loading state', () => {
    renderComponent({ loading: true });
    expect(screen.getByRole('progressbar')).toBeInTheDocument();
  });

  it('should show empty state when no data', () => {
    renderComponent({ data: [] });
    expect(screen.getByText(/no.*found/i)).toBeInTheDocument();
  });
});
```

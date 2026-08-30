# Unit Test Templates

## Backend Service Test

```typescript
// apps/legacy-api/test/unit/services/<Service>.spec.ts
import { <functionName> } from '../../../src/services/<Service>';
import { <Repository> } from '../../../src/repositories/<Repository>';
import { createMockTradingCompany } from '../../fixtures/trading-company.fixture';

jest.mock('../../../src/repositories/<Repository>');

describe('<Service>', () => {
  const mockTradingCompany = createMockTradingCompany();

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('<functionName>', () => {
    it('should return <expected> when <condition>', async () => {
      // Arrange
      const mockData = { id: 1, name: 'Test' };
      const mockRepo = {
        findOne: jest.fn().mockResolvedValue(mockData),
      };
      (<Repository> as jest.Mock).mockReturnValue(mockRepo);

      // Act
      const result = await <functionName>(mockTradingCompany, 1);

      // Assert
      expect(result).toEqual(mockData);
      expect(mockRepo.findOne).toHaveBeenCalledWith({ where: { id: 1 } });
    });

    it('should throw NotFoundError when entity does not exist', async () => {
      (<Repository> as jest.Mock).mockReturnValue({
        findOne: jest.fn().mockResolvedValue(null),
      });

      await expect(<functionName>(mockTradingCompany, 999))
        .rejects.toThrow('not found');
    });

    it('should enforce multi-tenancy', async () => {
      const mockRepo = { findOne: jest.fn().mockResolvedValue({ id: 1 }) };
      (<Repository> as jest.Mock).mockReturnValue(mockRepo);

      await <functionName>(mockTradingCompany, 1);

      expect(<Repository>).toHaveBeenCalledWith(mockTradingCompany);
    });

    it('should handle <edge case>', async () => {
      // Test edge cases: null, empty, boundary values
    });
  });
});
```

## Frontend Component Test

```typescript
// apps/legacy-web/src/components/<path>/<Component>.spec.tsx
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClientProvider } from '@tanstack/react-query';
import { <Component> } from './<Component>';
import { createTestQueryClient } from '../../../test/utils';

jest.mock('../../../hooks/use<Feature>', () => ({
  use<Feature>Query: jest.fn(),
}));

const renderComponent = (props = {}) => {
  const defaultProps = {
    data: [{ id: 1, name: 'Test' }],
    onSelect: jest.fn(),
    loading: false,
  };

  return {
    ...render(
      <QueryClientProvider client={createTestQueryClient()}>
        <<Component> {...defaultProps} {...props} />
      </QueryClientProvider>
    ),
    props: { ...defaultProps, ...props },
  };
};

describe('<Component>', () => {
  it('should render data correctly', () => {
    renderComponent();
    expect(screen.getByText('Test')).toBeInTheDocument();
  });

  it('should call onSelect when item is clicked', async () => {
    const { props } = renderComponent();
    await userEvent.click(screen.getByText('Test'));
    expect(props.onSelect).toHaveBeenCalledWith({ id: 1, name: 'Test' });
  });

  it('should show loading state', () => {
    renderComponent({ loading: true });
    expect(screen.getByRole('progressbar')).toBeInTheDocument();
  });

  it('should show empty state when no data', () => {
    renderComponent({ data: [] });
    expect(screen.getByText(/no.*found/i)).toBeInTheDocument();
  });

  it('should handle user input', async () => {
    renderComponent();
    const input = screen.getByRole('textbox');
    await userEvent.type(input, 'search query');
    expect(input).toHaveValue('search query');
  });
});
```

## Test Fixtures

```typescript
// Backend: test/fixtures/<entity>.fixture.ts
import { <Entity> } from '../../src/models/db/<Entity>';

export const createMock<Entity> = (overrides = {}): <Entity> => ({
  id: 1,
  name: 'Test Entity',
  createdAt: new Date(),
  ...overrides,
} as <Entity>);

// Frontend: test/utils.ts
import { QueryClient } from '@tanstack/react-query';

export const createTestQueryClient = () =>
  new QueryClient({
    defaultOptions: {
      queries: { retry: false },
      mutations: { retry: false },
    },
  });
```

# CLAUDE.md - Domain Types Library

Library-specific instructions for Claude Code. See also the parent `../../../CLAUDE.md` for project-wide conventions.

## Overview

`@acme/domain-types` is the **pure domain layer** of the Acme trading platform. It contains:

- **Value Objects**: Immutable types for business concepts (Money, Quantity, Address, DateRange)
- **Domain Services**: Business logic with no external dependencies
- **Interfaces**: Contracts for infrastructure implementations
- **Domain Errors**: Business-specific exception types
- **Constants**: Production-level reference data (currencies, units)

## Critical Constraints

### Zero External Dependencies

This library has **ZERO** external dependencies except `big.js` for decimal arithmetic:

```typescript
// ALLOWED
import { faker } from '@faker-js/faker'; // NO - testing
import Big from 'big.js';
import express from 'express'; // NO - framework

// FORBIDDEN - Never add these imports
import { Entity } from 'typeorm'; // NO - infrastructure
```

### Why This Matters

- Domain layer is the **innermost layer** in Clean Architecture
- Dependencies flow inward - nothing in domain depends on outer layers
- Makes the library reusable across: backend, frontend, data-seeding, CLI tools
- Enables pure unit testing without mocking frameworks

## Quick Reference

```bash
# Build the library
npx nx build domain-types

# Run tests
npx nx test domain-types

# Run specific test
npx nx test domain-types --testPathPattern=Money
```

## AI Assistant Guidelines

### When Modifying This Library

1. **Never add external dependencies** (except big.js)
2. **Use `readonly` for all value object properties**
3. **Make value objects immutable** - operations return new instances
4. **Throw domain errors, not generic Error**
5. **Keep interfaces minimal** - only what's needed by consumers

### Adding a Value Object

```typescript
// src/value-objects/NewValueObject.ts
import Big from 'big.js';

export interface NewValueObjectData {
  readonly someValue: string;
  readonly amount: Big;
}

export class NewValueObject {
  private readonly _data: NewValueObjectData;

  private constructor(data: NewValueObjectData) {
    this._data = data;
  }

  static create(someValue: string, amount: Big): NewValueObject {
    // Validation
    if (!someValue) {
      throw new InvalidNewValueObjectError('someValue cannot be empty');
    }
    return new NewValueObject({ someValue, amount });
  }

  get someValue(): string {
    return this._data.someValue;
  }

  get amount(): Big {
    return this._data.amount;
  }

  // Immutable operations - return new instances
  withAmount(newAmount: Big): NewValueObject {
    return new NewValueObject({ ...this._data, amount: newAmount });
  }

  equals(other: NewValueObject): boolean {
    return this._data.someValue === other.someValue && this._data.amount.eq(other.amount);
  }
}
```

### Adding a Domain Error

```typescript
// src/errors/NewError.ts
export class NewError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'NewError';
  }
}
```

### Adding a Domain Service

```typescript
// src/services/NewService.ts
import Big from 'big.js';

export class NewService {
  // No constructor dependencies - pure functions only

  calculate(input: Big): Big {
    return input.times(2);
  }
}
```

### Adding a Constant

```typescript
// src/constants/newConstants.ts
export interface NewConstantDefinition {
  readonly code: string;
  readonly name: string;
}

export const NEW_CONSTANTS: readonly NewConstantDefinition[] = [
  { code: 'A', name: 'Alpha' },
  { code: 'B', name: 'Beta' },
] as const;
```

## Project Structure

```
libs/shared/domain-types/
├── src/
│   ├── __tests__/                # Jest test suite
│   │   ├── Money.spec.ts
│   │   ├── Quantity.spec.ts
│   │   ├── StockBalanceService.spec.ts
│   │   └── ...
│   │
│   ├── value-objects/            # Immutable domain types
│   │   ├── Money.ts              # Currency-aware amounts
│   │   ├── Quantity.ts           # Unit-aware quantities
│   │   ├── Address.ts            # Multi-line addresses
│   │   ├── DateRange.ts          # Date boundaries
│   │   └── index.ts
│   │
│   ├── services/                 # Business logic
│   │   ├── StockBalanceService.ts     # Stock allocation
│   │   ├── MarginCalculationService.ts # Profit margins
│   │   ├── CurrencyConsistencyService.ts
│   │   ├── AccountingMonthService.ts
│   │   └── index.ts
│   │
│   ├── interfaces/               # Contracts for infrastructure
│   │   ├── IDataGenerator.ts     # Random data generation
│   │   ├── IEntityFactory.ts     # Factory pattern
│   │   ├── IRepository.ts        # Data persistence
│   │   └── index.ts
│   │
│   ├── errors/                   # Domain exceptions
│   │   ├── InvalidMoneyError.ts
│   │   ├── StockOverflowError.ts
│   │   ├── CurrencyMismatchError.ts
│   │   ├── AccountingMonthClosedError.ts
│   │   └── index.ts
│   │
│   ├── constants/                # Production reference data
│   │   ├── currencies.ts         # STANDARD_CURRENCIES
│   │   ├── units.ts              # STANDARD_UNITS, UnitType
│   │   └── index.ts
│   │
│   └── index.ts                  # Public API exports
│
├── CLAUDE.md                     # This file
├── project.json                  # Nx configuration
└── tsconfig.*.json
```

## Key Types

### Value Objects

| Type | Purpose | Key Operations |
| ----------- | ---------------------- | ---------------------------------------------- |
| `Money`     | Currency-aware amounts | `add()`, `subtract()`, `multiply()`, `toRaw()` |
| `Quantity`  | Unit-aware quantities | `add()`, `subtract()`, `toTonnes()`, `toRaw()` |
| `Address`   | Multi-line addresses | `toMultiLine()`, `toSingleLine()`              |
| `DateRange` | Date boundaries | `contains()`, `overlaps()`, `days()`           |

### Domain Services

| Service | Purpose |
| ---------------------------- | ------------------------------------- |
| `StockBalanceService`        | Enforce sales cannot exceed purchases |
| `MarginCalculationService`   | Calculate profit margins |
| `CurrencyConsistencyService` | Validate currency matching |
| `AccountingMonthService`     | Fiscal period management |

### Constants

| Constant | Purpose |
| --------------------- | ---------------------------------------- | -------------- |
| `STANDARD_CURRENCIES` | Trading currencies (GBP, EUR, USD)       |
| `STANDARD_UNITS`      | Measurement units with tonne conversions |
| `UnitType`            | `'Bulk'                                  | 'Packed'` type |

## Important Rules

1. **No external dependencies** - Only `big.js` allowed
2. **Immutable value objects** - All operations return new instances
3. **Readonly properties** - Use `readonly` for all interface fields
4. **Domain errors** - Throw specific domain errors, not generic Error
5. **Pure functions** - Services should have no side effects
6. **Test everything** - Domain logic must have comprehensive tests

## Consumers

This library is used by:

- **legacy-api**: Business logic and validation
- **legacy-web**: Display formatting and calculations
- **data-seeding**: Test data generation
- **Future**: CLI tools, mobile apps, etc.

## Related Documentation

- [data-seeding/CLAUDE.md](../../data-seeding/CLAUDE.md) - Factory patterns
- [Root CLAUDE.md](../../../CLAUDE.md) - Project-wide guidelines

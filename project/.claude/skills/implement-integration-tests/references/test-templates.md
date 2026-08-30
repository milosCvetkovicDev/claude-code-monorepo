# Integration Test Templates

## Test Database Utility

```typescript
// apps/legacy-api/test/utils/test-db.ts
import { DataSource } from 'typeorm';

import { entities } from '../../src/models/db';

let testDataSource: DataSource | null = null;

export const createTestDataSource = async (): Promise<DataSource> => {
  if (testDataSource?.isInitialized) {
    return testDataSource;
  }

  testDataSource = new DataSource({
    type: 'postgres',
    host: process.env.TEST_DB_HOST || 'localhost',
    port: parseInt(process.env.TEST_DB_PORT || '5433'),
    username: 'legacy',
    password: 'postgres',
    database: 'legacy_test',
    entities,
    synchronize: true,
    logging: false,
  });

  await testDataSource.initialize();
  return testDataSource;
};

export const closeTestDataSource = async (): Promise<void> => {
  if (testDataSource?.isInitialized) {
    await testDataSource.destroy();
    testDataSource = null;
  }
};

export const beginTransaction = async (ds: DataSource): Promise<void> => {
  await ds.query('BEGIN');
};

export const rollbackTransaction = async (ds: DataSource): Promise<void> => {
  await ds.query('ROLLBACK');
};
```

## Repository Integration Test

```typescript
// apps/legacy-api/test/integration/repositories/<Repository>.integration.spec.ts
import { DataSource } from 'typeorm';
import {
  createTestDataSource,
  closeTestDataSource,
  beginTransaction,
  rollbackTransaction,
} from '../../utils/test-db';
import { <Repository> } from '../../../src/repositories/<Repository>';
import { TradingCompany } from '../../../src/models/db/TradingCompany';
import { seedTestData } from '../../fixtures/seed';

describe('<Repository> Integration', () => {
  let dataSource: DataSource;
  let tradingCompany: TradingCompany;
  let otherTradingCompany: TradingCompany;

  beforeAll(async () => {
    dataSource = await createTestDataSource();
    const seed = await seedTestData(dataSource);
    tradingCompany = seed.tradingCompany;
    otherTradingCompany = seed.otherTradingCompany;
  });

  afterAll(async () => {
    await closeTestDataSource();
  });

  beforeEach(async () => {
    await beginTransaction(dataSource);
  });

  afterEach(async () => {
    await rollbackTransaction(dataSource);
  });

  describe('findAll', () => {
    it('should return only entities for the given trading company', async () => {
      const repo = <Repository>(tradingCompany);
      const results = await repo.findAll();

      expect(results.length).toBeGreaterThan(0);
      results.forEach((entity) => {
        expect(entity.tradingCompanyId).toBe(tradingCompany.id);
      });
    });

    it('should not return entities from other trading companies', async () => {
      const repo = <Repository>(tradingCompany);
      const results = await repo.findAll();

      const otherCompanyEntities = results.filter(
        (e) => e.tradingCompanyId === otherTradingCompany.id
      );
      expect(otherCompanyEntities).toHaveLength(0);
    });
  });

  describe('findById', () => {
    it('should return entity when found', async () => {
      const repo = <Repository>(tradingCompany);
      const result = await repo.findById(1);

      expect(result).toBeDefined();
      expect(result?.id).toBe(1);
    });

    it('should return null when entity does not exist', async () => {
      const repo = <Repository>(tradingCompany);
      const result = await repo.findById(99999);

      expect(result).toBeNull();
    });
  });

  describe('create', () => {
    it('should create entity with correct trading company', async () => {
      const repo = <Repository>(tradingCompany);
      const data = { name: 'Integration Test Entity' };

      const result = await repo.create(data);

      expect(result.id).toBeDefined();
      expect(result.tradingCompanyId).toBe(tradingCompany.id);
      expect(result.name).toBe(data.name);
    });
  });
});
```

## API Integration Test

```typescript
// apps/legacy-api/test/integration/routes/<resource>.integration.spec.ts
import request from 'supertest';
import { DataSource } from 'typeorm';

import { app } from '../../../src/app';
import { seedTestData } from '../../fixtures/seed';
import { generateTestToken } from '../../utils/auth';
import {
  beginTransaction,
  closeTestDataSource,
  createTestDataSource,
  rollbackTransaction,
} from '../../utils/test-db';

describe('API: /api/v1/<resources>', () => {
  let dataSource: DataSource;
  let authToken: string;
  let tradingCompanyId: number;

  beforeAll(async () => {
    dataSource = await createTestDataSource();
    const seed = await seedTestData(dataSource);
    tradingCompanyId = seed.tradingCompany.id;
    authToken = generateTestToken(seed.user);
  });

  afterAll(async () => {
    await closeTestDataSource();
  });

  beforeEach(async () => {
    await beginTransaction(dataSource);
  });

  afterEach(async () => {
    await rollbackTransaction(dataSource);
  });

  describe('GET /api/v1/<resources>', () => {
    it('should return 200 with list of resources', async () => {
      const response = await request(app)
        .get('/api/v1/<resources>')
        .set('Authorization', `Bearer ${authToken}`)
        .set('X-Trading-Company-Id', String(tradingCompanyId));

      expect(response.status).toBe(200);
      expect(Array.isArray(response.body)).toBe(true);
    });

    it('should return 401 without authentication', async () => {
      const response = await request(app).get('/api/v1/<resources>');
      expect(response.status).toBe(401);
    });

    it('should return 403 for wrong trading company', async () => {
      const response = await request(app)
        .get('/api/v1/<resources>')
        .set('Authorization', `Bearer ${authToken}`)
        .set('X-Trading-Company-Id', '99999');

      expect(response.status).toBe(403);
    });
  });

  describe('POST /api/v1/<resources>', () => {
    it('should create resource and return 201', async () => {
      const newResource = { name: 'Integration Test Resource' };

      const response = await request(app)
        .post('/api/v1/<resources>')
        .set('Authorization', `Bearer ${authToken}`)
        .set('X-Trading-Company-Id', String(tradingCompanyId))
        .send(newResource);

      expect(response.status).toBe(201);
      expect(response.body.id).toBeDefined();
      expect(response.body.name).toBe(newResource.name);
    });

    it('should return 400 for invalid input', async () => {
      const response = await request(app)
        .post('/api/v1/<resources>')
        .set('Authorization', `Bearer ${authToken}`)
        .set('X-Trading-Company-Id', String(tradingCompanyId))
        .send({});

      expect(response.status).toBe(400);
    });
  });

  describe('GET /api/v1/<resources>/:id', () => {
    it('should return 200 with resource', async () => {
      const response = await request(app)
        .get('/api/v1/<resources>/1')
        .set('Authorization', `Bearer ${authToken}`)
        .set('X-Trading-Company-Id', String(tradingCompanyId));

      expect(response.status).toBe(200);
      expect(response.body.id).toBe(1);
    });

    it('should return 404 for non-existent resource', async () => {
      const response = await request(app)
        .get('/api/v1/<resources>/99999')
        .set('Authorization', `Bearer ${authToken}`)
        .set('X-Trading-Company-Id', String(tradingCompanyId));

      expect(response.status).toBe(404);
    });
  });
});
```

## Seed Data Template

```typescript
// apps/legacy-api/test/fixtures/seed.ts
import { DataSource } from 'typeorm';

import { TradingCompany } from '../../src/models/db/TradingCompany';
import { User } from '../../src/models/db/User';

export interface SeedData {
  tradingCompany: TradingCompany;
  otherTradingCompany: TradingCompany;
  user: User;
}

export const seedTestData = async (dataSource: DataSource): Promise<SeedData> => {
  const tradingCompanyRepo = dataSource.getRepository(TradingCompany);
  const userRepo = dataSource.getRepository(User);

  const tradingCompany = await tradingCompanyRepo.save({
    name: 'Test Company',
    code: 'TEST',
  });

  const otherTradingCompany = await tradingCompanyRepo.save({
    name: 'Other Company',
    code: 'OTHER',
  });

  const user = await userRepo.save({
    email: 'test@example.com',
    firstName: 'Test',
    lastName: 'User',
    tradingCompanyId: tradingCompany.id,
  });

  return { tradingCompany, otherTradingCompany, user };
};
```

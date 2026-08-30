---
name: implement-tool
description: "Implement an MCP (Model Context Protocol) tool for the acme-mcp server. Use when the user needs a new tool for database queries, Azure operations, or other integrations. Do not use for API endpoints (use implement-endpoint) or CLI scripts."
model: sonnet
disable-model-invocation: true
args: <project-name> <tool-name>
---

# Implement MCP Tool

You are implementing a single MCP tool from its specification.

## Input

- **project-name**: The MCP server project (e.g., `acme-mcp`)
- **tool-name**: Name of the tool to implement (e.g., `acme_db_status`)

## Workflow

### Step 1: Find Tool Specification

1. Look for technical spec in `docs/plans/*-technical-spec.md`
2. Search for the tool name in the spec
3. Extract:
   - Purpose
   - Input schema
   - Output schema
   - Implementation notes

### Step 2: Create Tool Handler

Create the tool handler file following MCP SDK patterns:

```typescript
// apps/<project>/src/tools/<tool-name>.tool.ts
import { z } from 'zod';

// Input schema
export const <ToolName>InputSchema = z.object({
  // Define input parameters from spec
});

export type <ToolName>Input = z.infer<typeof <ToolName>InputSchema>;

// Output type
export interface <ToolName>Output {
  // Define output structure from spec
}

// Tool handler
export const handle<ToolName> = async (
  input: <ToolName>Input,
  context: ToolContext
): Promise<<ToolName>Output> => {
  // Validate input
  const validated = <ToolName>InputSchema.parse(input);

  // Call service
  const result = await <ServiceName>.<methodName>(validated);

  // Return formatted output
  return result;
};

// Tool definition for MCP registration
export const <toolName>Tool = {
  name: '<tool_name>',
  description: '<purpose from spec>',
  inputSchema: <ToolName>InputSchema,
  handler: handle<ToolName>,
};
```

### Step 3: Create/Update Service

If the tool needs a new service or service method:

```typescript
// apps/<project>/src/services/<domain>.service.ts

// Use functional exports (not classes)
export const <methodName> = async (
  params: <ParamsType>
): Promise<<ReturnType>> => {
  // Implementation
};
```

### Step 4: Register Tool

Add the tool to the MCP server registration:

```typescript
// apps/<project>/src/index.ts
import { <toolName>Tool } from './tools/<tool-name>.tool';

// Add to tools array
const tools = [
  // ... existing tools
  <toolName>Tool,
];
```

### Step 5: Write Unit Tests

```typescript
// apps/<project>/test/unit/tools/<tool-name>.tool.spec.ts
import { handle<ToolName> } from '../../../src/tools/<tool-name>.tool';

describe('<tool_name>', () => {
  it('should return expected output for valid input', async () => {
    // Arrange
    const input = { /* test input */ };
    const mockContext = { /* mock context */ };

    // Act
    const result = await handle<ToolName>(input, mockContext);

    // Assert
    expect(result).toMatchObject({ /* expected output */ });
  });

  it('should throw error for invalid input', async () => {
    // Arrange
    const invalidInput = { /* invalid input */ };

    // Act & Assert
    await expect(handle<ToolName>(invalidInput, mockContext))
      .rejects.toThrow();
  });
});
```

### Step 6: Verify

1. Run tests: `nx run <project>:test -- --testPathPattern=<tool-name>`
2. Run lint: `nx run <project>:lint`
3. Build: `nx run <project>:build`

## Output

````markdown
## Tool Implemented: <tool_name>

### Files Created/Modified

- `apps/<project>/src/tools/<tool-name>.tool.ts` (created)
- `apps/<project>/src/services/<domain>.service.ts` (modified)
- `apps/<project>/src/index.ts` (modified)
- `apps/<project>/test/unit/tools/<tool-name>.tool.spec.ts` (created)

### Input Schema

```json
{
  "type": "object",
  "properties": {
    // ...
  }
}
```
````

### Verification

| Check | Status |
| ----- | ------ |
| Tests | ✅     |
| Lint | ✅     |
| Build | ✅     |

### Usage Example

```typescript
const result = await mcpClient.callTool('<tool_name>', {
  // input params
});
```

```

## Conventions

- Tool names use snake_case: `acme_db_status`
- File names use kebab-case: `db-status.tool.ts`
- Handler functions use camelCase: `handleDbStatus`
- Always validate input with Zod schemas
- Always write unit tests for the handler
```

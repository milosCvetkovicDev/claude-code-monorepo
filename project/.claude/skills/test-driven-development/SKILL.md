---
name: test-driven-development
description: 'Write failing tests first, then implement to make them pass, then refactor. Project-level enhancements to the base TDD skill from superpowers plugin.'
---

# Test-Driven Development — Project Enhancements

This file extends the base TDD skill from the superpowers plugin. See the plugin version for the core red-green-refactor workflow.

## Anti-Rationalization Table

| If you're thinking...                                   | Remember...                                                                                                                            |
| ------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| "I'll write tests after the code works"                 | Writing tests after means testing what you built, not what you should have built. Red-green-refactor exists for a reason.              |
| "This is too simple to need a test"                     | Simple code gets complex fast. The test documents the expected behavior and catches regressions.                                       |
| "Mocking is easier than setting up the real thing"      | Mocks test your assumptions, not reality. Acme rule: use real database in integration tests — we got burned by mock/prod divergence. |
| "I need to see the implementation to know what to test" | Start with acceptance criteria. What should the code DO? Write that as a test first.                                                   |
| "TDD slows me down"                                     | TDD slows down typing. It speeds up shipping correct code. The cost of a bug in production dwarfs the cost of writing a test.          |

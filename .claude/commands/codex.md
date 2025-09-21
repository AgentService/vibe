<!--
name: reasoning-solve
description: Forces structured reasoning and codex consultation for problem-solving
usage: /codex "your problem description"
-->

# Structured Problem-Solving with Codex Consultation

You should solve the following task with structured reasoning: **$ARGUMENTS**

## MANDATORY Work Steps:

### 1. PROBLEM ANALYSIS (Reasoning Required)

Analyze the problem systematically:

-   What is the core problem?
-   What constraints and requirements exist?
-   What dependencies and risks need to be considered?
-   What existing patterns/code could be relevant?

### 2. CODEX CONSULTATION (MANDATORY)

**BEFORE you search for solutions**, execute this command:

```
codex exec "How to solve: $ARGUMENTS - considering modern best practices, architecture patterns, and potential pitfalls. Provide implementation strategies and alternative approaches."
```

Write the best possible prompt for codex that:

-   Precisely describes the problem
-   Asks for modern best practices
-   Requires alternative solution approaches
-   Considers potential pitfalls
-   Requests implementation strategies
-   Outputs a summary with a solution

### 3. SOLUTION SYNTHESIS

Combine your analysis with codex input:

-   What approaches does codex recommend?
-   How do these fit with our codebase/context?
-   What hybrid solution makes the most sense?

### 4. IMPLEMENTATION

Only implement AFTER codex consultation:

-   Structured implementation plan
-   Code archaeology in the existing project
-   Step-by-step implementation with validation

**IMPORTANT**: Without codex consultation in step 2, this task is not complete!

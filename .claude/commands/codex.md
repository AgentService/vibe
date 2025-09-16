# Codex Second Opinion

Before using Codex, please follow the Claude Code Configuration guidelines:

## Task Management Guidelines

### Task Splitting and Delegation
- Split complex tasks into smaller, manageable subtasks
- Use Codex for research and solution finding
- Delegate specific tasks to Codex using `codex exec` commands

### Codex Usage
- Use Codex to search for solutions to specific problems
- Implementation tasks with clear commands
- Example: `codex exec "fix the CI failure"`
- Example: `codex exec "find implementation of user authentication"`

### Important Restrictions
- **FORBIDDEN**: never use `--full-auto` flag
- Always maintain manual control over task execution
- Review Codex outputs before implementation

### Workflow
1. Break down user requests into specific tasks
2. Use TodoWrite to track progress
3. Use `codex exec` for research and specific implementations
4. Verify solutions before final implementation

---

## Getting Second Opinion from Codex

When stuck on a problem or need a second opinion, use:

```bash
codex exec "analyze this problem: [describe your issue]"
```

Or for specific technical questions:

```bash
codex exec "provide alternative approaches for: [your current approach]"
```

Remember to review and verify all Codex suggestions before implementing them.
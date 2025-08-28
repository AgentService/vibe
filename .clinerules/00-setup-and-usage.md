## Brief overview
- Active rules live in .clinerules/ and are auto-applied; numeric prefixes (00-, 01-) help ordering.
- clinerules-bank/ holds reusable, inactive templates to copy into .clinerules/ as needed.
- Align with existing repo conventions in docs/ directories.

## Rule activation workflow
- Keep only relevant rules in .clinerules/; prune stale sprint/client files.
- Use the Cline Rules popover to toggle specific workspace rules on/off.
- Copy from clinerules-bank/ → .clinerules/ to activate; avoid editing the bank directly.
- Prefer small, single-purpose files (e.g., 01-godot-coding.md, 02-testing.md).

## Godot project context
- Follow docs/ARCHITECTURE_QUICK_REFERENCE.md and docs/ARCHITECTURE_RULES.md.
- Use autoloads (autoload/): EventBus.gd (signals), Logger.gd (logging), GameOrchestrator.gd (flow).
- One script per scene; names match intent; minimal node trees; cohesive components.
- Use Resources (.tres) under data/* for data/balance; avoid hardcoding.
- Place reusable scripts under scripts/*; keep domain/resources/utils separated.

## Documentation requirements
- Update docs/ when modifying architecture/systems.
- Keep README.md and CHANGELOG.md in sync with new capabilities.
- Add feature entries under changelogs/features/ and maintain weekly rollups in changelogs/weekly/.

## Testing standards
- Add isolated tests under tests/ mirroring repo naming (e.g., System_Isolated.tscn/.gd).
- Favor scene-based isolated tests; run via tests/cli_test_runner.gd or run_tests.bat.
- Tests must be fast and deterministic; avoid global state leaks.

## Suggested structure
- Active (.clinerules/):
  - 00-setup-and-usage.md (this file)
  - 01-godot-coding.md (style, naming, scene/script structure)
  - 02-testing.md (layout, naming, execution)
  - 03-architecture.md (boundaries, signals/events, autoload usage)
  - current-sprint.md (temporary sprint guidance)
- Bank (clinerules-bank/):
  - frameworks/godot.md (framework-specific tips)
  - project-types/godot-arena.md (arena/roguelite patterns)
  - clients/example.md (client/context template)

## Workflow tips
- Be clear and outcome-focused; avoid ambiguous directives.
- Activate only what you need per sprint/context; prune regularly.
- Commit rule changes with rationale; treat rules as versioned decisions.

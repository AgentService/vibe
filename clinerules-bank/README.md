## Brief overview
- Repository of reusable but inactive Cline rule templates.
- Copy selected templates into .clinerules/ to activate; keep bank templates pristine.
- Optimized for a Godot project using the root structure and data-driven .tres resources.

## Structure
- frameworks/: Engine- or framework-specific rules (e.g., Godot).
- project-types/: Patterns for common project types (e.g., arena/roguelite).
- clients/: Client/context-specific rule sets (example template included).

## Activation workflow
- Copy needed templates from clinerules-bank/ to .clinerules/.
- Tailor minimally after copying; keep changes small and scoped.
- Use the Cline Rules popover to toggle active .clinerules files on/off.

## Naming and ordering
- Use numeric prefixes in .clinerules/ to control order (00-, 01-, 02-).
- Prefer small, single-purpose files (coding, testing, architecture, sprint).

## Editing policy
- Do not edit templates in clinerules-bank/ directly.
- Propose improvements by adding new templates or revising copies under .clinerules/ with rationale.

## Examples
- Activate Godot framework rules:
  - Copy: clinerules-bank/frameworks/godot.md → .clinerules/04-godot-framework.md
- Activate arena project-type rules:
  - Copy: clinerules-bank/project-types/godot-arena.md → .clinerules/10-project-type-arena.md

## Tips
- Keep the active rule set focused; prune regularly.
- Document non-obvious decisions in CHANGELOG.md or docs/ as appropriate.

# Week 34: Aug 18-24, 2025

**Current Sprint Changelog** - See `/changelogs/` for weekly archives and feature history

## [Current Week - In Progress]

### Added
- **Architecture Boundary Enforcement System**: Automated tools to prevent violations of the layered architecture
  - **Automated validation**: test_architecture_boundaries.gd detects forbidden patterns (get_node() in systems, EventBus in domain, etc.)
  - **Static analysis tool**: check_boundaries_standalone.gd provides detailed dependency graphs and violation reports
  - **Multiple run methods**: Command-line headless execution, Godot Editor integration, batch file for easy access
  - **Dependency matrix**: Visual representation of cross-layer dependencies with violation counts
  - **Real violation detection**: Successfully identified actual architecture violation in XpSystem.gd
  - **Pre-commit hooks**: Automatic architecture validation before each commit with clear error messages
  - **CI integration**: GitHub Actions workflow runs boundary checks on all PRs with automated PR comments
  - **Comprehensive documentation**: ARCHITECTURE_RULES.md with examples, fixes, and debugging guidance
  - **Layer enforcement**: Autoload→Domain, Systems→Domain+Autoload, Scenes→Systems+Autoload, Domain→Pure data
  - **Developer experience**: Clear violation messages with file:line references and suggested fixes
  - **Batch file utility**: check_architecture.bat for one-click analysis execution
  - **Essential documentation**: Quick reference guide and streamlined project README

- **Centralized Logger System**: Structured logging with optional categories and configurable log levels
  - **Log Levels**: DEBUG, INFO, WARN, ERROR, NONE with runtime switching
  - **Optional Categories**: Category-based filtering (balance, combat, waves, player, ui, performance)
  - **Hot-reload Config**: JSON configuration with F5 reload support via BalanceDB integration
  - **F6 Debug Toggle**: Quick DEBUG/INFO level switching during development
  - **Smart Defaults**: Works without config file, categories are optional, sensible fallbacks
  - **Proper Output**: Errors use push_error(), warnings use push_warning(), others use print()
  - **Migration-friendly**: Simple Logger.info() calls, categories only when needed

- **BalanceDB Schema Validation System**: Comprehensive runtime validation for all JSON balance data
  - **Type validation**: Enforces correct data types with JSON float-to-int conversion for whole numbers
  - **Range validation**: Critical gameplay values validated against sensible min/max ranges
  - **Nested structure validation**: Complex objects like arena_center, colors validated recursively  
  - **Required field validation**: Missing critical fields caught at load time, not during gameplay
  - **Hot-reload safety**: F5 reloading validates data before applying changes, with proper error handling
  - **Comprehensive test coverage**: 7 test scenarios covering valid/invalid data, types, ranges, nesting
  - **Developer experience**: Clear error messages with field names and expected vs actual values
  - **Clean logging**: Integrated with Logger system using "balance" category

- **Changelog Management System**: Implemented hybrid approach with weekly archives, feature tracking, and quarterly summaries
  - **Weekly archives**: Previous weeks stored in `/changelogs/weekly/2025-wXX.md` 
  - **Feature tracking**: Major features documented in `/changelogs/features/`
  - **Comprehensive README**: `/changelogs/README.md` with approach documentation and quick reference
  - **Documentation updates**: Updated all MD file references to new changelog structure
  - **FeatureHistory migration**: Consolidated existing FeatureHistory folder into new changelogs structure
  - **File consolidation**: Combined duplicate enemy radar documentation into single comprehensive implementation file

- **Obsidian Documentation System**: Created comprehensive UI system architecture documentation
  - **Systems documentation**: 6 core system docs in `/Obsidian/systems/` with [[linking]]
  - **UI Architecture analysis**: Current vs proposed implementation comparison
  - **Component breakdown**: Detailed scene structure and dependency mapping
  - **Signal flow documentation**: EventBus communication patterns
  - **Modal system analysis**: Current CardPicker implementation and proposed generic system
  - **Integration with workflow**: Added Obsidian update steps to CLAUDE.md and custom commands

- **EventBus Typed Contracts System**: Implemented compile-time payload guarantees for all cross-system signals
  - **Typed payload classes**: 14 payload classes in `/vibe/scripts/domain/signal_payloads/` with compile-time safety
  - **Complete signal migration**: All 12 EventBus signals converted to use typed payload objects instead of loose parameters
  - **Comprehensive validation**: Enhanced `test_signal_contracts.gd` with structure validation for all payload types
  - **Backward compatibility removal**: Clean migration removing old multi-parameter signal patterns
  - **Developer experience**: Clear payload class structure with typed properties and descriptive documentation
  - **IDE support**: Full IntelliSense support with payload property auto-completion
  - **Runtime validation**: Advanced test coverage validating payload object structure and property types
  - **Architecture enforcement**: Payload classes accessed via EventBus preloads to avoid dependency issues

### Changed
- **Logger Migration**: Completed migration of all print statements to centralized Logger system
  - **Main systems**: Arena.gd, Main.gd, CardPicker.gd, CardSystem.gd, TextureThemeSystem.gd, XpSystem.gd migrated
  - **Strategic logging**: Added warning logs for pool exhaustion in AbilitySystem and WaveDirector
  - **Error tracking**: Added failure logging for damage system pool lookups
  - **Category organization**: UI interactions use "ui" category, player events use "player" category
  - **Default DEBUG level**: All systems now use Logger with DEBUG level by default for development
  - **Cleaned debug output**: Removed specific alive projectiles/enemies counter logs from Arena
  - **Abilities category**: Added to log config for projectile and ability system logging

### Fixed
- **Godot Headless Console Output**: Resolved issue preventing console output from appearing in headless test execution
  - **Root cause**: Test scripts extending `Node` instead of `SceneTree` when run with `--script` flag
  - **Script lifecycle fix**: Changed from `_ready()` to `_initialize()` method for proper SceneTree execution
  - **Autoload dependency solution**: Documented scene-based testing (`.tscn`) vs raw script testing patterns
  - **Documentation update**: Added console output patterns and command examples to CLAUDE.md Testing section
  - **Validation patterns**: Clear distinction between simple scripts and tests requiring singleton access

### Technical

---

**Previous Weeks**: [Week 33](/changelogs/weekly/2025-w33.md) | [All Weeks](/changelogs/weekly/) | [Feature History](/changelogs/features/)

**Archive Policy**: This file contains current 2-3 weeks only. Completed weeks archived every Monday to maintain readability.
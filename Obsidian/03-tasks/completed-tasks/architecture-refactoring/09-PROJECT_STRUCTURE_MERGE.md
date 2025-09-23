# PROJECT STRUCTURE MERGE - Remove vibe/ Folder

## Overview
Merge the `vibe/` subfolder into the root directory to eliminate path confusion and simplify the project structure.

## Problem Statement
- Current split structure: Godot game files in `data/`, documentation/configs at root
- Constant path navigation issues when using Claude Code
- Inconsistent executable references (`../Godot` vs `./Godot`)
- Duplicate configuration files and complex directory structure

## Impact Assessment
- **Complexity**: MEDIUM-HIGH (237+ file updates needed)
- **Files affected**: 102 Godot files, 55+ documentation files
- **Risk level**: Medium (large change but straightforward)

## Benefits
✅ Single unified project structure  
✅ Eliminate path confusion in Claude Code  
✅ Consistent executable references  
✅ Better alignment with standard Godot project layout  
✅ Simplified navigation and file discovery  

## Migration Tasks

### Phase 1: Preparation
- [ ] **Backup project completely** (zip or git branch)
- [ ] Verify current project state (all tests passing)
- [ ] Document current directory structure for reference
- [ ] Identify all files with hardcoded `vibe/` references

### Phase 2: File Movement
- [ ] Move all contents from `data/` to root directory
  - [ ] Use `git mv` to preserve file history
  - [ ] Handle file conflicts (merge .gitignore files)
  - [ ] Ensure `project.godot` moves to root
- [ ] Delete empty `data/` folder
- [ ] Verify .godot folder and build artifacts in correct location

### Phase 3: Reference Updates
- [ ] **Documentation Updates** (55+ files)
  - [ ] Update CLAUDE.md references to executable paths
  - [ ] Fix README.md project structure documentation
  - [ ] Update all Obsidian task files with `data/` references
  - [ ] Update changelog entries with path references
  - [ ] Fix architecture documentation paths
- [ ] **Test Script Updates**
  - [ ] Update `run_tests.bat` executable path
  - [ ] Fix all test documentation with command examples
  - [ ] Update batch files and automation scripts
- [ ] **Configuration Updates**
  - [ ] Merge .gitignore files (root + data)
  - [ ] Update any IDE configuration paths
  - [ ] Check custom-commands.md for path references

### Phase 4: Validation
- [ ] **Godot Project Verification**
  - [ ] Open project in Godot Editor (should work from root)
  - [ ] Verify all scenes load correctly
  - [ ] Check that all resources resolve properly
- [ ] **Test Suite Execution**
  - [ ] Run full test suite with new paths
  - [ ] Verify all automated tests pass
  - [ ] Test MCP integration still works
- [ ] **Documentation Review**
  - [ ] Verify all documentation links work
  - [ ] Check that all examples and commands are correct
  - [ ] Validate architecture diagrams still accurate

### Phase 5: Cleanup & Commit
- [ ] Remove any orphaned files or references
- [ ] Update .gitignore with merged rules
- [ ] Stage all changes with `git add`
- [ ] Commit with descriptive message: `refactor: merge data/ into project root`
- [ ] Update README.md with new project structure
- [ ] Document the change in CHANGELOG.md

## Risk Mitigation
- **Backup Strategy**: Full project backup before starting
- **Incremental Testing**: Test after each major phase
- **Git History**: Use `git mv` to preserve file history
- **Rollback Plan**: Keep backup until fully validated

## Files Requiring Updates (Estimated)
- **Godot files**: ~102 files with `res://` paths (actually OK, no changes needed)
- **Documentation**: ~55 markdown files with `data/` references  
- **Scripts**: ~10 batch/test files with executable paths
- **Configuration**: 2-3 config files (.gitignore, etc.)

## Success Criteria
- [ ] Godot project opens correctly from root directory
- [ ] All tests pass with new structure
- [ ] Documentation accurately reflects new structure
- [ ] No broken references or missing files
- [ ] Claude Code navigation works seamlessly
- [ ] Git history preserved for moved files

## Timeline Estimate
- **Preparation**: 30 minutes
- **File Movement**: 15 minutes  
- **Reference Updates**: 1-2 hours
- **Validation**: 30 minutes
- **Total**: ~2.5-3 hours

## Notes
- This is a one-time structural change that will significantly improve development workflow
- Most `res://` paths in Godot files will continue to work unchanged
- Focus on documentation and script updates rather than game logic
- Consider doing this during a development lull to minimize disruption
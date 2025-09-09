# Cleanup Old Damage System Components

Status: Ready to Start
Owner: Solo (Indie)
Priority: Medium
Type: Technical Debt/Cleanup
Dependencies: Zero-Allocation Damage Queue System (completed)
Risk: Low (cleanup of unused code)
Complexity: 3/10

---

## Purpose

Clean up old damage system components and legacy code paths that are no longer needed after the successful implementation of the zero-allocation damage queue system. Remove technical debt and streamline the codebase.

**Context:** The zero-allocation damage queue system (Task 21) has been successfully implemented and is operating perfectly in production with 568 damage events processed at 0.0ms overhead and 100% success rate.

---

## Goals & Acceptance Criteria

- [ ] Remove unused EventBus damage signals and adapters
- [ ] Clean up legacy damage processing pathways
- [ ] Remove obsolete test files and commented code
- [ ] Update documentation to reflect current architecture
- [ ] Verify no breaking changes to existing functionality
- [ ] Maintain backward compatibility where necessary
- [ ] Update ARCHITECTURE.md with current damage flow

---

## Components to Clean Up

### Legacy EventBus Signals (if unused)
- [ ] Review `EventBus.damage_requested` usage (already removed in Task 22)
- [ ] Check for any remaining legacy damage signal patterns
- [ ] Remove backward compatibility adapters if no longer needed

### Old Test Files
- [ ] Review test files for outdated damage testing patterns
- [ ] Consolidate or remove redundant test scenarios
- [ ] Update test documentation

### Documentation Updates
- [ ] Update `docs/ARCHITECTURE_QUICK_REFERENCE.md` with queue internals
- [ ] Update `docs/ARCHITECTURE_RULES.md` to reflect single entry point
- [ ] Remove references to old damage event patterns
- [ ] Add zero-allocation queue documentation

### Code Comments and TODOs
- [ ] Remove TODO comments related to old damage system
- [ ] Update inline documentation for new queue system
- [ ] Clean up debug logging from development phase

---

## Files to Review for Cleanup

### Scripts
- [ ] `scripts/systems/damage_v2/DamageRegistry.gd` - Remove development debug logs
- [ ] `autoload/EventBus.gd` - Review for unused damage signals
- [ ] `scripts/systems/MeleeSystem.gd` - Clean up any legacy damage patterns
- [ ] `scripts/systems/DamageSystem.gd` - Review for obsolete code paths

### Tests
- [ ] `tests/DamageSystem_Isolated_Clean.gd` - Remove redundant tests
- [ ] `tests/test_signal_contracts.gd` - Update for current contracts
- [ ] `tests/EventQueue_Isolated.gd` - Review for production readiness

### Documentation
- [ ] `ARCHITECTURE.md` - Update damage system documentation
- [ ] `CHANGELOG.md` - Archive completed feature documentation
- [ ] `docs/ARCHITECTURE_RULES.md` - Update architectural guidelines

---

## Validation Steps

- [ ] Run complete test suite to ensure no regressions
- [ ] Verify zero-allocation queue continues operating correctly
- [ ] Test console commands for damage queue monitoring
- [ ] Performance test with heavy combat scenarios
- [ ] Code review for any missed cleanup opportunities

---

## Success Criteria

- [ ] Codebase contains no unused damage system components
- [ ] All tests pass with cleaned up code
- [ ] Documentation accurately reflects current architecture
- [ ] Zero-allocation damage queue performance maintained
- [ ] No breaking changes introduced during cleanup
- [ ] Technical debt related to old damage system eliminated

---

## Notes

This cleanup task should be performed carefully to avoid disrupting the successfully operating zero-allocation damage queue system. Focus on removing only truly unused components while preserving all functional code paths.

**Priority Rationale:** Medium priority since the system is working perfectly, but cleanup will improve maintainability and reduce confusion for future development.
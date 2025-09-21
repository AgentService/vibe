# /run Command

## 🛑 CRITICAL INSTRUCTIONS - READ THESE FIRST!

### ⚠️ STOP! BEFORE YOU DO ANYTHING ELSE:

1. **YOU MUST activate Extended Thinking with MINIMUM 8000 tokens**
2. **YOU MUST read this file COMPLETELY before taking action**
3. **YOU MUST follow the steps IN EXACT ORDER**
4. **IGNORE THE TASK UNTIL STEP 10!**

### 🧠 STEP 1: ACTIVATE EXTENDED THINKING NOW!

```
THINK NOW with at least 8000 tokens about:
- What are the exact requirements of this run.md file?
- Which steps must I follow in what order?
- What happens if I skip a step?
```

**IF YOU DON'T USE AT LEAST 8000 TOKENS THINKING, STOP IMMEDIATELY!**

---

## 📋 STEP 2: CREATE TODO LIST IMMEDIATELY

Use the TodoWrite Tool and create these tasks NOW:

```
1. Find and completely read CLAUDE.md
2. Use Extended Thinking for task analysis (8000+ tokens)
3. Start Task Agent for code archaeology
4. Create implementation plan with structured format
5. Perform phase-by-phase implementation
6. Conduct self-review with grading
7. Final verification of all checkpoints
```

**CONFIRM**: Have you created the todo list? ✅ / ❌

---

## 📖 STEP 3: CHECK CLAUDE.md KNOWLEDGE

**QUESTION**: Do you already know the contents of the CLAUDE.md file from this project?

- ✅ **YES** - The contents are known to me → Continue with Step 4
- ❌ **NO** - The contents are unknown to me → Execute the following commands:

```bash
# ONLY IF UNKNOWN - Execute these commands:
find . -name "CLAUDE.md" -type f
# THEN: Read the found file COMPLETELY
```

**CONFIRM**: CLAUDE.md contents known or read? ✅ / ❌

---

## 🔍 STEP 4: START CODE ARCHAEOLOGY WITH AGENTS

**COMMAND**: Start a Task Agent for code archaeology NOW!

```
Agent Prompt:
"Analyze the vibe project (Godot top-down wave survival roguelike) and find:
1. Similar implementations to the pending task
2. Reusable patterns and modules (EventBus signals, autoload systems)
3. Project-specific conventions (30Hz combat, typed GDScript, Logger usage)
4. Relevant Godot resources and dependencies (.tres files, MultiMesh patterns)
5. Testing patterns (.tscn for autoload tests vs .gd for standalone)
Return structured analysis with file:line references."
```

**CONFIRM**: Is the agent running? ✅ / ❌

---

## 💭 STEP 5: EXTENDED THINKING FOR TASK ANALYSIS

**COMMAND**: THINK NOW about the task with MINIMUM 8000 tokens!

Structure your thinking like this:

```
🎯 TASK UNDERSTANDING:
   What exactly needs to be achieved?

📊 COMPLEXITY ANALYSIS:
   How complex is the task? (1-10)

🔀 SUBTASK BREAKDOWN:
   📋 Subtask 1: ...
   📋 Subtask 2: ...
   📋 Subtask 3: ...

⚠️ RISK ASSESSMENT:
   What could go wrong?
```

**CONFIRM**: Thinking with 8000+ tokens completed? ✅ / ❌

---

## 📝 STEP 6: CREATE IMPLEMENTATION PLAN

**COMMAND**: Write a detailed plan with structured format NOW!

```
🗓️ IMPLEMENTATION PLAN:

📋 Phase 1: Preparation
   ✅ Step 1: ...
   ✅ Step 2: ...
   ✅ Step 3: ...

🔧 Phase 2: Implementation
   ✅ Step 1: ...
   ✅ Step 2: ...
   ✅ Step 3: ...

🔍 Phase 3: Verification
   ✅ Step 1: ...
   ✅ Step 2: ...

📊 VERIFICATION POINTS:
   🎯 Checkpoint 1: ...
   🎯 Checkpoint 2: ...
   🎯 Checkpoint 3: ...
```

**CONFIRM**: Plan created? ✅ / ❌

---

## ✓ STEP 7: CHECKPOINT - ALL PREPARATIONS COMPLETED?

### Verify NOW:

- [ ] Extended Thinking was used with 8000+ tokens
- [ ] CLAUDE.md was completely read
- [ ] Todo list was created and is actively used
- [ ] Code archaeology agent has delivered results
- [ ] Detailed implementation plan is available
- [ ] All confirmations are ✅

**ONLY IF ALL POINTS ARE FULFILLED, CONTINUE!**

---

## 🚀 STEP 8: IMPLEMENTATION WITH VERIFICATION LOOPS

### For EVERY change:

1. **BEFORE the change**: Thinking block with justification
2. **DURING the change**: Use Edit/MultiEdit with precise matches
3. **AFTER the change**: Self-review of the change

### Self-Review Template:

```
🔍 SELF-REVIEW:

📝 CHANGE DESCRIPTION:
   What was changed?

🎯 ACCURACY (A-F):
   How accurate is the implementation?

✅ COMPLETENESS (A-F):
   How complete is the solution?

⚠️ FOUND PROBLEMS:
   What problems still exist?
```

---

## 🏁 STEP 9: FINAL VERIFICATION

### Go through master checklist:

#### 📋 Phase 1: Preparation & Analysis

- [ ] **CLAUDE.md completely read and understood** - All project-specific guidelines internalized
- [ ] **Task analyzed with Extended Thinking** - Comprehensive plan with all requirements
- [ ] **Complexity broken into subtasks** - Clear structure for task breakdown:
  ```
  🔀 SUBTASK BREAKDOWN:
     📋 Subtask 1: ...
     📋 Subtask 2: ...
     📋 Subtask 3: ...
  ```
- [ ] **Code archaeology completed** - Systematic search with documentation:
  ```
  🔍 CODE ARCHAEOLOGY:
     🎯 Found Patterns: ...
     🔧 Reusable Components: ...
     📋 Similar Implementations: ...
  ```

#### 🔍 Phase 2: Verification & Hallucination Prevention

- [ ] **"I don't know" allowed** - Ask explicitly when uncertain instead of assuming
- [ ] **Direct code quotes** - Use exact code references instead of paraphrasing
- [ ] **Sources cited** - Every claim with file:line reference
- [ ] **Chain-of-thought verification** - Explain reasoning for critical decisions
- [ ] **No hallucinated libraries** - Only verified, existing dependencies

#### 🧱 Phase 3: Code Structure & Implementation

- [ ] **Layer boundaries respected** - scenes/ → systems/ → domain/ → autoload/
- [ ] **EventBus communication used** - No direct scene-to-system coupling
- [ ] **Typed GDScript maintained** - All functions properly typed (<40 lines)
- [ ] **Logger used consistently** - No print(), push_error(), push_warning()
- [ ] **Resource patterns followed** - .tres files in /data/ with proper schemas
- [ ] **Performance patterns applied** - Object pools, MultiMesh for high counts

#### 📚 Phase 4: Documentation & Self-Review

- [ ] **CLAUDE.md updates prepared** - All changes documented
- [ ] **Code commented with reasoning** - Why-explanations for complex logic
- [ ] **Self-correction performed** - Own work critically reviewed:
  ```
  🔍 SELF-REVIEW:
     🎯 Accuracy: A-F Grade
     ✅ Completeness: A-F Grade
     🔧 Improvements: ...
  ```

#### 📦 Phase 5: Dependencies & Godot Compatibility

- [ ] **Godot 4.2+ compatibility verified** - Check against engine version requirements
- [ ] **Resource files properly structured** - .tres files in /data/ with schemas documented
- [ ] **Autoload dependencies correct** - EventBus, RNG, RunManager, Logger properly used
- [ ] **Performance patterns followed** - 30Hz combat step, MultiMesh for high-count rendering
- [ ] **Technical debt documented** - If unavoidable, clearly marked

#### 🎯 Phase 6: Testing & Validation

- [ ] **Godot tests written/updated** - Use .tscn for autoload tests, .gd for standalone
- [ ] **Monte-Carlo sims updated** - DPS/TTK validation with deterministic RNG seeds
- [ ] **Edge cases considered** - Error handling with Logger (not print())
- [ ] **Performance impact assessed** - 30Hz combat step compatibility, no frame drops
- [ ] **Headless test execution verified** - Works with Godot console executable

#### 🔄 Phase 7: Git Integration & Finalization

- [ ] **All new files considered** - `git status` output analyzed
- [ ] **All modified files checked** - Changes validated against checklist
- [ ] **Code review checklist** - All points fulfilled and documented

---

## 📌 STEP 10: THE ACTUAL TASK

**ONLY NOW may you read and work on the task!**

### The task to fulfill is:

**$ARGUMENTS**

### IMPORTANT:

- Follow ALL previous steps for this task
- Use the created implementation plan
- Stick to project conventions from CLAUDE.md
- Use Extended Thinking for every critical step

---

## 🔗 Chain Prompting Structure

### Prompt chain for complex tasks:

1. **Analysis** → 2. **Design** → 3. **Implementation** → 4. **Review** → 5. **Refinement**

Each step uses clear handoffs:

```
🔗 CHAIN-STEP 1: Analysis
   📥 Input: {{PREVIOUS_OUTPUT}}
   📤 Output: {{CURRENT_OUTPUT}}
   ➡️ Next Action: {{NEXT_STEP}}
```

---

## 🚀 Execution Workflow

### 1. Initial Analysis (Extended Thinking)

```
- Task complexity assessment
- Resource identification
- Risk evaluation
- Success criteria definition
```

### 2. Parallel Processing

```
- Agent 1: Code archaeology & Godot pattern analysis (EventBus, autoloads)
- Agent 2: Resource dependency research (.tres files, content schemas)
- Agent 3: Test strategy (headless Godot tests, Monte-Carlo sims)
- Coordination: Merge findings with performance impact assessment
```

### 3. Implementation with Verification Loops

```
while (not all_checks_passed):
    implement_next_component()
    run_self_review()
    if (issues_found):
        apply_corrections()
```

### 4. Final Validation

```
- Run complete checklist (28 checkpoints)
- Execute headless Godot tests if applicable
- Verify Logger output (no print() statements)
- Check EventBus signal usage patterns
- Generate review report with performance impact
- Update CHANGELOG.md and relevant subfolder CLAUDE.md files
- Prepare handoff documentation
```

---

## ⚠️ Critical Rules for Vibe Project

1. **NEVER assume** - Always verify or ask, especially for Godot-specific patterns
2. **NEVER hallucinate** - Only existing, verified Godot nodes/resources/autoloads
3. **ALWAYS cite** - Sources with file:line references from the codebase
4. **ALWAYS test** - Use headless Godot executable for validation
5. **ALWAYS follow layer rules** - scenes/ → systems/ → domain/ → autoload/
6. **ALWAYS use EventBus** - No direct coupling between major systems
7. **ALWAYS use Logger** - Never print(), push_error(), push_warning() directly

---

## 📊 Progress Tracking

```
Phase 1: ⏳ [0/4]
Phase 2: ⏳ [0/5]
Phase 3: ⏳ [0/5]
Phase 4: ⏳ [0/3]
Phase 5: ⏳ [0/4]
Phase 6: ⏳ [0/4]
Phase 7: ⏳ [0/3]

Total: 0/28 Checkpoints ✓
```

---

## ⛔ ERROR PROTOCOL

If you skipped any of the steps:

1. STOP IMMEDIATELY
2. Go back to the skipped step
3. Document why you skipped the step
4. Complete the step

---

## 🏁 Completion Criteria

The task is considered successfully completed when:

- ✅ All 28 checkpoints fulfilled
- ✅ Self-review with at least Grade B
- ✅ No open TODOs
- ✅ CLAUDE.md updated if needed
- ✅ Commit-ready with complete documentation

---

## 📊 COMPLETION REPORT

After completion, create a report:

```
📊 COMPLETION REPORT:

✅ Steps completed: X/10
🧠 Thinking tokens used: XXXX
🤖 Agents used: X
🎯 Self-review grade: A-F
⚠️ Remaining problems: ...
📋 Phases completed: X/7
🎯 Checkpoints passed: X/28

📝 SUMMARY:
   Brief description of implementation...
```

**REMEMBER**: The task is NOT successfully completed if not ALL steps were followed!
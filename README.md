# Godot Game Project

> PoE-style buildcraft roguelike with mechanics-first approach

## 🚀 Quick Start

### Running the Game
```bash
"./Godot_v4.4.1-stable_win64.exe"
```

### Running Tests
```bash
"./Godot_v4.4.1-stable_win64_console.exe" --headless tests/run_tests.tscn --quit-after 15
```

### Architecture Check
```bash
double-click check_architecture.bat
```

## 🏗️ Architecture

Enforces layered architecture with automated boundary checking:
- **Scenes** (7 files) - UI/Visual
- **Systems** (13 files) - Game Logic  
- **Autoload** (6 files) - Global State
- **Domain** (16 files) - Pure Data

## 📚 Key Documentation

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System design and decisions
- **[CLAUDE.md](CLAUDE.md)** - Development guidelines
- **[Architecture Quick Reference](docs/ARCHITECTURE_QUICK_REFERENCE.md)** - Commands and patterns

## 🔧 Development

### Tools
- **Architecture validation**: `check_architecture.bat`
- **Pre-commit hooks**: Automatic violation prevention
- **CI integration**: GitHub Actions pipeline

### Workflow
1. Run architecture check before changes
2. Follow layer dependency rules
3. Pre-commit hooks prevent violations
4. CI validates all PRs
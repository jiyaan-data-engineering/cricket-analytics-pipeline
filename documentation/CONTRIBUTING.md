# Contributing to Cricket Analytics Pipeline

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## Code of Conduct

- Be respectful and inclusive
- Provide constructive feedback
- Give credit to contributors
- Focus on the code, not the person

## Ways to Contribute

### 1. **Report Bugs**
- Use GitHub Issues
- Describe the issue clearly
- Include steps to reproduce
- Provide expected vs actual behavior

### 2. **Suggest Features**
- Use GitHub Discussions
- Explain the use case
- Describe the expected behavior
- Consider implementation complexity

### 3. **Improve Documentation**
- Fix typos
- Add examples
- Clarify instructions
- Add tutorials

### 4. **Submit Code**
- Fix bugs
- Add features
- Improve performance
- Write tests

### 5. **Review PRs**
- Test the changes
- Provide feedback
- Suggest improvements
- Approve when ready

## Getting Started

### Fork & Clone
```bash
# Fork the repository on GitHub
# Clone your fork
git clone https://github.com/YOUR_USERNAME/cricket-analytics-pipeline.git
cd cricket-analytics-pipeline

# Add upstream remote
git remote add upstream https://github.com/jiyaan-data-engineering/cricket-analytics-pipeline.git
```

### Create a Branch
```bash
# Create feature branch
git checkout -b feature/your-feature-name
# or
git checkout -b fix/your-bug-fix
```

### Make Changes
```bash
# Edit files
# Test your changes
# Commit with clear messages
git add .
git commit -m "Brief description of changes"
```

### Push & Create PR
```bash
# Push to your fork
git push origin feature/your-feature-name

# Create Pull Request on GitHub
# Fill in PR template
# Wait for review
```

## Commit Message Guidelines

### Format
```
<type>(<scope>): <subject>

<body>

<footer>
```

### Type
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Code style (no logic change)
- `refactor`: Code refactoring
- `test`: Tests
- `chore`: Build, dependencies

### Examples
```
feat(dataflow): add schema validation for batting data

fix(bigquery): resolve null value handling in dim_player

docs(readme): improve installation instructions

refactor(pipeline): simplify API response parsing
```

## Code Quality

### Standards
- Follow Python PEP 8
- Use type hints
- Write meaningful comments
- Keep functions small
- DRY principle

### Testing
```bash
# Run tests
python -m pytest tests/

# Check coverage
pytest --cov=src tests/

# Lint
flake8 src/

# Format
black src/
```

### Documentation
- Add docstrings to functions
- Update README if needed
- Add examples for complex code
- Comment non-obvious logic

## Pull Request Process

1. **Update** your branch: `git pull upstream master`
2. **Test** your changes thoroughly
3. **Add tests** for new features
4. **Update** documentation
5. **Push** to your fork
6. **Create PR** with clear description
7. **Respond** to reviewer feedback
8. **Squash commits** if requested

## PR Description Template

```markdown
## Description
Brief description of changes

## Related Issue
Closes #123

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
How to test the changes

## Checklist
- [ ] Code follows style guidelines
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] No new warnings generated
```

## Issue Labels

- `bug` — Something isn't working
- `enhancement` — New feature
- `documentation` — Docs needed
- `good first issue` — For newcomers
- `help wanted` — Need assistance
- `question` — Question/discussion
- `wontfix` — Won't be implemented

## Review Process

### Reviewers Will Check
- Code quality
- Testing coverage
- Documentation
- Performance impact
- Security concerns

### Timeline
- Initial review: 1-2 days
- Revisions: 2-3 days per round
- Final approval: 1 day

## Development Setup

### Install Dependencies
```bash
# Clone repo
git clone https://github.com/jiyaan-data-engineering/cricket-analytics-pipeline.git
cd cricket-analytics-pipeline

# Create virtual environment
python -m venv venv
source venv/bin/activate

# Install requirements
pip install -r requirements.txt
pip install -r requirements-dev.txt
```

### Run Tests
```bash
pytest tests/
```

### Format Code
```bash
black src/
flake8 src/
```

## Project Structure

```
cricket-analytics-pipeline/
├── config/              # Configuration files
├── ingestion/           # Ingestion scripts
├── cloud_function/      # Cloud Function code
├── dataflow/            # Dataflow pipeline
├── bigquery/            # BigQuery SQL & schemas
├── airflow/             # Airflow DAGs
├── terraform/           # Infrastructure code
├── tests/               # Test files
├── docs/                # Documentation
└── README.md            # Project README
```

## Documentation

### Places to Update
- `README.md` — Main documentation
- `ARCHITECTURE.md` — Design docs
- `DEPLOYMENT.md` — Setup guide
- `AIRFLOW.md` — Airflow setup
- Code docstrings

### Writing Style
- Clear and concise
- Use examples
- Add diagrams if helpful
- Include links
- Keep up-to-date

## Recognition

Contributors will be recognized:
- In README.md
- In CHANGELOG.md
- In GitHub releases
- On project website

## Contact

- **Issues**: GitHub Issues
- **Discussions**: GitHub Discussions
- **Email**: contact@jiyaan-institute.com

## License

By contributing, you agree your contributions are licensed under Apache License 2.0.

---

Thank you for contributing! 🎉

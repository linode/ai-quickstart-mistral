<!--
Sync Impact Report:
Version change: 1.0.0 → 1.1.0 (added Code Documentation & Clarity principle)
Modified principles: Added Core Principle VI (Code Documentation & Clarity)
Added sections: Core Principle VI, Development Workflow code documentation requirement
Removed sections: N/A
Templates requiring updates:
  ✅ plan-template.md - Constitution Check section should verify code documentation compliance
  ✅ spec-template.md - No changes needed (generic template)
  ✅ tasks-template.md - No changes needed (generic template)
  ✅ All command files - No agent-specific references found
Follow-up TODOs: Ensure all existing code files include proper headers and comments per new principle
-->

# GPU Instance Quickstart Constitution

## Core Principles

### I. Security-First (NON-NEGOTIABLE)
All deployments MUST include explicit security warnings and guidance. Default configurations MUST assume internet exposure and require firewall protection. Security documentation MUST be prominently displayed (e.g., in `/etc/motd`). Authentication and access control MUST be addressed in deployment documentation, even if not implemented in v1. Rationale: Marketplace Apps are exposed by default; users must understand security implications before deployment.

### II. One-Click Deployment Reliability
Deployment MUST complete successfully within 5 minutes from instance boot to working services. All dependencies (NVIDIA drivers, Docker, services) MUST be automatically installed and configured. Deployment failures MUST provide clear, actionable error messages. Rationale: The core value proposition is speed and simplicity; any manual intervention breaks the "one-click" promise.

### III. Documentation & User Experience
Every feature MUST include clear, step-by-step documentation. User-facing documentation MUST be tested by following it from scratch. Examples and use cases MUST be provided for all primary workflows. Error messages MUST guide users to resolution steps. Rationale: Marketplace Apps serve diverse technical audiences; excellent documentation reduces support burden and increases adoption.

### IV. Testing & Validation
All deployment scripts and configurations MUST be tested on clean instances before release. Integration tests MUST verify end-to-end deployment success. Service health checks MUST be implemented and documented. Breaking changes to deployment process MUST be versioned and migration paths documented. Rationale: Marketplace Apps must work reliably across instance types; untested deployments damage user trust.

### V. Maintainability & Observability
All services MUST be containerized and managed via Docker Compose. Logging MUST be accessible via standard Docker commands. Configuration MUST be externalized (environment variables, config files). Service updates MUST be documented with clear upgrade procedures. Rationale: Containerization ensures consistency and simplifies maintenance; observability enables troubleshooting without SSH access.

### VI. Code Documentation & Clarity (NON-NEGOTIABLE)
All code MUST be clearly commented to explain purpose, logic, and non-obvious decisions. As AI-generated code, developers examining the codebase MUST be able to understand what is happening without reverse-engineering. All files and scripts MUST include header comments documenting:
- **Purpose**: What the file/script does and why it exists
- **Dependencies**: Required packages, tools, services, or external resources
- **Troubleshooting**: Common issues, error handling, or links to troubleshooting documentation
- **Specification Links**: References to relevant spec documents (e.g., `specs/001-ai-sandbox/spec.md`) where applicable
Rationale: AI-generated code requires explicit documentation for maintainability; future developers must understand intent, dependencies, and how to resolve issues without extensive investigation.

## Security Requirements

- Default deployments MUST warn users about internet exposure
- Firewall configuration guidance MUST be provided in documentation
- Security warnings MUST be visible at first login (e.g., `/etc/motd`)
- Authentication requirements MUST be documented, even if deferred to future versions
- Sensitive data (API keys, tokens) MUST NOT be hardcoded in deployment scripts

## Development Workflow

- All changes to deployment scripts MUST be tested on clean instances
- Documentation updates MUST accompany code changes
- Breaking changes to deployment process MUST increment version and include migration guide
- PR reviews MUST verify security warnings are present and accurate
- PR reviews MUST verify code documentation requirements (comments, headers, spec links) are met
- Constitution compliance MUST be verified in plan.md Constitution Check section

## Governance

This constitution supersedes all other development practices. Amendments require:
- Documentation of rationale for change
- Impact assessment on dependent templates and workflows
- Version increment per semantic versioning (MAJOR.MINOR.PATCH)
- Update to this governance section if amendment procedures change

All PRs and reviews MUST verify compliance with constitution principles. Complexity beyond these principles MUST be justified in plan.md Complexity Tracking section. Use `.specify/templates/plan-template.md` for implementation planning and `.specify/templates/spec-template.md` for feature specifications.

**Version**: 1.1.0 | **Ratified**: 2025-11-12 | **Last Amended**: 2025-01-27

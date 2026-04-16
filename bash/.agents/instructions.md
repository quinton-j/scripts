# Instructions

## CloudLink API Guidance

- For tasks involving CloudLink API scripts in `/scripts/bash`, query the target service `_spec` route first (for example: `clAdminOp GET _spec`) and use that response as guidance for supported microservice capabilities, resource shapes, and request patterns before proposing or implementing changes.

## GitHub PR Guidance

- Use clear, action-oriented PR titles.
- Follow the repository PR template when one exists (for example, `.github/pull_request_template.md`).
- Include a Description section with intent, scope, and impact.
- Link the associated Jira issue using the CL key format.
- Summarize key changes as short bullet points.
- Confirm validation status (build/tests) before requesting review.
- Keep PRs focused; avoid unrelated refactors.
- Address review comments with explicit rationale, then resolve threads.
- Update PR checklist items accurately.

## Jira Issue Guidance

- Use concise titles that state the intended outcome.
- Set project to CL and select the correct component.
- Write description with Goal, Scope, and Success Criteria.
- Add related PR links once available.
- Keep acceptance criteria testable and unambiguous.
- Prefer one issue per coherent unit of work.
- Update issue status and details as work evolves.
- Ensure wording reflects remediation intent for security/dependency tasks.

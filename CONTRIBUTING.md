# Contributing

**This repository is read-only.** It's published as a reference for how the maintainer wires up a small Terraform + GitHub Actions infrastructure stack, not as an open-source project soliciting contributions.

- **Issues are disabled.** Bugs in *this repo's IaC* should be reported via the security channel (`SECURITY.md`) only if they have a security impact.
- **Pull requests will not be reviewed or merged.** External interaction is restricted to repo collaborators.
- **Forks are welcome under the [MIT License](LICENSE).** Fork freely if you want to adapt this layout for your own infra; you can credit the original or not — that's what MIT means.

## Security reports

Vulnerabilities are still in scope and should be reported through GitHub's private security advisories — see `SECURITY.md` for the exact process.

## Why read-only

This is personal infrastructure tied to live AWS and Cloudflare state. The cost of accepting drive-by changes (state drift, surprise costs, accidental customer-resource modification) outweighs the upside. The code is here to be read, copied, and learned from — not extended in place.

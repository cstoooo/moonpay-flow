# Security Policy

## Supported version

Security fixes target the latest released minor version on Mooncakes and GitHub `main`.

## Reporting

Do not open a public issue for a vulnerability involving file parsing, malformed XML, denial of service or accidental data exposure. Contact the repository owner privately through the GitHub profile linked from the repository.

Include:

- affected version;
- minimal synthetic input;
- observed behavior;
- expected behavior;
- impact assessment.

## Data handling

The repository contains only synthetic payment messages. Do not submit real customer, bank-account, payment or credential data in issues, pull requests, fixtures or logs.

## Parser boundary

MoonPay Flow is not a complete ISO 20022 XSD validator and must not be used as the sole control for real payment authorization. Validate against the applicable scheme rules and bank implementation guide before production use.

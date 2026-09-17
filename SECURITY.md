# Security Policy

## Reporting a vulnerability

Please report suspected security vulnerabilities privately rather than opening a public issue containing exploit details, credentials or sensitive system information.

When GitHub private vulnerability reporting or Security Advisories are available for this repository, use that channel. Otherwise contact the repository owner privately through an established contact method associated with the project.

A useful report should include:

- affected Terminal version/build;
- macOS version and architecture;
- concise reproduction steps;
- expected and observed behavior;
- security impact;
- relevant logs with credentials, tokens, usernames and private paths removed.

## Scope

Terminal launches normal local shell processes with the privileges of the current macOS user. Commands intentionally entered by the user, and the files or network resources those commands access, are outside the application's vulnerability scope unless Terminal itself changes their behavior in an unsafe or unintended way.

Please do not include real passwords, API keys, private keys, authentication cookies or other secrets in reports.

Security Policy

Supported Versions

The following versions of the Blue-Green Deployment Todo API receive active security updates and patches:

Version

Supported

1.0.x

:white_check_mark:

< 1.0

:x:

Security Architecture Highlights

HTTP Security Headers: Enforced via helmet in Express and hardened security headers in Nginx (X-Frame-Options, X-Content-Type-Options, X-XSS-Protection).

Rate Limiting: API requests are rate-limited (express-rate-limit) to mitigate brute-force and DoS attacks.

Container Hardening: Production Docker images run as the non-root node user on minimal alpine base images.

Network Isolation: MongoDB and internal application containers communicate over an isolated Docker bridge network and private cloud VPC.

Automated Scanning: CodeQL static analysis, Dependabot dependency updates, and container scanning workflows run in GitHub Actions.

Reporting a Vulnerability

Please do not report security vulnerabilities through public GitHub issues.

Use GitHub Private Vulnerability Reporting on this repository to submit a confidential report.

Include a clear description of the issue, steps to reproduce, affected components (src/, nginx/, terraform/, ansible/, or Docker configurations), and potential impact.

You can expect an initial acknowledgment within 48 hours and a remediation plan or status update within 7 business days.

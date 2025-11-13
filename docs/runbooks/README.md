# Operational Runbooks

## Overview

This directory contains step-by-step operational procedures for managing the Todo API application and infrastructure.

## Available Runbooks

### Deployment Operations
- [Blue-Green Deployment](./blue-green-deployment.md) - Standard deployment procedure
- [Rollback Procedure](./rollback.md) - Emergency rollback steps
- [Hotfix Deployment](./hotfix-deployment.md) - Expedited deployment process

### Infrastructure Operations
- [Scaling Operations](./scaling.md) - Scale up/down application
- [Database Maintenance](./database-maintenance.md) - MongoDB operations
- [Load Balancer Management](./load-balancer.md) - LB configuration

### Troubleshooting
- [Application Troubleshooting](./troubleshoot-app.md) - Common application issues
- [Database Troubleshooting](./troubleshoot-db.md) - Database issues
- [Performance Issues](./troubleshoot-performance.md) - Performance debugging

### Monitoring & Alerting
- [Alert Response](./alert-response.md) - How to respond to alerts
- [Log Analysis](./log-analysis.md) - Finding issues in logs
- [Metrics Investigation](./metrics-investigation.md) - Using Prometheus/Grafana

### Security Operations
- [Security Incident Response](./security-incident.md) - Security breach procedures
- [Credential Rotation](./credential-rotation.md) - Rotate secrets and keys
- [Access Management](./access-management.md) - User access procedures

## Runbook Structure

Each runbook follows this format:

1. **Purpose** - What this procedure accomplishes
2. **When to Use** - Situations requiring this procedure
3. **Prerequisites** - Required access, tools, knowledge
4. **Estimated Time** - How long it takes
5. **Steps** - Detailed step-by-step instructions
6. **Verification** - How to confirm success
7. **Rollback** - How to undo if needed
8. **Troubleshooting** - Common issues and solutions

## Quick Reference

### Emergency Contacts
- **On-Call Engineer:** [PagerDuty rotation]
- **DevOps Lead:** [Contact]
- **DBA:** [Contact]
- **Security:** [Contact]

### Critical Commands

```bash
# Health check
curl http://localhost/health

# View logs
docker-compose logs -f app-blue

# Restart service
docker-compose restart app-blue

# Switch environments
./scripts/switch.sh green

# Emergency rollback
git revert HEAD && ./deploy.sh
```

### Common Issues

| Symptom | Likely Cause | Runbook |
|---------|--------------|---------|
| 502 Bad Gateway | App container down | [Troubleshoot App](./troubleshoot-app.md) |
| Slow response times | Database performance | [Troubleshoot Performance](./troubleshoot-performance.md) |
| Memory alerts | Memory leak | [Troubleshoot Performance](./troubleshoot-performance.md) |
| Failed deployment | Build error | [Rollback](./rollback.md) |
| Database connection errors | MongoDB down | [Troubleshoot DB](./troubleshoot-db.md) |

## Best Practices

1. **Always follow the runbook** - Don't skip steps
2. **Document deviations** - Note any changes made
3. **Verify each step** - Check output before proceeding
4. **Communicate status** - Update team via Slack
5. **Learn from incidents** - Update runbooks after issues

## Contributing

To add or update a runbook:

1. Copy the template: `cp template.md new-runbook.md`
2. Fill in all sections
3. Test the procedure
4. Submit for review
5. Update this index

## Revision History

| Date | Runbook | Change | Author |
|------|---------|--------|--------|
| [Date] | All | Initial creation | [Name] |

---

For questions: [DevOps Team Email]

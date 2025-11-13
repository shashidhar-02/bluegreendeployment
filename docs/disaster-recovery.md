# Disaster Recovery Plan (DRP)

## Executive Summary

This Disaster Recovery Plan outlines procedures to ensure business continuity for the Todo API application in the event of system failures, data loss, or catastrophic events.

**Recovery Objectives:**
- **RTO (Recovery Time Objective):** 2 hours
- **RPO (Recovery Point Objective):** 15 minutes

## Table of Contents

1. [Scope and Objectives](#scope-and-objectives)
2. [Emergency Contacts](#emergency-contacts)
3. [Disaster Scenarios](#disaster-scenarios)
4. [Recovery Procedures](#recovery-procedures)
5. [Backup Strategy](#backup-strategy)
6. [Testing Schedule](#testing-schedule)

---

## Scope and Objectives

### Scope
This DRP covers:
- Todo API application (Blue-Green environments)
- MongoDB database
- DigitalOcean infrastructure
- Jenkins CI/CD system
- Load balancer and networking
- Monitoring and logging systems

### Objectives
- Minimize downtime to < 2 hours
- Ensure data loss is < 15 minutes
- Maintain business operations
- Protect against data corruption
- Enable rapid failover

---

## Emergency Contacts

### Primary Response Team

| Role | Name | Phone | Email | Backup |
|------|------|-------|-------|--------|
| **Incident Commander** | [Name] | [Phone] | [Email] | [Backup Name] |
| **DevOps Lead** | [Name] | [Phone] | [Email] | [Backup Name] |
| **Database Admin** | [Name] | [Phone] | [Email] | [Backup Name] |
| **Application Owner** | [Name] | [Phone] | [Email] | [Backup Name] |
| **Security Officer** | [Name] | [Phone] | [Email] | [Backup Name] |

### Vendor Contacts

| Vendor | Support Type | Contact | Account ID |
|--------|-------------|---------|------------|
| **DigitalOcean** | Infrastructure | support@digitalocean.com | [Account ID] |
| **MongoDB Atlas** | Database (if used) | support@mongodb.com | [Account ID] |
| **Slack** | Communication | - | Workspace: [Name] |
| **PagerDuty** | Alerting | support@pagerduty.com | [Account ID] |

### Communication Channels

- **Primary:** Slack #incident-response
- **Secondary:** Conference Bridge: [Number]
- **Escalation:** CEO/CTO direct lines

---

## Disaster Scenarios

### Scenario 1: Application Server Failure

**Impact:** High  
**Likelihood:** Medium  
**Detection:** Prometheus alerts, health check failures

**Indicators:**
- ServiceDown alert fires
- HTTP 502/503 errors
- Health endpoint unreachable

**Response:** See [Application Server Recovery](#application-server-recovery)

---

### Scenario 2: Database Failure/Corruption

**Impact:** Critical  
**Likelihood:** Low  
**Detection:** MongoDB connection errors, data inconsistency

**Indicators:**
- MongoDBDown alert
- Connection timeout errors
- Data integrity check failures

**Response:** See [Database Recovery](#database-recovery)

---

### Scenario 3: Complete Infrastructure Loss

**Impact:** Critical  
**Likelihood:** Very Low  
**Detection:** All services unreachable, DigitalOcean dashboard issues

**Indicators:**
- All health checks fail
- Load balancer unreachable
- SSH connections timeout
- DigitalOcean status page incidents

**Response:** See [Full Infrastructure Recovery](#full-infrastructure-recovery)

---

### Scenario 4: Data Center Outage

**Impact:** Critical  
**Likelihood:** Very Low  
**Detection:** Regional service disruption

**Indicators:**
- DigitalOcean region status: degraded
- Network connectivity loss
- Multiple service failures

**Response:** See [Multi-Region Failover](#multi-region-failover)

---

### Scenario 5: Security Breach

**Impact:** Critical  
**Likelihood:** Low  
**Detection:** Security alerts, unauthorized access

**Indicators:**
- UnauthorizedAccess alert
- Unusual traffic patterns
- Failed authentication attempts spike
- Data exfiltration detected

**Response:** See [Security Incident Response](#security-incident-response)

---

### Scenario 6: Jenkins CI/CD Failure

**Impact:** Medium  
**Likelihood:** Medium  
**Detection:** Pipeline failures, deployment issues

**Indicators:**
- Jenkins unreachable
- Pipeline execution failures
- Build artifacts not generated

**Response:** See [CI/CD Recovery](#cicd-recovery)

---

## Recovery Procedures

### Application Server Recovery

#### Symptoms
- Application container crashes
- High error rates (>5%)
- Memory/CPU exhaustion

#### Steps

**1. Assess Impact (5 minutes)**
```bash
# Check container status
docker ps -a | grep todo-app

# Check logs
docker logs todo-app-blue --tail 100
docker logs todo-app-green --tail 100

# Check resource usage
docker stats --no-stream
```

**2. Immediate Mitigation (10 minutes)**

**Option A: Switch to alternate environment**
```bash
# If blue is failing, switch to green
cd ~/bluegreendeployment
./scripts/switch.sh green

# Verify health
curl http://localhost/health
```

**Option B: Restart application**
```bash
# Restart specific environment
docker-compose restart app-blue

# Wait for health check
sleep 30
curl http://localhost/blue/health
```

**3. Root Cause Analysis (30 minutes)**
```bash
# Examine logs
docker logs todo-app-blue > /tmp/app-failure-$(date +%Y%m%d-%H%M%S).log

# Check system resources
free -h
df -h
top -bn1 | head -20

# Review recent deployments
git log --oneline -10
```

**4. Restore Service (60 minutes)**

**Rollback to previous version:**
```bash
# Identify last working version
docker images | grep todo-app

# Deploy previous version
docker tag todo-app:backup todo-app:blue
docker-compose up -d app-blue

# Update load balancer
./scripts/switch.sh blue
```

**5. Verify Recovery**
```bash
# Run health checks
./tests/health-check.sh

# Monitor metrics
curl http://localhost:9090/api/v1/query?query=up{job="todo-app"}

# Check error rates
curl http://localhost:9090/api/v1/query?query=rate(http_requests_total{status=~"5.."}[5m])
```

**RTO: 1 hour**  
**RPO: 0 (no data loss)**

---

### Database Recovery

#### Symptoms
- MongoDB connection failures
- Data corruption detected
- Replication lag

#### Steps

**1. Assess Database State (10 minutes)**
```bash
# Check MongoDB status
docker exec -it mongodb mongosh --eval "db.serverStatus()"

# Check replication (if applicable)
docker exec -it mongodb mongosh --eval "rs.status()"

# Verify data integrity
docker exec -it mongodb mongosh --eval "db.todos.find().count()"
```

**2. Identify Latest Backup (5 minutes)**
```bash
# List available backups
ls -lh /backups/mongodb/ | tail -10

# Verify backup integrity
sha256sum /backups/mongodb/mongodb-backup-latest.tar.gz
sha256sum -c /backups/mongodb/mongodb-backup-latest.tar.gz.sha256
```

**3. Stop Application (5 minutes)**
```bash
# Prevent write operations
docker-compose stop app-blue app-green

# Verify no connections
docker exec mongodb mongosh --eval "db.currentOp()" | grep -c '"active" : true'
```

**4. Restore Database (30 minutes)**

**Option A: Point-in-time restore**
```bash
# Run restore script
cd /opt/bluegreendeployment
./backup/restore-mongodb.sh

# Select backup timestamp when prompted
# Confirm restoration

# Verify data
docker exec mongodb mongosh --eval "db.todos.find().pretty().limit(5)"
```

**Option B: Manual restore**
```bash
# Extract backup
cd /tmp
tar -xzf /backups/mongodb/mongodb-backup-YYYYMMDD-HHMMSS.tar.gz

# Restore database
docker exec -i mongodb mongorestore \
  --drop \
  --gzip \
  --archive=/tmp/mongodb-backup/dump.gz

# Verify
docker exec mongodb mongosh todos --eval "db.todos.countDocuments()"
```

**5. Restart Application (10 minutes)**
```bash
# Start application containers
docker-compose up -d app-blue app-green

# Warm up cache
for i in {1..10}; do curl -s http://localhost/health > /dev/null; done

# Monitor connections
watch -n 5 'docker exec mongodb mongosh --quiet --eval "db.serverStatus().connections"'
```

**6. Verify Data Integrity (10 minutes)**
```bash
# Run data validation
npm run test:integration

# Check recent records
curl http://localhost/api/todos?limit=10

# Monitor error rates
curl http://localhost:9090/api/v1/query?query=mongodb_up
```

**RTO: 1 hour**  
**RPO: 15 minutes** (based on backup frequency)

---

### Full Infrastructure Recovery

#### Scenario: Complete infrastructure loss (region failure, account compromise, etc.)

#### Prerequisites
- Terraform state backup
- Application code in GitHub
- Database backups in S3 or external storage
- Infrastructure as Code (IaC) repository access

#### Steps

**1. Declare Disaster (15 minutes)**
```bash
# Notify team via Slack
# Activate incident response team
# Document incident start time
# Set up communication channel

# Quick assessment
# - Can we reach DigitalOcean dashboard?
# - Are backups accessible?
# - Is GitHub repository available?
# - Can we access S3/backup storage?
```

**2. Provision New Infrastructure (45 minutes)**

**Option A: Different region in same cloud**
```bash
# Clone repository (if not available)
git clone https://github.com/shashidhar-02/bluegreendeployment.git
cd bluegreendeployment/terraform

# Update region in variables
sed -i 's/nyc3/sfo3/g' variables.tf

# Initialize Terraform with new backend
terraform init -reconfigure

# Review plan
terraform plan -out=disaster-recovery.tfplan

# Apply (with approval)
terraform apply disaster-recovery.tfplan
```

**Option B: Different cloud provider**
```bash
# Use pre-prepared Terraform configurations
cd terraform/aws  # or gcp, azure

# Configure provider credentials
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."

# Deploy infrastructure
terraform init
terraform plan
terraform apply -auto-approve
```

**3. Restore Database (30 minutes)**
```bash
# SSH to new database server
NEW_DB_IP=$(terraform output -raw mongodb_server_ip)
ssh root@$NEW_DB_IP

# Download latest backup from S3
aws s3 cp s3://backups-bucket/mongodb/mongodb-backup-latest.tar.gz /tmp/

# Restore database
tar -xzf /tmp/mongodb-backup-latest.tar.gz
docker exec -i mongodb mongorestore --gzip --archive=/tmp/dump.gz

# Verify
docker exec mongodb mongosh --eval "db.todos.countDocuments()"
```

**4. Deploy Application (20 minutes)**
```bash
# Get new server IPs
export BLUE_SERVER=$(terraform output -raw blue_server_ip)
export GREEN_SERVER=$(terraform output -raw green_server_ip)

# Trigger Jenkins deployment or manual deploy
cd ~/bluegreendeployment

# Update docker-compose with new MongoDB host
sed -i "s/mongodb:27017/$NEW_DB_IP:27017/g" docker-compose.yml

# Deploy to both environments
docker-compose up -d app-blue app-green

# Update load balancer
terraform apply -var="update_loadbalancer=true"
```

**5. Update DNS (10 minutes)**
```bash
# Update DNS records to point to new load balancer
NEW_LB_IP=$(terraform output -raw loadbalancer_ip)

# Update A record (example with DigitalOcean API)
curl -X PUT "https://api.digitalocean.com/v2/domains/yourdomain.com/records/A" \
  -H "Authorization: Bearer $DO_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"data\":\"$NEW_LB_IP\"}"

# Wait for DNS propagation (TTL dependent)
watch -n 10 'dig +short yourdomain.com'
```

**6. Verify Full System (20 minutes)**
```bash
# Run comprehensive health checks
./tests/health-check.sh

# Run integration tests
npm run test:integration

# Run load test (light)
k6 run --vus 10 --duration 2m tests/load/load-test.js

# Monitor all services
curl http://NEW_LB_IP/health
curl http://NEW_LB_IP:9090/targets  # Prometheus
curl http://NEW_LB_IP:3000/d/app-dashboard/  # Grafana
```

**RTO: 2 hours**  
**RPO: 15 minutes**

---

### Multi-Region Failover

#### Prerequisites
- Multi-region deployment configured
- Database replication between regions
- Global load balancer (e.g., Cloudflare, AWS Route 53)

#### Steps

**1. Detect Region Failure (5 minutes)**
```bash
# Check DigitalOcean status
curl https://status.digitalocean.com/api/v2/status.json

# Verify from external monitoring
# Pingdom, UptimeRobot, StatusCake
```

**2. Initiate Failover (10 minutes)**
```bash
# Update global load balancer
# Point traffic to secondary region

# Example: Cloudflare Load Balancer
curl -X PATCH "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/load_balancers/$LB_ID" \
  -H "Authorization: Bearer $CF_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"enabled_pools":["secondary-pool"]}'

# Or Route 53 health check failover (automatic)
# Verify health check status in AWS Console
```

**3. Promote Secondary Database (15 minutes)**
```bash
# SSH to secondary region database
ssh root@db-secondary.region2.com

# If using MongoDB replica set
docker exec mongodb mongosh --eval "rs.stepDown()"

# Verify new primary
docker exec mongodb mongosh --eval "rs.status()" | grep "stateStr"

# Should show: "PRIMARY"
```

**4. Verify Services (10 minutes)**
```bash
# Test from multiple locations
curl -I https://yourdomain.com/health

# Check DNS resolution
dig +short yourdomain.com

# Monitor traffic shift
# Check Cloudflare/Route 53 analytics
```

**5. Communicate Status (Ongoing)**
```bash
# Update status page
# Notify customers via email/SMS
# Post incident updates every 30 minutes
```

**RTO: 30 minutes** (with automated failover)  
**RPO: 0-5 minutes** (depending on replication lag)

---

### Security Incident Response

#### Steps

**1. Contain Threat (Immediate)**
```bash
# Block suspicious IPs
iptables -A INPUT -s SUSPICIOUS_IP -j DROP

# Disable compromised accounts
# Revoke API keys/tokens

# Isolate affected systems
docker-compose stop affected-service
```

**2. Assess Damage (30 minutes)**
```bash
# Check access logs
grep "SUSPICIOUS_IP" /var/log/nginx/access.log

# Review authentication logs
docker logs mongodb | grep -i "authentication"

# Identify data access
docker exec mongodb mongosh --eval "db.system.profile.find({user:'compromised_user'}).pretty()"
```

**3. Eradicate Threat (1 hour)**
```bash
# Rotate all credentials
./security/vault/rotate-all-secrets.sh

# Update firewall rules
terraform apply -var="update_firewall=true"

# Patch vulnerabilities
npm audit fix
docker pull latest-patched-image
```

**4. Recover (2 hours)**
```bash
# Restore from clean backup if needed
./backup/restore-mongodb.sh

# Rebuild compromised containers
docker-compose build --no-cache
docker-compose up -d

# Re-deploy application
git checkout known-good-commit
./deploy.sh
```

**5. Post-Incident (1 week)**
- Conduct forensic analysis
- Update security policies
- Implement additional controls
- Train team on lessons learned

**RTO: 3 hours**  
**RPO: Depends on compromise severity**

---

### CI/CD Recovery

#### Steps

**1. Assess Jenkins Status (10 minutes)**
```bash
# Check Jenkins container
docker ps -a | grep jenkins

# Check logs
docker logs jenkins --tail 100

# Verify disk space
df -h /var/jenkins_home
```

**2. Restore Jenkins (30 minutes)**

**Option A: Restart Jenkins**
```bash
docker-compose restart jenkins

# Wait for startup
sleep 60

# Verify
curl http://jenkins-server:8080/login
```

**Option B: Restore from backup**
```bash
# Stop Jenkins
docker-compose stop jenkins

# Restore Jenkins home
tar -xzf /backups/jenkins/jenkins-home-backup.tar.gz -C /var/jenkins_home

# Restart
docker-compose up -d jenkins

# Wait for initialization
timeout 300 bash -c 'until curl -s http://localhost:8080/login > /dev/null; do sleep 5; done'
```

**3. Manual Deployment (If Jenkins unavailable)**
```bash
# Deploy without pipeline
cd ~/bluegreendeployment

# Build image
docker build -t todo-app:manual-$(date +%s) .

# Deploy to blue
docker-compose stop app-blue
docker tag todo-app:manual-* todo-app:blue
docker-compose up -d app-blue

# Health check
curl http://localhost/blue/health

# Switch traffic if healthy
./scripts/switch.sh blue
```

**4. Resume CI/CD (20 minutes)**
```bash
# Re-run failed pipeline
# Trigger new build via webhook
curl -X POST http://jenkins:8080/job/todo-app/build \
  --user admin:$JENKINS_TOKEN

# Monitor build
curl http://jenkins:8080/job/todo-app/lastBuild/api/json
```

**RTO: 1 hour**  
**RPO: 0** (no data loss for application)

---

## Backup Strategy

### Backup Schedule

| Component | Frequency | Retention | Location | Verified |
|-----------|-----------|-----------|----------|----------|
| **MongoDB** | Every 15 min (incremental) | 30 days | S3 + Local | Daily |
| **MongoDB** | Daily (full) | 90 days | S3 | Weekly |
| **Application Config** | On change | 365 days | Git + S3 | On commit |
| **Jenkins** | Daily | 30 days | S3 | Weekly |
| **Terraform State** | On change | 365 days | S3 versioned | On apply |
| **Logs** | Continuous | 30 days | Elasticsearch | N/A |

### Backup Locations

**Primary:** AWS S3 (us-east-1)
```bash
s3://company-backups-primary/bluegreendeployment/
├── mongodb/
├── jenkins/
├── terraform/
└── configs/
```

**Secondary:** DigitalOcean Spaces (nyc3)
```bash
spaces://backup-space/bluegreendeployment/
```

**Tertiary:** Local NAS (on-premises)
```bash
/mnt/nas/backups/bluegreendeployment/
```

### Backup Verification

**Automated Tests (Daily):**
```bash
#!/bin/bash
# /opt/scripts/verify-backups.sh

# Test MongoDB restore
LATEST_BACKUP=$(ls -t /backups/mongodb/*.tar.gz | head -1)
./backup/restore-mongodb.sh --dry-run --file=$LATEST_BACKUP

# Verify checksum
sha256sum -c $LATEST_BACKUP.sha256

# Test data integrity
docker exec mongodb-test mongosh --eval "db.todos.countDocuments()"

# Report results
if [ $? -eq 0 ]; then
    echo "✅ Backup verification successful"
    curl -X POST $SLACK_WEBHOOK -d '{"text":"Backup verification: PASSED"}'
else
    echo "❌ Backup verification failed"
    curl -X POST $SLACK_WEBHOOK -d '{"text":"Backup verification: FAILED"}'
fi
```

### Recovery Testing

**Monthly Drill:**
1. Restore to isolated environment
2. Verify application functionality
3. Run integration tests
4. Document recovery time
5. Update procedures based on findings

---

## Testing Schedule

### Tabletop Exercises

**Quarterly (2 hours each):**
- Walk through disaster scenarios
- Review contact lists
- Update procedures
- Test communication channels

**Next scheduled:** [Date]

### Technical Drills

**Monthly:**
- Database restore (every month)
- Application deployment (every month)
- Infrastructure provisioning (quarterly)
- Full disaster recovery (semi-annually)

**Drill Schedule:**
| Date | Type | Scenario | Lead | Duration | Status |
|------|------|----------|------|----------|--------|
| [Date] | Database | MongoDB failure | DBA | 1 hour | Scheduled |
| [Date] | Application | Blue-green switch | DevOps | 30 min | Scheduled |
| [Date] | Infrastructure | Region failover | DevOps Lead | 2 hours | Scheduled |
| [Date] | Full DR | Complete recovery | All | 4 hours | Scheduled |

### Test Metrics

Track for each drill:
- Actual RTO vs target
- Actual RPO vs target
- Issues encountered
- Procedure gaps
- Team feedback
- Improvement actions

---

## Maintenance and Updates

### Document Review

**Quarterly:**
- Update contact information
- Review procedures
- Update recovery times
- Incorporate lessons learned

**Document Owner:** DevOps Lead  
**Last Updated:** [Date]  
**Next Review:** [Date]

### Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | [Date] | [Name] | Initial creation |
| 1.1 | [Date] | [Name] | Added security incident response |
| 1.2 | [Date] | [Name] | Updated RTO/RPO based on testing |

---

## Appendix

### A. Pre-Disaster Checklist

- [ ] All backups running successfully
- [ ] Backup verification passing
- [ ] Contact list up to date
- [ ] Terraform state backed up
- [ ] Secrets documented (in Vault)
- [ ] Runbooks accessible offline
- [ ] Monitoring alerts configured
- [ ] Team trained on procedures

### B. Communication Templates

**Initial Incident Notification:**
```
INCIDENT ALERT

Severity: [CRITICAL/HIGH/MEDIUM]
System: [Affected system]
Impact: [User impact description]
Start Time: [Timestamp]
Response Team: Activated
Next Update: [Time]

Status Page: [URL]
```

**Recovery Complete:**
```
INCIDENT RESOLVED

System: [Affected system]
Resolution: [Brief description]
Downtime: [Duration]
Root Cause: [Brief summary]
Detailed RCA: [Due date]

Thank you for your patience.
```

### C. Useful Commands Reference

```bash
# Quick health check
docker ps && curl http://localhost/health

# Check all backups
ls -lh /backups/*/latest*

# View recent logs
docker-compose logs --tail=100 --follow

# Database connection test
docker exec mongodb mongosh --eval "db.serverStatus().ok"

# Terraform state check
terraform show

# Git last good commit
git log --oneline --all --graph -10
```

### D. External Dependencies

| Service | Purpose | Criticality | Failover |
|---------|---------|-------------|----------|
| DigitalOcean | Infrastructure | Critical | AWS standby |
| GitHub | Code repository | High | GitLab mirror |
| Docker Hub | Container registry | High | Private registry |
| Slack | Communication | Medium | Email/Phone |
| PagerDuty | Alerting | High | SMS backup |

---

**END OF DISASTER RECOVERY PLAN**

For questions or updates, contact: [DevOps Team Email]

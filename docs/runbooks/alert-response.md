# Alert Response Runbook

## Purpose

Provide step-by-step procedures for responding to common monitoring alerts from Prometheus/Alertmanager.

## When to Use

- Prometheus alert fires
- PagerDuty notification received
- Slack alert notification
- Grafana dashboard shows anomalies

## Prerequisites

**Access Required:**
- SSH access to servers
- Prometheus/Grafana access
- Log aggregation system (Kibana)
- PagerDuty account

**Tools Required:**
- SSH client
- `curl`, `jq`
- Docker CLI

---

## Alert Severity Levels

| Severity | Response Time | Escalation |
|----------|---------------|------------|
| **Critical** | Immediate (5 min) | Page on-call engineer |
| **Warning** | Within 30 min | Slack notification |
| **Info** | Business hours | Log for review |

---

## Common Alerts

### 1. ServiceDown

**Alert Definition:**
```yaml
alert: ServiceDown
expr: up{job="todo-app"} == 0
for: 1m
severity: critical
```

**Meaning:** Application container is not responding to health checks.

#### Response Procedure (10 minutes)

**Step 1: Acknowledge Alert**
```bash
# Acknowledge in PagerDuty or Slack
# Note time of acknowledgment
```

**Step 2: Verify Issue**
```bash
# Check application status
ssh root@app-server

# Check container status
docker ps -a | grep todo-app

# Check health endpoint
curl http://localhost/health
curl http://localhost/blue/health
curl http://localhost/green/health
```

**Step 3: Quick Diagnosis**
```bash
# Check container logs
docker logs todo-app-blue --tail 100
docker logs todo-app-green --tail 100

# Common patterns to look for:
# - "ECONNREFUSED" - Database connection issue
# - "Out of memory" - Memory limit reached
# - "Cannot bind to port" - Port conflict
# - "Unhandled exception" - Application crash
```

**Step 4: Immediate Mitigation**

**Option A: Restart container**
```bash
# Restart both environments
docker-compose restart app-blue app-green

# Wait for startup
sleep 30

# Verify health
curl http://localhost/health
```

**Option B: Switch to healthy environment**
```bash
# Check which environment is healthy
curl http://localhost/blue/health
curl http://localhost/green/health

# Switch to healthy environment
./scripts/switch.sh blue  # or green

# Verify
curl http://yourdomain.com/health
```

**Option C: Rollback**
```bash
# If recent deployment caused issue
./scripts/rollback.sh

# See Rollback Runbook for details
```

**Step 5: Verify Resolution**
```bash
# Confirm service is up
curl http://yourdomain.com/health

# Check Prometheus
curl http://prometheus:9090/api/v1/query?query='up{job="todo-app"}'

# Monitor for 5 minutes
watch -n 10 'curl -s http://localhost/health | jq'
```

**Step 6: Document & Close**
```bash
# Log incident
echo "$(date) - ServiceDown resolved - Cause: [reason] - Action: [action]" >> /var/log/incidents.log

# Close PagerDuty alert
# Post resolution in Slack
```

---

### 2. HighErrorRate

**Alert Definition:**
```yaml
alert: HighErrorRate
expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
for: 5m
severity: critical
```

**Meaning:** More than 5% of requests are returning 5xx errors.

#### Response Procedure (15 minutes)

**Step 1: Assess Impact**
```bash
# Check error rate
curl -s "http://prometheus:9090/api/v1/query?query=rate(http_requests_total{status=~\"5..\"}[5m])" | jq

# Check affected endpoints
docker logs todo-app-blue --tail 200 | grep "5[0-9][0-9]" | awk '{print $7}' | sort | uniq -c | sort -nr

# Most common endpoints with errors shown
```

**Step 2: Check Recent Changes**
```bash
# Recent deployments
git log --oneline -5

# Recent infrastructure changes
terraform show | head -20

# Check if error started after deployment
# Compare deploy time with error spike in Grafana
```

**Step 3: Identify Root Cause**

**Common causes and checks:**

**A. Database Issues**
```bash
# Check MongoDB connectivity
docker exec mongodb mongosh --eval "db.serverStatus()" > /dev/null
echo $?  # Should be 0

# Check slow queries
docker exec mongodb mongosh --eval "db.currentOp({'secs_running': {\$gte: 5}})"

# Check connection pool
docker exec mongodb mongosh --eval "db.serverStatus().connections"
```

**B. Memory/Resource Issues**
```bash
# Check memory usage
docker stats --no-stream | grep todo-app

# Check disk space
df -h

# Check system load
uptime
```

**C. External Dependencies**
```bash
# Check external API connectivity
curl -w "\nTime: %{time_total}s\n" https://external-api.com/health

# Check DNS resolution
nslookup external-api.com
```

**D. Application Bugs**
```bash
# Check for exceptions in logs
docker logs todo-app-blue --tail 500 | grep -i "error\|exception"

# Check specific error messages
docker logs todo-app-blue | grep "TypeError\|ReferenceError"
```

**Step 4: Implement Fix**

**Immediate fixes:**

**For database issues:**
```bash
# Restart MongoDB connection pool
docker-compose restart app-blue app-green

# Or restart MongoDB if needed
docker-compose restart mongodb
```

**For memory issues:**
```bash
# Increase memory limit in docker-compose.yml
# Then restart
docker-compose up -d app-blue app-green
```

**For application bugs:**
```bash
# Rollback to previous version
./scripts/rollback.sh

# See Rollback Runbook
```

**For external dependencies:**
```bash
# Enable circuit breaker/retry logic
# Or failover to backup service
# Or temporarily disable affected feature
```

**Step 5: Monitor Recovery**
```bash
# Watch error rate decrease
watch -n 10 'curl -s "http://prometheus:9090/api/v1/query?query=rate(http_requests_total{status=~\"5..\"}[5m])" | jq ".data.result[0].value[1]"'

# Should drop below 0.01 (1%)

# Check Grafana dashboard
# Error rate should return to baseline
```

**Step 6: Root Cause Analysis**
```bash
# Save logs for analysis
docker logs todo-app-blue > /tmp/error-analysis-$(date +%Y%m%d-%H%M%S).log

# Create incident report
# Schedule post-mortem if needed
```

---

### 3. HighCPUUsage

**Alert Definition:**
```yaml
alert: HighCPUUsage
expr: rate(process_cpu_seconds_total[5m]) > 0.8
for: 10m
severity: warning
```

**Meaning:** Application using >80% CPU for 10+ minutes.

#### Response Procedure (20 minutes)

**Step 1: Confirm High CPU**
```bash
# Check current CPU usage
docker stats --no-stream | grep todo-app

# Check system CPU
top -bn1 | head -20

# Check CPU history in Grafana
```

**Step 2: Identify CPU Consumers**
```bash
# Get container process tree
docker exec todo-app-blue ps aux

# Check for CPU-intensive queries
docker exec mongodb mongosh --eval "db.currentOp().inprog.filter(op => op.secs_running > 5)"

# Check for high traffic
docker logs nginx --tail 100 | wc -l
```

**Step 3: Analyze Cause**

**A. High Traffic**
```bash
# Check request rate
curl -s "http://prometheus:9090/api/v1/query?query=rate(http_requests_total[5m])" | jq

# If traffic is high but legitimate:
# - Scale horizontally (add more instances)
# - Enable caching
# - Optimize slow endpoints
```

**B. Inefficient Code**
```bash
# Profile application (if profiling enabled)
# Check logs for slow operations
docker logs todo-app-blue | grep "slow query\|taking [0-9][0-9][0-9]ms"

# Identify hot code paths
npm run profile  # if configured
```

**C. Infinite Loop/Deadlock**
```bash
# Check application logs for repeating patterns
docker logs todo-app-blue --tail 1000 | grep -o "Processing.*" | sort | uniq -c | sort -nr

# If same message repeats many times, may indicate loop
```

**Step 4: Implement Fix**

**Immediate mitigation:**
```bash
# Restart container to clear state
docker-compose restart app-blue

# If under attack (DDoS):
# Enable rate limiting in nginx
cat >> /etc/nginx/nginx.conf <<EOF
limit_req_zone \$binary_remote_addr zone=api_limit:10m rate=10r/s;
limit_req zone=api_limit burst=20 nodelay;
EOF
nginx -s reload
```

**Long-term fix:**
```bash
# Optimize slow endpoints
# Add caching layer
# Scale horizontally
# Upgrade server resources
```

**Step 5: Monitor**
```bash
# Watch CPU usage return to normal
watch -n 5 'docker stats --no-stream | grep todo-app'

# Should drop below 50%
```

---

### 4. HighMemoryUsage

**Alert Definition:**
```yaml
alert: HighMemoryUsage
expr: container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.9
for: 5m
severity: warning
```

**Meaning:** Container using >90% of memory limit.

#### Response Procedure (15 minutes)

**Step 1: Check Memory Usage**
```bash
# Container memory
docker stats --no-stream | grep todo-app

# System memory
free -h

# Memory by process
docker exec todo-app-blue ps aux --sort=-rss | head -10
```

**Step 2: Identify Memory Leak**
```bash
# Check if memory is increasing over time
# Compare with Grafana historical data

# Check application for leaks
docker exec todo-app-blue node --expose-gc -e "console.log(process.memoryUsage())"

# Check for large objects in memory
# If heap profiling enabled:
npm run heap-snapshot
```

**Step 3: Immediate Mitigation**
```bash
# Option A: Restart container to free memory
docker-compose restart app-blue

# Option B: Increase memory limit (temporary)
docker update --memory 8g todo-app-blue

# Option C: Scale out (add more instances)
# Distribute load across more containers
```

**Step 4: Long-term Fix**
```bash
# Fix memory leak in code
# Add memory profiling
# Implement proper cleanup
# Add memory monitoring
```

---

### 5. DiskSpaceLow

**Alert Definition:**
```yaml
alert: DiskSpaceLow
expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) < 0.1
for: 5m
severity: warning
```

**Meaning:** Less than 10% disk space available.

#### Response Procedure (15 minutes)

**Step 1: Check Disk Usage**
```bash
# Overall disk usage
df -h

# Find large directories
du -sh /* 2>/dev/null | sort -hr | head -10

# Find large files
find / -type f -size +100M -exec ls -lh {} \; 2>/dev/null | sort -k5 -hr | head -10
```

**Step 2: Identify Space Consumers**
```bash
# Docker images
docker images | awk '{print $7}' | grep -E '[0-9]' | awk '{s+=$1} END {print s "MB"}'

# Docker containers
docker ps -as

# Logs
du -sh /var/log/*
du -sh /var/lib/docker/containers/*/

# Backups
du -sh /backups/*
```

**Step 3: Free Up Space**

```bash
# Remove old Docker images
docker image prune -a --filter "until=24h" -f

# Remove unused containers
docker container prune -f

# Remove unused volumes
docker volume prune -f

# Rotate logs
logrotate -f /etc/logrotate.conf

# Remove old backups (keep last 7 days)
find /backups -type f -mtime +7 -delete

# Clear npm cache
npm cache clean --force

# Clear apt cache (if Ubuntu/Debian)
apt-get clean
```

**Step 4: Verify Space Freed**
```bash
# Check disk usage again
df -h

# Should be back under 70%
```

**Step 5: Prevent Future Issues**
```bash
# Set up automated cleanup
cat > /etc/cron.daily/docker-cleanup <<'EOF'
#!/bin/bash
docker image prune -a --filter "until=48h" -f
docker container prune -f --filter "until=24h"
find /backups -type f -mtime +30 -delete
EOF
chmod +x /etc/cron.daily/docker-cleanup

# Monitor disk usage
# Set up alerts at 80% threshold
```

---

### 6. MongoDBDown

**Alert Definition:**
```yaml
alert: MongoDBDown
expr: mongodb_up == 0
for: 1m
severity: critical
```

**Meaning:** MongoDB is not accessible.

#### Response Procedure (15 minutes)

**Step 1: Check MongoDB Status**
```bash
# Container status
docker ps -a | grep mongodb

# Connection test
docker exec mongodb mongosh --eval "db.serverStatus()" > /dev/null 2>&1
echo $?  # Should be 0 if healthy
```

**Step 2: Diagnose Issue**

**A. Container stopped**
```bash
# Check why it stopped
docker logs mongodb --tail 100

# Common causes:
# - OOM killed
# - Disk full
# - Configuration error
# - Port conflict
```

**B. Connection issues**
```bash
# Check network
docker network inspect app-network | grep mongodb

# Check port binding
netstat -tulpn | grep 27017

# Check firewall
iptables -L -n | grep 27017
```

**C. Database corruption**
```bash
# Check MongoDB logs for corruption messages
docker logs mongodb | grep -i "corrupt\|error"
```

**Step 3: Restart MongoDB**
```bash
# Restart container
docker-compose restart mongodb

# Wait for startup
sleep 10

# Verify
docker exec mongodb mongosh --eval "db.serverStatus().ok"
```

**Step 4: If Restart Fails**

**Option A: Rebuild container**
```bash
# Stop and remove
docker-compose stop mongodb
docker-compose rm -f mongodb

# Start fresh
docker-compose up -d mongodb

# Wait for initialization
sleep 30
```

**Option B: Restore from backup**
```bash
# If database corrupted
./backup/restore-mongodb.sh

# Select most recent backup
# Verify restoration
```

**Step 5: Verify Application Recovery**
```bash
# Test database queries
curl http://localhost/api/todos

# Check application logs
docker logs todo-app-blue --tail 50

# Should see successful database connections
```

---

### 7. SSLCertificateExpiringSoon

**Alert Definition:**
```yaml
alert: SSLCertificateExpiringSoon
expr: (probe_ssl_earliest_cert_expiry - time()) / 86400 < 30
for: 1d
severity: warning
```

**Meaning:** SSL certificate expires in less than 30 days.

#### Response Procedure (30 minutes)

**Step 1: Check Certificate Status**
```bash
# Check expiry date
echo | openssl s_client -servername yourdomain.com -connect yourdomain.com:443 2>/dev/null | openssl x509 -noout -dates

# Check days remaining
echo | openssl s_client -servername yourdomain.com -connect yourdomain.com:443 2>/dev/null | openssl x509 -noout -checkend 2592000
```

**Step 2: Renew Certificate**

**For Let's Encrypt:**
```bash
# Manual renewal
certbot renew --force-renewal

# Verify renewal
certbot certificates
```

**For paid certificate:**
```bash
# Purchase new certificate
# Download certificate files
# Install certificate (see SSL setup docs)
```

**Step 3: Install New Certificate**
```bash
# Update nginx configuration
sudo cp new-cert.pem /etc/ssl/certs/yourdomain.com.pem
sudo cp new-key.pem /etc/ssl/private/yourdomain.com.key

# Test configuration
nginx -t

# Reload nginx
nginx -s reload
```

**Step 4: Verify**
```bash
# Check new expiry date
echo | openssl s_client -servername yourdomain.com -connect yourdomain.com:443 2>/dev/null | openssl x509 -noout -dates

# Test HTTPS
curl -I https://yourdomain.com

# Should return 200 OK
```

---

## Alert Response Checklist

For any alert:

1. **Acknowledge** - Let team know you're handling it
2. **Assess** - Understand severity and impact
3. **Diagnose** - Identify root cause
4. **Mitigate** - Take immediate action to restore service
5. **Monitor** - Verify resolution
6. **Document** - Log incident and actions taken
7. **Prevent** - Implement long-term fix

---

## Escalation Procedures

### When to Escalate

Escalate if:
- Unable to resolve within 30 minutes
- Multiple alerts firing simultaneously
- Data loss or corruption detected
- Security breach suspected
- Need additional permissions/access
- Unsure of proper procedure

### Escalation Path

1. **Level 1:** On-call engineer (immediate)
2. **Level 2:** Senior DevOps engineer (15 minutes)
3. **Level 3:** DevOps Lead (30 minutes)
4. **Level 4:** CTO (1 hour)

### Escalation Contacts

```bash
# Send escalation notification
curl -X POST $PAGERDUTY_WEBHOOK \
  -H "Content-Type: application/json" \
  -d '{
    "routing_key": "'"$ESCALATION_KEY"'",
    "event_action": "trigger",
    "payload": {
      "summary": "Escalation needed - '"$ALERT_NAME"'",
      "severity": "critical",
      "source": "alert-runbook"
    }
  }'
```

---

## Post-Incident Tasks

After resolving any alert:

1. **Document incident**
   ```bash
   # Create incident report
   cat > /var/log/incidents/$(date +%Y%m%d-%H%M%S)-${ALERT_NAME}.md <<EOF
   # Incident Report
   
   **Alert:** ${ALERT_NAME}
   **Time:** $(date)
   **Severity:** ${SEVERITY}
   **Resolved by:** ${USER}
   **Duration:** ${DURATION}
   
   ## Root Cause
   [Description]
   
   ## Resolution
   [Actions taken]
   
   ## Prevention
   [How to prevent in future]
   EOF
   ```

2. **Update runbook** if new information learned

3. **Schedule post-mortem** for critical incidents

4. **Implement prevention measures**

---

## Related Runbooks

- [Troubleshooting Guide](./troubleshoot-app.md)
- [Rollback Procedure](./rollback.md)
- [Database Maintenance](./database-maintenance.md)
- [Disaster Recovery](../disaster-recovery.md)

---

## Document Information

**Owner:** DevOps Team  
**Last Updated:** 2025-01-13  
**Review Cycle:** Monthly  
**Version:** 1.0

For questions: devops@yourdomain.com

# Rollback Runbook

## Purpose

Quickly revert to the previous working version of the application in case of deployment issues or critical bugs.

## When to Use

- New deployment causes errors or crashes
- Performance degradation after deployment
- Critical bugs discovered in production
- Failed health checks after deployment
- Database migration issues
- Security vulnerability introduced

## Prerequisites

**Access Required:**
- SSH access to application servers
- Load balancer configuration access
- Jenkins access (for automated rollback)

**Tools Required:**
- SSH client
- `curl` for health checks
- Docker CLI

## Estimated Time

**Emergency Rollback:** 2-5 minutes  
**Full Rollback with Verification:** 10-15 minutes

---

## Emergency Rollback (Fastest)

Use this when you need to restore service immediately.

### Step 1: Switch to Previous Environment (1 minute)

```bash
# SSH to application server
ssh root@app-server

# Check current active environment
CURRENT=$(curl -s http://localhost/health | jq -r '.version')
echo "Current: $CURRENT"

# Switch to the other environment
if [ "$CURRENT" = "blue" ]; then
  PREVIOUS="green"
else
  PREVIOUS="blue"
fi

# Execute switch
./scripts/switch.sh $PREVIOUS

# Verify
curl http://localhost/health
```

### Step 2: Verify Service Restored (1 minute)

```bash
# Health check
curl https://yourdomain.com/health

# Check error rates in Grafana
# Should return to normal within 1 minute

# Notify team
curl -X POST $SLACK_WEBHOOK \
  -d '{"text":"🔴 ROLLBACK EXECUTED - Service restored to '"$PREVIOUS"' environment"}'
```

**Total Time: 2-3 minutes**

---

## Complete Rollback Procedure

Use this for a thorough rollback with full verification.

### Step 1: Assess Situation (2 minutes)

**1.1 Identify Issues**
```bash
# Check application logs
docker logs todo-app-blue --tail 100 | grep -i error

# Check error rates
curl http://prometheus:9090/api/v1/query?query='rate(http_requests_total{status=~"5.."}[5m])'

# Check alert status
curl http://prometheus:9090/api/v1/alerts | jq '.data.alerts[] | select(.state=="firing")'
```

**1.2 Document Issue**
```bash
# Create incident log
cat > /tmp/rollback-$(date +%Y%m%d-%H%M%S).txt <<EOF
Rollback Initiated: $(date)
Reason: [Brief description]
Current Environment: $CURRENT
Rolling back to: $PREVIOUS
Initiated by: ${USER}
EOF
```

**1.3 Notify Team**
```bash
# Post to Slack incident channel
curl -X POST $SLACK_WEBHOOK \
  -H 'Content-Type: application/json' \
  -d '{
    "text": "🚨 ROLLBACK IN PROGRESS",
    "blocks": [
      {
        "type": "section",
        "text": {
          "type": "mrkdwn",
          "text": "*Rollback Initiated*\n*Reason:* '"${REASON}"'\n*From:* '"${CURRENT}"'\n*To:* '"${PREVIOUS}"'\n*By:* '"${USER}"'"
        }
      }
    ]
  }'
```

### Step 2: Switch Traffic (2 minutes)

**2.1 Update Load Balancer**
```bash
# Switch to previous environment
./scripts/switch.sh $PREVIOUS

# Wait for propagation
sleep 10
```

**2.2 Verify Traffic Switch**
```bash
# Check health endpoint shows old version
curl -s http://yourdomain.com/health | jq -r '.version'
# Should show: green (or blue, depending on rollback)

# Verify response time
curl -w "\nTime: %{time_total}s\n" -o /dev/null -s https://yourdomain.com/health
```

### Step 3: Verify Service Health (3 minutes)

**3.1 Run Health Checks**
```bash
# Test all critical endpoints
for endpoint in /health /api/todos; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://yourdomain.com$endpoint)
  echo "$endpoint: $STATUS"
  if [ "$STATUS" != "200" ]; then
    echo "❌ Failed: $endpoint"
  fi
done
```

**3.2 Test CRUD Operations**
```bash
# Create todo
RESPONSE=$(curl -s -X POST https://yourdomain.com/api/todos \
  -H "Content-Type: application/json" \
  -d '{"title":"Rollback verification","completed":false}')

TODO_ID=$(echo $RESPONSE | jq -r '.data._id')

# Read todo
curl -s https://yourdomain.com/api/todos/$TODO_ID | jq

# Update todo
curl -s -X PUT https://yourdomain.com/api/todos/$TODO_ID \
  -H "Content-Type: application/json" \
  -d '{"completed":true}' | jq

# Delete todo
curl -s -X DELETE https://yourdomain.com/api/todos/$TODO_ID | jq

echo "✅ CRUD operations successful"
```

**3.3 Monitor Metrics**
```bash
# Check error rate (should be < 1%)
curl -s "http://prometheus:9090/api/v1/query?query=rate(http_requests_total{status=~\"5..\"}[5m])" | jq

# Check response time (should be < 500ms p95)
curl -s "http://prometheus:9090/api/v1/query?query=histogram_quantile(0.95,rate(http_request_duration_seconds_bucket[5m]))" | jq

# Monitor for 5 minutes
watch -n 30 'curl -s "http://prometheus:9090/api/v1/query?query=up{job=\"todo-app\"}" | jq ".data.result[].value[1]"'
```

### Step 4: Stop Failed Environment (2 minutes)

**4.1 Stop Problematic Container**
```bash
# Stop the environment that had issues
docker-compose stop app-$CURRENT

# Verify it's stopped
docker ps | grep todo-app
```

**4.2 Preserve Logs**
```bash
# Save logs for analysis
docker logs app-$CURRENT > /var/log/failed-deployment-$(date +%Y%m%d-%H%M%S).log

# Copy to backup location
cp /var/log/failed-deployment-*.log /backups/incident-logs/
```

### Step 5: Post-Rollback Tasks (5 minutes)

**5.1 Update Documentation**
```bash
# Log rollback
cat >> /var/log/rollback.log <<EOF
$(date '+%Y-%m-%d %H:%M:%S') - Rollback Completed
From: $CURRENT
To: $PREVIOUS
Reason: $REASON
Duration: $(( $(date +%s) - $ROLLBACK_START ))s
Performed by: ${USER}
Status: Success
EOF
```

**5.2 Notify Stakeholders**
```bash
# Update status page
# Send notification

curl -X POST $SLACK_WEBHOOK \
  -d '{
    "text": "✅ ROLLBACK COMPLETE",
    "blocks": [
      {
        "type": "section",
        "text": {
          "type": "mrkdwn",
          "text": "*Rollback Successful*\n*Environment:* '"${PREVIOUS}"'\n*Status:* All systems operational\n*Duration:* '"${DURATION}"' seconds"
        }
      }
    ]
  }'
```

**5.3 Schedule Post-Mortem**
```bash
# Create incident ticket
# Schedule team review meeting
# Begin root cause analysis
```

---

## Database Rollback

If database migrations were applied, you may need to rollback the database as well.

### Step 1: Assess Database Changes (5 minutes)

```bash
# Check if migrations were applied
docker exec mongodb mongosh --eval "db.migrations.find().sort({appliedAt:-1}).limit(5).pretty()"

# Identify problematic migration
MIGRATION_ID="20250113_add_new_field"
```

### Step 2: Rollback Migration (10 minutes)

**Option A: Automated rollback (if supported)**
```bash
# Run down migration
npm run migrate:down $MIGRATION_ID

# Verify rollback
docker exec mongodb mongosh --eval "db.migrations.find({migrationId:'$MIGRATION_ID'})"
```

**Option B: Manual rollback**
```bash
# Connect to MongoDB
docker exec -it mongodb mongosh

# Manually undo changes
use todos;
db.todos.updateMany({}, {$unset: {newField: ""}});

# Record rollback
db.migrations.updateOne(
  {migrationId: "20250113_add_new_field"},
  {$set: {rolledBack: true, rolledBackAt: new Date()}}
);

exit;
```

**Option C: Restore from backup**
```bash
# If changes are complex, restore from backup
./backup/restore-mongodb.sh

# Select backup from before deployment
# Confirm restoration
```

### Step 3: Verify Database State (5 minutes)

```bash
# Run database tests
npm run test:database

# Verify data integrity
docker exec mongodb mongosh --eval "
  db.todos.countDocuments();
  db.todos.findOne();
"

# Check application can connect
curl http://localhost/api/todos
```

---

## Code Rollback (If Needed)

If you need to rollback code changes in git:

### Step 1: Identify Problematic Commit

```bash
# View recent commits
git log --oneline -10

# Find the bad commit
BAD_COMMIT="abc123"
GOOD_COMMIT="def456"
```

### Step 2: Revert Changes

**Option A: Git revert (recommended - preserves history)**
```bash
# Revert specific commit
git revert $BAD_COMMIT

# Push revert
git push origin main

# This creates a new commit that undoes the changes
```

**Option B: Git reset (use cautiously - rewrites history)**
```bash
# Reset to previous commit
git reset --hard $GOOD_COMMIT

# Force push (requires admin rights)
git push origin main --force

# ⚠️ WARNING: This rewrites history
```

### Step 3: Redeploy

```bash
# Trigger Jenkins pipeline with reverted code
# Or manual deployment
./deploy.sh
```

---

## Verification Checklist

After rollback, confirm:

- [ ] Application health checks return 200 OK
- [ ] Error rate < 1%
- [ ] Response time p95 < 500ms
- [ ] No firing alerts in Alertmanager
- [ ] Database queries successful
- [ ] All critical endpoints working
- [ ] Logs show no errors
- [ ] Metrics stable for 5+ minutes
- [ ] Customer-facing pages loading correctly
- [ ] Third-party integrations working

---

## Troubleshooting

### Issue: Both Environments Failing

**Symptoms:**
- Rollback doesn't fix the issue
- Both blue and green show errors

**Possible Causes:**
- Database issue
- External dependency failure
- Network problem

**Solution:**
```bash
# Check database
docker exec mongodb mongosh --eval "db.serverStatus()"

# Check external dependencies
curl https://external-api.com/health

# Check network
ping -c 5 8.8.8.8

# Check DNS
nslookup yourdomain.com

# Review recent infrastructure changes
terraform show
```

### Issue: Rollback Doesn't Improve Metrics

**Symptoms:**
- Switched environments but errors persist
- Metrics not improving

**Solution:**
```bash
# Verify traffic actually switched
curl -s http://localhost/health | jq -r '.version'

# Check nginx configuration
nginx -t
cat /etc/nginx/nginx.conf | grep proxy_pass

# Force nginx reload
nginx -s reload

# Clear any caches
redis-cli FLUSHALL  # if using Redis

# Restart load balancer
systemctl restart nginx
```

### Issue: Database in Inconsistent State

**Symptoms:**
- Application errors after rollback
- Data corruption warnings

**Solution:**
```bash
# Immediate: Restore from backup
./backup/restore-mongodb.sh

# Select most recent clean backup
# This may result in some data loss (up to RPO)

# Verify restoration
docker exec mongodb mongosh --eval "db.todos.countDocuments()"

# Restart application
docker-compose restart app-blue app-green
```

### Issue: Users Still Seeing Issues

**Symptoms:**
- Metrics show service is healthy
- Some users report continued problems

**Possible Causes:**
- CDN caching old version
- DNS propagation delay
- Browser caching

**Solution:**
```bash
# Clear CDN cache (if applicable)
# Cloudflare example:
curl -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/purge_cache" \
  -H "Authorization: Bearer $CF_TOKEN" \
  -d '{"purge_everything":true}'

# Check DNS propagation
dig +short yourdomain.com @8.8.8.8
dig +short yourdomain.com @1.1.1.1

# Advise users to:
# 1. Hard refresh browser (Ctrl+Shift+R)
# 2. Clear browser cache
# 3. Try incognito mode
```

---

## Post-Rollback Actions

**Immediate (Within 1 Hour):**
- [ ] Confirm service fully restored
- [ ] Analyze logs from failed deployment
- [ ] Identify root cause
- [ ] Document issues encountered
- [ ] Update incident log

**Within 24 Hours:**
- [ ] Conduct post-mortem meeting
- [ ] Create bug tickets for identified issues
- [ ] Update deployment procedures
- [ ] Fix underlying issues
- [ ] Plan new deployment

**Within 1 Week:**
- [ ] Implement fixes
- [ ] Add tests to prevent recurrence
- [ ] Update runbooks with lessons learned
- [ ] Test fixes in staging
- [ ] Schedule redeployment

---

## Prevention Strategies

To reduce the need for rollbacks:

**1. Staging Environment Testing**
```bash
# Always test in staging first
./deploy.sh staging
# Run full test suite
# Load testing
# Soak test for 24 hours
```

**2. Gradual Rollout**
```bash
# Deploy to small percentage of users first
# Use feature flags
# Monitor closely
# Increase traffic gradually
```

**3. Automated Testing**
```bash
# Pre-deployment checks
npm run test
npm run test:integration
npm run test:e2e

# Post-deployment verification
npm run test:smoke
```

**4. Monitoring and Alerting**
```bash
# Ensure alerts are properly configured
# Monitor key metrics during deployment
# Set up deployment canaries
```

---

## Related Runbooks

- [Blue-Green Deployment](./blue-green-deployment.md)
- [Database Maintenance](./database-maintenance.md)
- [Hotfix Deployment](./hotfix-deployment.md)
- [Disaster Recovery](../disaster-recovery.md)

---

## Document Information

**Owner:** DevOps Team  
**Last Updated:** 2025-01-13  
**Review Cycle:** Quarterly  
**Version:** 1.0

**Emergency Contact:** [On-Call PagerDuty]

For questions: devops@yourdomain.com

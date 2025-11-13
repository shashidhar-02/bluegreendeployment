# Blue-Green Deployment Runbook

## Purpose

Perform a zero-downtime deployment of the Todo API application using blue-green deployment strategy.

## When to Use

- Deploying new application version to production
- Rolling out feature changes
- Applying security patches
- Regular release cycles

## Prerequisites

**Access Required:**
- SSH access to application servers
- Jenkins access (for automated deployment)
- Load balancer configuration access
- GitHub repository access

**Tools Required:**
- SSH client
- `curl` for health checks
- `git` (for manual deployment)
- Docker and Docker Compose

**Knowledge Required:**
- Basic Docker commands
- Understanding of blue-green deployment
- Application health check endpoints

## Estimated Time

**Automated (Jenkins):** 15-20 minutes  
**Manual:** 25-30 minutes

---

## Automated Deployment (Recommended)

### Step 1: Prepare Release (5 minutes)

**1.1 Verify Code Changes**
```bash
# Review changes since last release
git log --oneline origin/main..HEAD

# Check for breaking changes
git diff origin/main..HEAD -- package.json
```

**1.2 Run Pre-Deployment Tests**
```bash
# Run unit tests locally
npm test

# Run integration tests
npm run test:integration

# Check for vulnerabilities
npm audit
```

**1.3 Update Version**
```bash
# Bump version (if using semantic versioning)
npm version patch  # or minor, or major

# Push tags
git push origin main --tags
```

### Step 2: Trigger Jenkins Pipeline (2 minutes)

**2.1 Start Deployment**
```bash
# Option A: Via Jenkins UI
# 1. Navigate to http://jenkins.yourdomain.com:8080
# 2. Click "todo-app-pipeline"
# 3. Click "Build with Parameters"
# 4. Select branch: main
# 5. Click "Build"

# Option B: Via Jenkins API
curl -X POST "http://jenkins.yourdomain.com:8080/job/todo-app-pipeline/buildWithParameters" \
  --user "${JENKINS_USER}:${JENKINS_TOKEN}" \
  --data-urlencode "BRANCH=main" \
  --data-urlencode "ENVIRONMENT=production"
```

**2.2 Monitor Pipeline**
```bash
# Watch build progress
# Jenkins UI: Blue Ocean view shows real-time progress

# Or via CLI
jenkins-cli -s http://jenkins.yourdomain.com:8080 \
  console todo-app-pipeline -f
```

### Step 3: Verify Deployment (5 minutes)

**3.1 Wait for Pipeline Completion**
- Monitor Jenkins pipeline stages
- Ensure all stages pass: Checkout, Test, Build, Deploy, Verify

**3.2 Check Inactive Environment Health**
```bash
# If blue is active, green was just deployed
INACTIVE_ENV="green"  # or blue

# Health check
curl http://app-server/green/health

# Expected response:
# {
#   "status": "ok",
#   "version": "green",
#   "database": "connected",
#   "timestamp": "2025-01-13T10:30:00Z"
# }
```

**3.3 Verify Application Functionality**
```bash
# Test CRUD operations
# Create todo
curl -X POST http://app-server/green/api/todos \
  -H "Content-Type: application/json" \
  -d '{"title":"Test deployment","completed":false}'

# Get todos
curl http://app-server/green/api/todos

# Verify response includes new todo
```

**3.4 Check Logs**
```bash
# SSH to server
ssh root@app-server

# View application logs
docker logs todo-app-green --tail 50

# Look for:
# - No error messages
# - Successful startup messages
# - Database connection established
```

### Step 4: Traffic Switch (3 minutes)

**4.1 Automatic Switch (Jenkins handles this)**
- Jenkins pipeline automatically switches traffic after verification
- Load balancer updated to point to new environment
- Monitor alerts during switch

**4.2 Verify Traffic Switch**
```bash
# Check which environment is active
curl http://yourdomain.com/health

# Response should show new version
# {
#   "status": "ok",
#   "version": "green",  # Changed from blue
#   ...
# }
```

**4.3 Monitor Metrics**
```bash
# Open Grafana dashboard
# http://grafana.yourdomain.com:3000/d/app-dashboard

# Watch for:
# - Request rate remains stable
# - Error rate stays below 1%
# - Response time p95 < 500ms
# - No spike in 5xx errors
```

### Step 5: Post-Deployment Validation (5 minutes)

**5.1 Run Smoke Tests**
```bash
# Run automated smoke tests
npm run test:smoke

# Or manual checks
for endpoint in /health /api/todos; do
  curl -s -o /dev/null -w "%{http_code}" http://yourdomain.com$endpoint
  echo " - $endpoint"
done
```

**5.2 Check Application Logs**
```bash
# Monitor for 5 minutes
docker logs -f todo-app-green

# Look for:
# - Normal request patterns
# - No errors or warnings
# - Successful database queries
```

**5.3 Verify Monitoring**
```bash
# Check Prometheus targets
curl http://prometheus.yourdomain.com:9090/api/v1/targets

# Verify all targets are "up"
# Check alert status
curl http://prometheus.yourdomain.com:9090/api/v1/alerts

# Should show no firing alerts
```

**5.4 Update Deployment Log**
```bash
# Document deployment
cat >> /var/log/deployments.log <<EOF
$(date '+%Y-%m-%d %H:%M:%S') - Deployment Successful
Version: $(git describe --tags)
Environment: green
Duration: 18 minutes
Deployed by: ${USER}
EOF
```

---

## Manual Deployment (Fallback)

### Step 1: Prepare Environment (5 minutes)

**1.1 Identify Target Environment**
```bash
# SSH to application server
ssh root@app-server

# Check current active environment
ACTIVE=$(curl -s http://localhost/health | jq -r '.version')
echo "Active: $ACTIVE"

# Target is the opposite
if [ "$ACTIVE" = "blue" ]; then
  TARGET="green"
else
  TARGET="blue"
fi
echo "Target: $TARGET"
```

**1.2 Navigate to Application Directory**
```bash
cd /opt/bluegreendeployment
```

### Step 2: Deploy Application (10 minutes)

**2.1 Pull Latest Code**
```bash
# Fetch latest changes
git fetch origin

# Checkout specific version/tag
git checkout tags/v1.2.3  # or main for latest
```

**2.2 Build Docker Image**
```bash
# Build new image
docker build -t todo-app:$TARGET .

# Verify build
docker images | grep todo-app
```

**2.3 Update Target Environment**
```bash
# Stop target container
docker-compose stop app-$TARGET

# Remove old container
docker-compose rm -f app-$TARGET

# Start new container
docker-compose up -d app-$TARGET

# Wait for startup
sleep 30
```

### Step 3: Verify Deployment (5 minutes)

**3.1 Health Check**
```bash
# Check health endpoint
curl http://localhost/$TARGET/health

# Verify response
if curl -s http://localhost/$TARGET/health | jq -e '.status == "ok"'; then
  echo "✅ Health check passed"
else
  echo "❌ Health check failed"
  exit 1
fi
```

**3.2 Test Application**
```bash
# Test CRUD operations
# Create
TODO_ID=$(curl -s -X POST http://localhost/$TARGET/api/todos \
  -H "Content-Type: application/json" \
  -d '{"title":"Deployment test","completed":false}' | jq -r '.data._id')

# Read
curl -s http://localhost/$TARGET/api/todos/$TODO_ID | jq

# Update
curl -s -X PUT http://localhost/$TARGET/api/todos/$TODO_ID \
  -H "Content-Type: application/json" \
  -d '{"completed":true}' | jq

# Delete
curl -s -X DELETE http://localhost/$TARGET/api/todos/$TODO_ID | jq

echo "✅ CRUD tests passed"
```

**3.3 Check Logs**
```bash
# View recent logs
docker logs todo-app-$TARGET --tail 100

# Check for errors
if docker logs todo-app-$TARGET --tail 100 | grep -i "error"; then
  echo "⚠️  Errors found in logs"
else
  echo "✅ No errors in logs"
fi
```

### Step 4: Switch Traffic (5 minutes)

**4.1 Update Nginx Configuration**
```bash
# Edit nginx config
nano /etc/nginx/nginx.conf

# Change upstream server from blue to green (or vice versa)
# Before:
#   proxy_pass http://app-blue:3000;
# After:
#   proxy_pass http://app-green:3000;

# Or use switch script
./scripts/switch.sh $TARGET
```

**4.2 Reload Nginx**
```bash
# Test configuration
nginx -t

# If OK, reload
nginx -s reload

# Verify
curl -s http://localhost/health | jq -r '.version'
# Should show: green (or blue if that was target)
```

**4.3 Monitor Traffic**
```bash
# Watch nginx access logs
tail -f /var/log/nginx/access.log

# Watch application logs
docker logs -f todo-app-$TARGET

# Monitor for 5 minutes for any issues
```

### Step 5: Post-Deployment (5 minutes)

**5.1 Verify Public Access**
```bash
# From your local machine (not server)
curl https://yourdomain.com/health

# Should return new version
```

**5.2 Keep Old Environment Running**
```bash
# Leave the old environment (blue/green) running
# This allows quick rollback if needed

# Check both environments
docker ps | grep todo-app

# Both app-blue and app-green should be running
```

**5.3 Update Documentation**
```bash
# Update DEPLOYMENT_LOG.md
cat >> DEPLOYMENT_LOG.md <<EOF

## Deployment $(date '+%Y-%m-%d')
- **Version**: $(git describe --tags)
- **Environment**: $TARGET
- **Time**: $(date '+%H:%M:%S')
- **Method**: Manual
- **Status**: Success
- **Deployed by**: ${USER}

EOF
```

---

## Verification Checklist

After deployment, verify:

- [ ] Health endpoint returns 200 OK
- [ ] Application version matches expected
- [ ] Database connectivity confirmed
- [ ] All API endpoints responding
- [ ] No errors in application logs
- [ ] Prometheus targets show "up"
- [ ] Grafana dashboard shows normal metrics
- [ ] No firing alerts in Alertmanager
- [ ] SSL certificate valid (if applicable)
- [ ] CDN cache cleared (if applicable)

## Rollback Procedure

If issues are detected:

**Immediate Rollback (1 minute):**
```bash
# Switch back to previous environment
PREVIOUS_ENV="blue"  # or green
./scripts/switch.sh $PREVIOUS_ENV

# Verify
curl http://yourdomain.com/health
```

See [Rollback Runbook](./rollback.md) for detailed steps.

---

## Troubleshooting

### Issue: Health Check Fails

**Symptoms:**
- `curl http://localhost/green/health` returns 502 or timeout

**Solution:**
```bash
# Check container status
docker ps -a | grep todo-app-green

# If not running, check logs
docker logs todo-app-green --tail 100

# Common causes:
# 1. Database connection failure
docker exec mongodb mongosh --eval "db.serverStatus()"

# 2. Port conflict
netstat -tulpn | grep 3000

# 3. Missing environment variables
docker exec todo-app-green env | grep -E 'MONGO|NODE'

# Restart if needed
docker-compose restart app-green
```

### Issue: Traffic Not Switching

**Symptoms:**
- Load balancer still points to old environment

**Solution:**
```bash
# Verify nginx configuration
nginx -t

# Check nginx upstream configuration
grep -A 10 "upstream" /etc/nginx/nginx.conf

# Manually reload nginx
nginx -s reload

# Or restart nginx
systemctl restart nginx

# Verify switch
curl -s http://localhost/health | jq -r '.version'
```

### Issue: Database Connection Errors

**Symptoms:**
- Application logs show MongoDB connection errors

**Solution:**
```bash
# Check MongoDB status
docker exec mongodb mongosh --eval "db.serverStatus().ok"

# Verify network connectivity
docker exec todo-app-green ping -c 3 mongodb

# Check connection string
docker exec todo-app-green env | grep MONGO_URL

# Restart application with correct config
docker-compose restart app-green
```

### Issue: High Error Rates After Deployment

**Symptoms:**
- Grafana shows spike in 5xx errors
- Prometheus alerts fire

**Solution:**
```bash
# Immediate rollback
./scripts/switch.sh blue  # or previous environment

# Investigate errors
docker logs todo-app-green | grep -i error

# Check recent code changes
git diff HEAD~1

# Review Sentry/error tracking
# Fix issues and redeploy
```

---

## Post-Deployment Tasks

**Within 1 Hour:**
- [ ] Monitor error rates for anomalies
- [ ] Check database performance
- [ ] Review application logs
- [ ] Verify backup jobs running

**Within 24 Hours:**
- [ ] Remove old Docker images
- [ ] Update deployment documentation
- [ ] Notify stakeholders of successful deployment
- [ ] Schedule old environment cleanup (optional)

**Within 1 Week:**
- [ ] Conduct deployment retrospective
- [ ] Update runbook with any issues encountered
- [ ] Archive deployment artifacts

---

## Related Runbooks

- [Rollback Procedure](./rollback.md)
- [Hotfix Deployment](./hotfix-deployment.md)
- [Troubleshooting Guide](./troubleshoot-app.md)
- [Database Maintenance](./database-maintenance.md)

---

## Document Information

**Owner:** DevOps Team  
**Last Updated:** 2025-01-13  
**Review Cycle:** Quarterly  
**Version:** 1.0

For questions: devops@yourdomain.com

# Architecture Documentation

## System Architecture Overview

This document describes the architecture of the Blue-Green Deployment Todo API system.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Internet / Users                         │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │   Nginx Reverse Proxy  │
                    │   (Port 80, 8080)      │
                    └───────────┬───────────┘
                                │
                ┌───────────────┼───────────────┐
                │               │               │
                ▼               ▼               ▼
        ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
        │   Blue API   │ │  Green API   │ │   Monitors   │
        │  (Port 3001) │ │ (Port 3002)  │ │              │
        └──────┬───────┘ └──────┬───────┘ └──────────────┘
               │                │
               └────────┬───────┘
                        │
                        ▼
                ┌──────────────┐
                │   MongoDB    │
                │  (Port 27017)│
                └──────────────┘
```

## Component Architecture

### 1. Application Layer

#### Node.js API (Express)
- **Technology**: Node.js 18, Express.js
- **Purpose**: RESTful API for todo management
- **Deployment**: Two identical instances (Blue & Green)
- **Features**:
  - CRUD operations for todos
  - Health check endpoints
  - Version identification
  - MongoDB integration via Mongoose

#### Blue Environment
- **Port**: 3001 (host) → 3000 (container)
- **Role**: Current production version
- **Environment Variable**: `APP_VERSION=blue`

#### Green Environment
- **Port**: 3002 (host) → 3000 (container)
- **Role**: Staging/next version
- **Environment Variable**: `APP_VERSION=green`

### 2. Data Layer

#### MongoDB
- **Version**: 7.0
- **Port**: 27017 (internal only)
- **Data Persistence**: Docker volume `mongodb_data`
- **Database**: `todoapp`
- **Shared Resource**: Both Blue and Green connect to same database

### 3. Proxy Layer

#### Nginx
- **Version**: Alpine-based
- **Ports**: 
  - 80: Main application proxy
  - 8080: Control panel & admin
- **Configuration**:
  - Upstream routing with health checks
  - Blue-Green traffic switching
  - Direct environment access (`/blue/`, `/green/`)
  - Static file serving (control panel)

### 4. Monitoring Layer

#### Prometheus
- **Port**: 9090
- **Purpose**: Metrics collection and alerting
- **Targets**:
  - Both API instances
  - Nginx
  - System metrics (node-exporter)
- **Data Retention**: 30 days

#### Grafana
- **Port**: 3003
- **Purpose**: Metrics visualization
- **Features**:
  - Pre-configured Prometheus datasource
  - Custom dashboards
  - Alert visualization

#### Node Exporter
- **Port**: 9100
- **Purpose**: System-level metrics
- **Metrics**: CPU, memory, disk, network

## Data Flow

### Request Flow (Normal Operation)

```
User Request
    ↓
Nginx (Port 80)
    ↓
Route to Active Environment
    ↓
Blue or Green API
    ↓
MongoDB
    ↓
Response back through Nginx
    ↓
User
```

### Blue-Green Deployment Flow

```
1. Current State: Blue is Active
    ↓
2. Deploy new version to Green
    ↓
3. Green starts, passes health checks
    ↓
4. Update Nginx config
    ↓
5. Reload Nginx (zero-downtime)
    ↓
6. Traffic now goes to Green
    ↓
7. Blue remains running (for rollback)
```

## Network Architecture

### Docker Networks
- **Network Name**: `todo-network`
- **Type**: Bridge
- **Subnet**: Auto-assigned by Docker

### Service Communication
```
todo-api-blue ←→ mongodb (internal)
todo-api-green ←→ mongodb (internal)
nginx ←→ todo-api-blue (internal)
nginx ←→ todo-api-green (internal)
prometheus ←→ all services (internal)
grafana ←→ prometheus (internal)
```

### Port Mapping

| Service | Internal Port | External Port | Purpose |
|---------|--------------|---------------|---------|
| nginx | 80 | 80 | Main application |
| nginx | 8080 | 8080 | Control panel |
| todo-api-blue | 3000 | 3001 | Blue environment |
| todo-api-green | 3000 | 3002 | Green environment |
| mongodb | 27017 | - | Database (internal) |
| prometheus | 9090 | 9090 | Metrics |
| grafana | 3000 | 3003 | Dashboards |
| node-exporter | 9100 | 9100 | System metrics |

## Infrastructure Architecture

### Cloud Infrastructure (Terraform)

```
┌──────────────────────────────────────────┐
│          DigitalOcean Cloud              │
│                                          │
│  ┌────────────────────────────────────┐ │
│  │           VPC Network              │ │
│  │        (10.10.0.0/16)              │ │
│  │                                    │ │
│  │  ┌──────────────────────────────┐ │ │
│  │  │        Droplet (VM)          │ │ │
│  │  │    Ubuntu 22.04 LTS          │ │ │
│  │  │    2 vCPU, 4GB RAM           │ │ │
│  │  │                              │ │ │
│  │  │    Docker Engine             │ │ │
│  │  │    Docker Compose            │ │ │
│  │  │    All Services              │ │ │
│  │  └──────────────────────────────┘ │ │
│  └────────────────────────────────────┘ │
│                                          │
│  ┌────────────────────────────────────┐ │
│  │           Firewall                 │ │
│  │   - SSH (22)                       │ │
│  │   - HTTP (80)                      │ │
│  │   - HTTPS (443)                    │ │
│  │   - Monitoring (9090, 3003)        │ │
│  └────────────────────────────────────┘ │
└──────────────────────────────────────────┘
```

### Configuration Management (Ansible)

**Responsibilities**:
1. Install and configure Docker
2. Setup application directories
3. Copy configuration files
4. Manage Docker Compose services
5. Handle deployments

## CI/CD Architecture

### GitHub Actions Pipeline

```
┌─────────────────────────────────────────────────────────┐
│                    GitHub Repository                     │
└────────────────────┬────────────────────────────────────┘
                     │
          ┌──────────┴──────────┐
          │                     │
    [Push Event]          [Pull Request]
          │                     │
          ▼                     ▼
    ┌──────────┐          ┌──────────┐
    │   Test   │          │   Test   │
    └─────┬────┘          └──────────┘
          │
          ▼
    ┌──────────┐
    │  Build   │
    └─────┬────┘
          │
          ▼
    ┌──────────┐
    │   Push   │──────► Docker Hub
    └─────┬────┘
          │
          ▼
    ┌──────────┐
    │  Deploy  │──────► Production Server
    └──────────┘              │
                              ▼
                      Blue-Green Switch
```

## Deployment Strategies

### Strategy 1: Rolling Deployment (Blue-Green)

**Advantages**:
- Zero downtime
- Instant rollback
- Full version testing before switch
- No user impact

**Process**:
1. Deploy to inactive environment
2. Run automated tests
3. Switch traffic
4. Monitor metrics
5. Rollback if needed

### Strategy 2: Canary Deployment (Future Enhancement)

Could be implemented by:
- Route percentage of traffic to Green
- Gradually increase Green traffic
- Monitor error rates
- Full switch or rollback

## Security Architecture

### Network Security
- VPC isolation
- Firewall rules (only necessary ports)
- Internal service communication
- No direct database exposure

### Application Security
- Environment variable management
- Secrets management via GitHub
- Docker image scanning
- Regular dependency updates

### Access Control
- SSH key authentication
- No password-based auth
- Least privilege principle
- Separate staging/production environments

## Scalability Considerations

### Current Limitations
- Single server deployment
- Single MongoDB instance
- Limited to vertical scaling

### Future Enhancements

1. **Horizontal Scaling**
   - Multiple app instances
   - Load balancer distribution
   - Session management

2. **Database Scaling**
   - MongoDB replica set
   - Read replicas
   - Sharding for large datasets

3. **Multi-Region Deployment**
   - Geographic distribution
   - CDN integration
   - Database replication

4. **Container Orchestration**
   - Kubernetes migration
   - Auto-scaling policies
   - Service mesh

## Monitoring Architecture

### Metrics Collection

```
Application Metrics
    ↓
Prometheus (Scrape)
    ↓
Time-Series Storage
    ↓
Grafana (Query)
    ↓
Visualization
```

### Key Metrics

1. **Application Metrics**
   - Request rate
   - Response time
   - Error rate
   - Health status

2. **System Metrics**
   - CPU usage
   - Memory usage
   - Disk I/O
   - Network traffic

3. **Container Metrics**
   - Container status
   - Resource consumption
   - Restart count

## Disaster Recovery

### Backup Strategy
- MongoDB volume backups
- Configuration backups
- Infrastructure as Code (Terraform)

### Recovery Procedures
1. **Application Failure**: Switch to standby environment
2. **Database Failure**: Restore from backup
3. **Server Failure**: Provision new server with Terraform
4. **Complete Failure**: Rebuild from source control

## Technology Stack

### Backend
- **Runtime**: Node.js 18
- **Framework**: Express.js 4.18
- **ODM**: Mongoose 8.0
- **Database**: MongoDB 7.0

### DevOps
- **Containerization**: Docker, Docker Compose
- **IaC**: Terraform
- **Configuration**: Ansible
- **CI/CD**: GitHub Actions
- **Monitoring**: Prometheus, Grafana
- **Proxy**: Nginx

### Cloud
- **Provider**: DigitalOcean (configurable)
- **Compute**: Droplets (VMs)
- **Networking**: VPC, Firewall

## Best Practices Implemented

1. **Infrastructure as Code**: All infrastructure versioned
2. **Immutable Infrastructure**: Containers, not manual changes
3. **Automated Testing**: CI/CD pipeline
4. **Monitoring**: Comprehensive metrics
5. **Documentation**: Extensive docs
6. **Security**: Secrets management, firewall rules
7. **Disaster Recovery**: Backup and recovery procedures
8. **Zero Downtime**: Blue-Green deployment

## Future Improvements

1. **Add HTTPS/SSL**: Let's Encrypt integration
2. **Add Authentication**: JWT-based auth
3. **Add Rate Limiting**: Protect against abuse
4. **Add Caching**: Redis for performance
5. **Add CDN**: Static asset delivery
6. **Add Logging**: ELK stack integration
7. **Add Testing**: Unit, integration, E2E tests
8. **Add APM**: Application performance monitoring
9. **Add Backup Automation**: Scheduled backups
10. **Add Multi-Region**: Geographic redundancy

---

This architecture provides a solid foundation for production deployments with room for growth and enhancement.

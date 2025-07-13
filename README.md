# Core Infrastructure

This Helm chart provides core infrastructure components for the VBMKTek platform.

## Components

### Currently Available
- **PostgreSQL** - Primary relational database
- **MongoDB** - Document database for application data
- **Secrets** - Centralized secret management

### Future Ready
- **Redis** - Caching and session storage
- **Apache Kafka** - Event streaming platform
- **Zookeeper** - Coordination service for Kafka

## Installation

```bash
# Install to core-infra namespace
helm install core-infra . -n core-infra --create-namespace

# Upgrade existing installation
helm upgrade core-infra . -n core-infra
```

## Configuration

### PostgreSQL
```yaml
postgres:
  enabled: true
  persistence:
    enabled: true
    size: 10Gi
  resources:
    requests:
      memory: "512Mi"
      cpu: "250m"
```

### MongoDB  
```yaml
mongodb:
  enabled: true
  persistence:
    enabled: true
    size: 10Gi
  resources:
    requests:
      memory: "512Mi"
      cpu: "250m"
```

### Redis (Future)
```yaml
redis:
  enabled: true  # Set to true to enable
  persistence:
    enabled: true
    size: 5Gi
```

## Access

### NodePort Services
- PostgreSQL: `<node-ip>:30532`
- MongoDB: `<node-ip>:30117`
- Redis: `<node-ip>:30379` (when enabled)

### Internal Services
- PostgreSQL: `postgres:5432`
- MongoDB: `mongodb:27017`
- Redis: `redis:6379` (when enabled)

## Connection Strings

The chart automatically generates connection strings available in secrets:

```yaml
# PostgreSQL
postgresql://postgres:changeme@postgres:5432/postgres

# MongoDB  
mongodb://root:changeme@mongodb:27017/admin?authSource=admin&retryWrites=true

# Redis (when enabled)
redis://:changeme@redis:6379/0
```

## Secrets

All credentials are stored in `core-infra-secrets` secret:
- `postgres-username`, `postgres-password`, `postgres-uri`
- `mongo-username`, `mongo-password`, `mongo-uri`  
- `redis-password`, `redis-uri` (when Redis is enabled)

## Architecture

```
core-infra namespace
├── postgres (deployment + service + pvc)
├── mongodb (deployment + service + pvc)
├── redis (deployment + service + pvc) [future]
├── kafka (deployment + service + pvc) [future]
├── zookeeper (deployment + service + pvc) [future]
└── core-infra-secrets (secret)
```

## Maintenance

### Cleanup Jobs
Auto-cleanup is disabled by default. To enable:

```yaml
postgres:
  cleanup:
    enabled: true
    schedule: "0 2 * * 0"  # Weekly
    retentionDays: 30

mongodb:
  cleanup:
    enabled: true
    schedule: "0 2 * * 0"
    retentionDays: 30
```

## Monitoring

The infrastructure components are ready for monitoring integration with:
- Prometheus metrics collection
- Grafana dashboards
- Health check endpoints

## PVC Migration

This chart supports migrating existing PVCs from another namespace (e.g., `kgnn`) to the `core-infra` namespace.

### Migration Features
- Automatically clones PVC data from source namespace to target namespace
- Preserves all data integrity during migration
- Uses secure pod-to-pod data transfer with tar compression
- Includes RBAC permissions for cross-namespace operations
- Automatic cleanup of temporary resources

### Migration Configuration
```yaml
pvcMigration:
  enabled: true
  sourceNamespace: kgnn
  targetNamespace: core-infra
  
  pvcs:
    - name: postgres-pvc
      size: 10Gi
      sourceClaimName: postgres-pvc
      targetClaimName: postgres-pvc
    - name: mongodb-pvc
      size: 10Gi
      sourceClaimName: mongodb-pvc
      targetClaimName: mongodb-pvc
```

### Migration Commands
```bash
# Install with PVC migration
make install-with-migration

# Upgrade with PVC migration
make upgrade-with-migration

# Test migration functionality
make test-migration

# Check migration job status
make check-migration

# Check source PVCs
make check-source-pvcs

# Check target PVCs
make check-target-pvcs
```

### Migration Process
1. **Pre-flight checks**: Validates source and target namespaces
2. **RBAC setup**: Creates ServiceAccount, ClusterRole, and ClusterRoleBinding
3. **PVC creation**: Creates target PVCs with appropriate sizes
4. **Data migration**: Launches migration job with the following steps:
   - Creates temporary source and target pods
   - Mounts source and target PVCs
   - Transfers data using tar compression
   - Cleans up temporary resources
5. **Verification**: Validates data integrity post-migration

### Migration Job Details
- **Image**: `alpine:latest` with kubectl installed
- **Permissions**: Cross-namespace PVC and Pod management
- **Timeout**: 5 minutes (configurable)
- **Retry**: 3 attempts with exponential backoff
- **Cleanup**: Automatic cleanup of temporary resources

### Troubleshooting Migration
```bash
# Check migration job logs
kubectl logs -n core-infra -l app=pvc-clone

# Check migration job status
kubectl get jobs -n core-infra

# Manual cleanup if needed
kubectl delete job -n core-infra -l app.kubernetes.io/component=pvc-clone
```
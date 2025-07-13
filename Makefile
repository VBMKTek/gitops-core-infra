# Core Infrastructure Makefile
NAMESPACE = core-infra
CHART_NAME = core-infra
RELEASE_NAME = core-infra

.PHONY: help install upgrade uninstall status logs clean test

help:	## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

install:	## Install the chart
	helm install $(RELEASE_NAME) . -n $(NAMESPACE) --create-namespace

upgrade:	## Upgrade the chart
	helm upgrade $(RELEASE_NAME) . -n $(NAMESPACE)

uninstall:	## Uninstall the chart
	helm uninstall $(RELEASE_NAME) -n $(NAMESPACE)

status:		## Show release status
	helm status $(RELEASE_NAME) -n $(NAMESPACE)

logs-postgres:	## Show PostgreSQL logs
	kubectl logs -n $(NAMESPACE) deployment/postgres -f

logs-mongodb:	## Show MongoDB logs
	kubectl logs -n $(NAMESPACE) deployment/mongodb -f

logs-redis:	## Show Redis logs (if enabled)
	kubectl logs -n $(NAMESPACE) deployment/redis -f

clean:		## Clean up all resources
	kubectl delete namespace $(NAMESPACE) --ignore-not-found=true

test:		## Test database connections
	@echo "Testing PostgreSQL connection..."
	kubectl run -n $(NAMESPACE) postgres-test --rm -i --tty --image=postgres:16-alpine -- psql postgresql://postgres:changeme@postgres:5432/postgres -c "SELECT version();"
	@echo "Testing MongoDB connection..."
	kubectl run -n $(NAMESPACE) mongodb-test --rm -i --tty --image=mongo:6-jammy -- mongosh mongodb://root:changeme@mongodb:27017/admin --eval "db.adminCommand('ping')"

backup-postgres:	## Backup PostgreSQL
	kubectl exec -n $(NAMESPACE) deployment/postgres -- pg_dump -U postgres postgres > backup-postgres-$(date +%Y%m%d-%H%M%S).sql

backup-mongodb:		## Backup MongoDB
	kubectl exec -n $(NAMESPACE) deployment/mongodb -- mongodump --uri="mongodb://root:changeme@localhost:27017/admin" --out=/tmp/backup
	kubectl cp $(NAMESPACE)/deployment/mongodb:/tmp/backup ./backup-mongodb-$$(date +%Y%m%d-%H%M%S)

pods:		## Show all pods
	kubectl get pods -n $(NAMESPACE) -o wide

services:	## Show all services
	kubectl get services -n $(NAMESPACE) -o wide

secrets:	## Show secrets (without values)
	kubectl get secrets -n $(NAMESPACE)

events:		## Show recent events
	kubectl get events -n $(NAMESPACE) --sort-by='.lastTimestamp'

describe-postgres:	## Describe PostgreSQL resources
	kubectl describe deployment/postgres -n $(NAMESPACE)
	kubectl describe service/postgres -n $(NAMESPACE)

describe-mongodb:	## Describe MongoDB resources
	kubectl describe deployment/mongodb -n $(NAMESPACE)
	kubectl describe service/mongodb -n $(NAMESPACE)

# Simple Data Migration - Using kubectl exec directly
migrate-data:	## Migrate data from kgnn namespace using kubectl exec
	@echo "Starting simple data migration..."
	@chmod +x scripts/simple-migrate.sh
	@./scripts/simple-migrate.sh

migrate-postgres:	## Migrate only PostgreSQL data
	@echo "Migrating PostgreSQL data..."
	@SOURCE_POD=$$(kubectl get pods -n kgnn -l app=postgres -o jsonpath='{.items[0].metadata.name}') && \
	TARGET_POD=$$(kubectl get pods -n $(NAMESPACE) -l app=postgres -o jsonpath='{.items[0].metadata.name}') && \
	echo "Exporting from $$SOURCE_POD to $$TARGET_POD..." && \
	kubectl exec -n kgnn $$SOURCE_POD -- pg_dumpall -U postgres > /tmp/postgres_backup.sql && \
	kubectl exec -i -n $(NAMESPACE) $$TARGET_POD -- psql -U postgres < /tmp/postgres_backup.sql && \
	rm -f /tmp/postgres_backup.sql && \
	echo "✅ PostgreSQL migration completed"

migrate-mongodb:	## Migrate only MongoDB data
	@echo "Migrating MongoDB data..."
	@SOURCE_POD=$$(kubectl get pods -n kgnn -l app=mongodb -o jsonpath='{.items[0].metadata.name}') && \
	TARGET_POD=$$(kubectl get pods -n $(NAMESPACE) -l app=mongodb -o jsonpath='{.items[0].metadata.name}') && \
	echo "Exporting from $$SOURCE_POD to $$TARGET_POD..." && \
	kubectl exec -n kgnn $$SOURCE_POD -- mongodump --uri="mongodb://root:changeme@localhost:27017" --out=/tmp/mongo_backup --gzip && \
	kubectl cp kgnn/$$SOURCE_POD:/tmp/mongo_backup /tmp/mongo_backup && \
	kubectl cp /tmp/mongo_backup $(NAMESPACE)/$$TARGET_POD:/tmp/mongo_backup && \
	kubectl exec -n $(NAMESPACE) $$TARGET_POD -- mongorestore --uri="mongodb://root:changeme@localhost:27017" /tmp/mongo_backup --gzip --drop && \
	kubectl exec -n kgnn $$SOURCE_POD -- rm -rf /tmp/mongo_backup && \
	kubectl exec -n $(NAMESPACE) $$TARGET_POD -- rm -rf /tmp/mongo_backup && \
	rm -rf /tmp/mongo_backup && \
	echo "✅ MongoDB migration completed"

# Quick deployment with data migration
deploy-and-migrate:	## Deploy chart then migrate data
	@echo "Deploying chart and migrating data..."
	$(MAKE) install
	@sleep 30  # Wait for pods to be ready
	$(MAKE) migrate-data
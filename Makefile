.PHONY: all deploy ui test destroy clean

# Default target: Launch cluster, deploy Kafka, and deploy UI
all:
	@echo "🚀 Launching full stack..."
	./launch.sh
	./deploy-kafka.sh
	./deploy-kafka-ui.sh
	@echo "✅ Stack deployed!"

# Deploy Kafka and Dashboards only
deploy:
	@echo "📦 Deploying Kafka and Dashboards..."
	./deploy-kafka.sh

# Deploy Kafka UI only
ui:
	@echo "🖥️ Deploying Kafka UI..."
	./deploy-kafka-ui.sh

# Run Performance Test
test:
	@echo "🧪 Running Performance Test..."
	./test-kafka-performance.sh

# Port Forwarding
ports:
	@echo "🔌 Starting Port Forwarding..."
	./port-forward.sh

# Port Forwarding
poregistry-clean:
	@echo "🧹 Cleaning up registry..."
	./cleanup-registry.sh

# LitmusChaos Management
chaos-install:
	@echo "⚡ Installing LitmusChaos..."
	./deploy-litmuschaos.sh

chaos-experiments:
	@echo "🧪 Deploying chaos experiments..."
	kubectl apply -f config/litmus-experiments/

chaos-ui:
	@echo "🖥️  Starting LitmusChaos UI..."
	@echo "Access at http://localhost:9091 (admin/litmus)"
	kubectl port-forward svc/chaos-litmus-frontend-service -n litmus 9091:9091

chaos-clean:
	@echo "🧹 Removing LitmusChaos..."
	helm uninstall chaos -n litmus || true
	kubectl delete namespace litmus || true

# Destroy Cluster
destroy:
	@echo "💥 Destroying Cluster..."
	./destroy.sh

# Alias for destroy
clean: destroy

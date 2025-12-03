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

# Registry Management
registry-setup:
	@echo "🐳 Setting up local Docker registry..."
	./setup-registry.sh
	./pull-images.sh

registry-status:
	@echo "📊 Checking registry status..."
	./registry-status.sh

registry-clean:
	@echo "🧹 Cleaning up registry..."
	./cleanup-registry.sh

# Destroy Cluster
destroy:
	@echo "💥 Destroying Cluster..."
	./destroy.sh

# Alias for destroy
clean: destroy

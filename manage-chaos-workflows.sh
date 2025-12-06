#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if argo CLI is installed
check_argo_cli() {
    if ! command -v argo &> /dev/null; then
        echo -e "${RED}Error: Argo CLI not found${NC}"
        echo ""
        echo "The Argo CLI is required to run workflows."
        echo ""
        echo "Install it with:"
        echo -e "  ${GREEN}./install-argo-cli.sh${NC}"
        echo ""
        echo "Or manually:"
        echo "  curl -sLO https://github.com/argoproj/argo-workflows/releases/download/v3.5.5/argo-darwin-arm64.gz"
        echo "  gunzip argo-darwin-arm64.gz"
        echo "  chmod +x argo-darwin-arm64"
        echo "  sudo mv argo-darwin-arm64 /usr/local/bin/argo"
        echo ""
        exit 1
    fi
}

show_help() {
    echo -e "${BLUE}Kafka Chaos Workflow Management${NC}"
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  deploy              Deploy all chaos workflows"
    echo "  run-suite           Run the full chaos test suite"
    echo "  run-load-chaos      Run load testing with chaos"
    echo "  enable-schedule     Enable scheduled daily chaos tests"
    echo "  disable-schedule    Disable scheduled chaos tests"
    echo "  list                List all workflows"
    echo "  status              Show workflow status"
    echo "  logs <workflow>     Show logs for a workflow"
    echo "  delete <workflow>   Delete a specific workflow"
    echo "  clean               Clean up all workflows"
    echo "  help                Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 deploy"
    echo "  $0 run-suite"
    echo "  $0 status"
    echo "  $0 logs kafka-chaos-suite"
    echo ""
}

deploy_workflows() {
    echo -e "${GREEN}Deploying Kafka Chaos Workflows...${NC}"
    
    # Deploy workflow templates
    kubectl apply -f config/litmus-workflows/kafka-chaos-suite.yaml
    kubectl apply -f config/litmus-workflows/kafka-load-chaos.yaml
    kubectl apply -f config/litmus-workflows/kafka-chaos-schedule.yaml
    
    echo ""
    echo -e "${GREEN}✓ Workflows deployed successfully${NC}"
    echo ""
    echo "Available workflows:"
    echo "  - kafka-chaos-suite: Comprehensive chaos testing"
    echo "  - kafka-load-chaos: Load testing with chaos"
    echo "  - kafka-chaos-schedule: Scheduled daily tests"
    echo ""
}

run_chaos_suite() {
    check_argo_cli
    
    echo -e "${GREEN}Running Kafka Chaos Suite...${NC}"
    echo ""
    
    # Submit the workflow
    argo submit config/litmus-workflows/kafka-chaos-suite.yaml \
        --namespace argo \
        --watch
    
    echo ""
    echo -e "${GREEN}✓ Chaos suite execution complete${NC}"
    echo "View results in Argo UI: https://localhost:2746"
}

run_load_chaos() {
    check_argo_cli
    
    echo -e "${GREEN}Running Load Test with Chaos...${NC}"
    echo ""
    
    # Submit the workflow
    argo submit config/litmus-workflows/kafka-load-chaos.yaml \
        --namespace argo \
        --watch
    
    echo ""
    echo -e "${GREEN}✓ Load chaos test complete${NC}"
}

enable_schedule() {
    echo -e "${GREEN}Enabling Scheduled Chaos Tests...${NC}"
    
    kubectl apply -f config/litmus-workflows/kafka-chaos-schedule.yaml
    
    echo ""
    echo -e "${GREEN}✓ Scheduled chaos tests enabled${NC}"
    echo "Schedule: Daily at 2 AM UTC"
    echo ""
    echo "View schedule:"
    echo "  kubectl get cronworkflow kafka-chaos-schedule -n argo"
}

disable_schedule() {
    echo -e "${YELLOW}Disabling Scheduled Chaos Tests...${NC}"
    
    kubectl delete cronworkflow kafka-chaos-schedule -n argo || true
    
    echo ""
    echo -e "${GREEN}✓ Scheduled chaos tests disabled${NC}"
}

list_workflows() {
    echo -e "${BLUE}=== Workflow Templates ===${NC}"
    kubectl get workflowtemplates -n argo 2>/dev/null || echo "No workflow templates found"
    
    echo ""
    echo -e "${BLUE}=== Running/Completed Workflows ===${NC}"
    kubectl get workflows -n argo 2>/dev/null || echo "No workflows found"
    
    echo ""
    echo -e "${BLUE}=== Scheduled Workflows ===${NC}"
    kubectl get cronworkflows -n argo 2>/dev/null || echo "No scheduled workflows found"
}

show_status() {
    echo -e "${BLUE}=== Kafka Chaos Workflow Status ===${NC}"
    echo ""
    
    # Recent workflows
    echo -e "${GREEN}Recent Workflows:${NC}"
    kubectl get workflows -n argo --sort-by=.metadata.creationTimestamp | tail -10
    
    echo ""
    echo -e "${GREEN}Scheduled Workflows:${NC}"
    kubectl get cronworkflows -n argo
    
    echo ""
    echo -e "${GREEN}Kafka Cluster Health:${NC}"
    kubectl get kafka -n kafka
    kubectl get pods -n kafka -l strimzi.io/cluster=krafter | head -5
}

show_logs() {
    check_argo_cli
    
    local workflow=$1
    
    if [ -z "$workflow" ]; then
        echo -e "${RED}Error: Workflow name required${NC}"
        echo "Usage: $0 logs <workflow-name>"
        exit 1
    fi
    
    echo -e "${GREEN}Fetching logs for workflow: $workflow${NC}"
    echo ""
    
    argo logs "$workflow" -n argo --follow
}

delete_workflow() {
    local workflow=$1
    
    if [ -z "$workflow" ]; then
        echo -e "${RED}Error: Workflow name required${NC}"
        echo "Usage: $0 delete <workflow-name>"
        exit 1
    fi
    
    echo -e "${YELLOW}Deleting workflow: $workflow${NC}"
    
    kubectl delete workflow "$workflow" -n argo
    
    echo -e "${GREEN}✓ Workflow deleted${NC}"
}

clean_workflows() {
    echo -e "${YELLOW}Cleaning up all chaos workflows...${NC}"
    
    # Delete all workflows
    kubectl delete workflows --all -n argo || true
    
    # Delete scheduled workflows
    kubectl delete cronworkflows --all -n argo || true
    
    echo ""
    echo -e "${GREEN}✓ All workflows cleaned up${NC}"
}

# Main command dispatcher
case "${1:-help}" in
    deploy)
        deploy_workflows
        ;;
    run-suite)
        run_chaos_suite
        ;;
    run-load-chaos)
        run_load_chaos
        ;;
    enable-schedule)
        enable_schedule
        ;;
    disable-schedule)
        disable_schedule
        ;;
    list)
        list_workflows
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs "$2"
        ;;
    delete)
        delete_workflow "$2"
        ;;
    clean)
        clean_workflows
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac

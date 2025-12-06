# LitmusChaos Portal Setup Guide

## Quick Start

### 1. Access the LitmusChaos Portal

```bash
make chaos-ui
```

Then open http://localhost:9091 in your browser.

**Default Credentials:**
- Username: `admin`
- Password: `litmus`

### 2. Enable Chaos Infrastructure

Once logged in, follow these steps:

#### Step 1: Navigate to Environments
1. Click on **"Environments"** in the left sidebar
2. Click **"+ New Environment"** button

#### Step 2: Create Environment
1. **Name**: `kafka-production` (or your preferred name)
2. **Description**: `Kafka cluster chaos testing environment`
3. **Type**: Select **"Production"** or **"Non-Production"**
4. Click **"Create"**

#### Step 3: Enable Chaos Infrastructure
1. In your new environment, click **"+ Enable Chaos Infrastructure"**
2. Choose **"Self Agent"** (for Kind cluster)
3. **Infrastructure Name**: `kind-panda-cluster`
4. **Description**: `Local Kind cluster for Kafka`
5. **Platform Name**: `Kubernetes`
6. **Installation Mode**: Select **"Cluster Wide"**
7. **Namespace**: `litmus`
8. **Service Account**: `litmus-admin`

#### Step 4: Install Infrastructure
The portal will generate a YAML manifest. You have two options:

**Option A: Copy the YAML and apply manually**
```bash
# Copy the YAML from the portal
kubectl apply -f chaos-infrastructure.yaml
```

**Option B: Use the provided command**
The portal will show a `kubectl apply` command - copy and run it.

#### Step 5: Verify Installation
```bash
# Check chaos infrastructure pods
kubectl get pods -n litmus

# You should see:
# - subscriber-xxxxx
# - chaos-operator-ce-xxxxx  
# - chaos-exporter-xxxxx
```

Wait for all pods to be in `Running` state (usually 1-2 minutes).

#### Step 6: Confirm in Portal
1. Go back to the Environments page
2. Your infrastructure should show as **"Active"** with a green indicator
3. You should see cluster details like:
   - Number of nodes
   - Kubernetes version
   - Infrastructure status

### 3. Run Your First Chaos Experiment

#### Using the Portal UI:

1. **Navigate to Chaos Experiments**
   - Click **"Chaos Experiments"** in the left sidebar
   - Click **"+ New Experiment"**

2. **Configure Experiment**
   - **Name**: `kafka-pod-delete-test`
   - **Infrastructure**: Select your `kind-panda-cluster`
   - **Experiment Type**: Choose from templates or create custom

3. **Select Chaos Fault**
   - Search for **"pod-delete"**
   - Click on it to add to your experiment
   - Configure target:
     - **Namespace**: `kafka`
     - **Label**: `strimzi.io/cluster=krafter`
     - **Chaos Duration**: `60` seconds

4. **Schedule**
   - **Run Now** or **Schedule for later**
   - Click **"Save and Run"**

5. **Monitor**
   - Watch the experiment progress in real-time
   - View logs and metrics
   - Check resilience score

#### Using Argo Workflows (Recommended):

```bash
# Run comprehensive chaos suite
make chaos-workflows-run

# Run load testing with chaos
make chaos-workflows-load

# Enable scheduled chaos tests
make chaos-workflows-schedule

# Check workflow status
make chaos-workflows-status
```

## Troubleshooting

### Infrastructure Not Connecting

**Check pod status:**
```bash
kubectl get pods -n litmus
kubectl describe pod <subscriber-pod-name> -n litmus
```

**Check logs:**
```bash
kubectl logs -n litmus -l app=subscriber
kubectl logs -n litmus -l app=chaos-operator
```

**Common issues:**
- **ImagePullBackOff**: Images not loaded in Kind
  ```bash
  ./pull-images.sh  # Pull all images
  ```
- **CrashLoopBackOff**: Check logs for specific error
- **Pending**: Check resource availability

### Experiments Not Running

**Verify CRDs are installed:**
```bash
kubectl get crd | grep chaos
```

You should see:
- `chaosengines.litmuschaos.io`
- `chaosexperiments.litmuschaos.io`
- `chaosresults.litmuschaos.io`

**Check RBAC:**
```bash
kubectl get sa litmus-admin -n litmus
kubectl get clusterrole litmus-admin
kubectl get clusterrolebinding litmus-admin
```

### Portal Not Accessible

**Check port-forward:**
```bash
# Kill existing port-forwards
pkill -f "port-forward.*litmus"

# Restart
make chaos-ui
```

**Check portal pods:**
```bash
kubectl get pods -n litmus | grep litmus
```

All portal pods should be `Running`:
- `chaos-litmus-frontend-xxxxx`
- `chaos-litmus-server-xxxxx`
- `chaos-litmus-auth-server-xxxxx`

## Advanced Configuration

### Custom Infrastructure Settings

Edit the infrastructure deployment after installation:

```bash
# Edit subscriber
kubectl edit deployment subscriber -n litmus

# Edit chaos operator
kubectl edit deployment chaos-operator-ce -n litmus
```

### Multiple Environments

You can create multiple environments for different testing scenarios:
- **Development**: Low-impact tests, frequent runs
- **Staging**: Medium-impact tests, scheduled runs
- **Production**: High-impact tests, manual approval required

### Integration with CI/CD

Export chaos experiment as YAML:
1. Go to your experiment in the portal
2. Click **"Export"**
3. Save the YAML
4. Use in your CI/CD pipeline:

```yaml
# .github/workflows/chaos-test.yml
- name: Run Chaos Test
  run: |
    kubectl apply -f chaos-experiment.yaml
    kubectl wait --for=condition=complete --timeout=600s chaosengine/my-experiment -n kafka
```

## Monitoring and Observability

### Grafana Dashboards

Access Grafana at http://localhost:30080

**Key Dashboards:**
- **Kafka Cluster**: Overall cluster health
- **LitmusChaos**: Experiment results and metrics
- **Kubernetes Cluster**: Node and pod metrics

### Prometheus Metrics

Chaos exporter exposes metrics at:
```
http://chaos-exporter.litmus.svc:8080/metrics
```

**Key metrics:**
- `litmuschaos_awaited_experiments`
- `litmuschaos_passed_experiments`
- `litmuschaos_failed_experiments`
- `litmuschaos_experiment_verdict`

### Argo Workflows UI

Access Argo at https://localhost:2746

View:
- Workflow execution DAG
- Step-by-step logs
- Artifacts and results
- Historical runs

## Best Practices

### 1. Start Small
Begin with low-impact experiments:
- Pod delete (single pod)
- Container restart
- Network delay (low percentage)

### 2. Progressive Testing
Gradually increase chaos intensity:
1. **Week 1**: Pod-level chaos
2. **Week 2**: Network chaos
3. **Week 3**: Resource chaos
4. **Week 4**: Node-level chaos

### 3. Monitor Everything
Always have monitoring active:
- Grafana dashboards open
- Argo workflow UI visible
- Application logs streaming

### 4. Document Results
After each experiment:
- Record recovery time
- Note any issues
- Update runbooks
- Share with team

### 5. Automate
Use scheduled workflows for:
- Regular resilience validation
- Regression testing
- Continuous chaos engineering

## Resources

- **LitmusChaos Docs**: https://docs.litmuschaos.io/
- **Chaos Hub**: https://hub.litmuschaos.io/
- **Community**: https://kubernetes.slack.com/messages/litmus
- **GitHub**: https://github.com/litmuschaos/litmus

## Quick Reference

```bash
# Access Portal
make chaos-ui

# Run workflows
make chaos-workflows-run
make chaos-workflows-load
make chaos-workflows-status

# Check infrastructure
kubectl get pods -n litmus
kubectl get chaosengines -A
kubectl get chaosexperiments -A

# View logs
kubectl logs -n litmus -l app=subscriber
kubectl logs -n litmus -l app=chaos-operator

# Clean up
make chaos-clean
make chaos-workflows-clean
```

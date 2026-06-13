ifneq (,$(wildcard ../.env))
    include ../.env
    export
endif

AWS_DEFAULT_REGION ?= us-east-1

.PHONY: check-prereqs cluster-up cluster-down install-crossplane install-argocd install-backstage backstage-dev backstage-stop backstage-restart

check-prereqs:
	@./scripts/check-prereqs.sh

cluster-up:
	@echo "Creating Kind Kubernetes cluster..."
	kind create cluster --config kind-config.yaml
	@echo "Waiting for node to be ready..."
	kubectl wait --for=condition=Ready node/backstage-dev-control-plane --timeout=90s
	@echo "Kind cluster backstage-dev is ready."

cluster-down:
	@echo "Deleting Kind Kubernetes cluster..."
	kind delete cluster --name backstage-dev
	@echo "Kind cluster deleted."

install-crossplane:
	@echo "Adding Crossplane Helm repository..."
	helm repo add crossplane-stable https://charts.crossplane.io/stable
	helm repo update
	@echo "Installing Crossplane..."
	helm upgrade --install crossplane crossplane-stable/crossplane --namespace crossplane-system --create-namespace --wait
	@echo "Verifying Crossplane deployment health..."
	kubectl wait --namespace crossplane-system --for=condition=ready pod -l app=crossplane --timeout=120s
	@echo "Crossplane is installed and healthy."

install-argocd:
	@echo "Adding ArgoCD Helm repository..."
	helm repo add argo https://argoproj.github.io/argo-helm
	helm repo update
	@echo "Installing ArgoCD..."
	helm upgrade --install argocd argo/argo-cd --namespace argocd --create-namespace --wait
	@echo "Patching ArgoCD server service to NodePort 30080..."
	@SVC_NAME=argocd-server && \
	PORT_NUM=$$(kubectl get svc $$SVC_NAME -n argocd -o jsonpath='{.spec.ports[0].port}') && \
	kubectl patch svc $$SVC_NAME -n argocd -p "{\"spec\": {\"type\": \"NodePort\", \"ports\": [{\"port\": $$PORT_NUM, \"nodePort\": 30080}]}}"
	@echo "Verifying ArgoCD server health..."
	kubectl wait --namespace argocd --for=condition=ready pod -l app.kubernetes.io/name=argocd-server --timeout=120s
	@echo "ArgoCD is installed and accessible at http://localhost:8080."

install-kyverno:
	helm repo add kyverno https://kyverno.github.io/kyverno/
	helm repo update
	helm install kyverno kyverno/kyverno \
		--namespace kyverno \
		--create-namespace \
		--wait

.PHONY: install-kyverno install-kyverno-policies
install-kyverno-policies:
	@echo "Applying Kyverno policies manually..."
	kubectl apply -f kyverno/policies/

install-backstage:
	@echo "Adding Backstage Helm repository..."
	helm repo add backstage https://backstage.github.io/charts
	helm repo update
	@echo "Installing Backstage..."
	helm upgrade --install backstage backstage/backstage --namespace backstage --create-namespace --wait
	@echo "Patching Backstage service to NodePort 30007..."
	@SVC_NAME=$$(kubectl get svc -n backstage -o jsonpath='{.items[0].metadata.name}') && \
	PORT_NUM=$$(kubectl get svc $$SVC_NAME -n backstage -o jsonpath='{.spec.ports[0].port}') && \
	kubectl patch svc $$SVC_NAME -n backstage -p "{\"spec\": {\"type\": \"NodePort\", \"ports\": [{\"port\": $$PORT_NUM, \"nodePort\": 30007}]}}"
	@echo "Verifying Backstage pod health..."
	kubectl wait --namespace backstage --for=condition=ready pod -l app.kubernetes.io/name=backstage --timeout=180s
	@echo "Backstage is installed and accessible at http://localhost:7007."

backstage-dev:
	@echo "Starting PostgreSQL 15 container in Docker Compose..."
	docker compose up -d db
	@echo "Installing Backstage dependencies..."
	export NVM_DIR="$$HOME/.nvm" && \
	[ -s "$$NVM_DIR/nvm.sh" ] && \. "$$NVM_DIR/nvm.sh" && \
	cd backstage && yarn install
	@echo "Starting Backstage app in development mode on port 3000..."
	export NVM_DIR="$$HOME/.nvm" && \
	[ -s "$$NVM_DIR/nvm.sh" ] && \. "$$NVM_DIR/nvm.sh" && \
	cd backstage && \
	if [ -f .env ]; then export $$(grep -v '^#' .env | xargs); fi && \
	POSTGRES_HOST=localhost \
	POSTGRES_PORT=5432 \
	POSTGRES_USER=postgres \
	POSTGRES_PASSWORD=postgrespassword \
	APP_PORT=3000 \
	yarn start

backstage-stop:
	@echo "Stopping Backstage frontend (port 3000) and backend (port 7007)..."
	@lsof -ti:3000 | xargs kill -9 2>/dev/null && echo "Stopped process on port 3000" || echo "Nothing on port 3000"
	@lsof -ti:7007 | xargs kill -9 2>/dev/null && echo "Stopped process on port 7007" || echo "Nothing on port 7007"
	@echo "Backstage stopped."

backstage-restart: backstage-stop
	@echo "Restarting Backstage..."
	$(MAKE) backstage-dev

.PHONY: install-crossplane-providers aws-creds check-crossplane

install-crossplane-providers:
	@echo "Applying Crossplane provider manifests..."
	kubectl apply -f infrastructure/crossplane/providers/provider-aws-eks.yaml
	kubectl apply -f infrastructure/crossplane/providers/provider-aws-ec2.yaml
	kubectl apply -f infrastructure/crossplane/providers/provider-aws-iam.yaml
	@echo "Waiting for providers to become healthy..."
	# Wait loop for each provider
	for prov in provider-aws-eks provider-aws-ec2 provider-aws-iam; do \
	  echo "Checking $$prov..."; \
	  kubectl wait --namespace crossplane-system --for=condition=Ready provider $$prov --timeout=300s || echo "Warning: $$prov not healthy after timeout"; \
	done

aws-creds:
	@echo "Running AWS credentials setup script..."
	bash scripts/setup-aws-creds.sh

check-crossplane:
	@echo "Crossplane providers status:"; \
	kubectl get provider -n crossplane-system -o custom-columns=NAME:.metadata.name,VERSION:.status.packageVersion,HEALTH:.status.health
.PHONY: install-xrd install-composition test-claim delete-claim install-eks-infra

install-xrd:
	@echo "Applying XRD manifest..."
	kubectl apply -f infrastructure/crossplane/eks/xrd.yaml
	@echo "Waiting for XRD to become Established..."
	kubectl wait --for=condition=Established crd xeksclusters.platform.io --timeout=180s

install-composition:
	@echo "Applying Composition manifest..."
	kubectl apply -f infrastructure/crossplane/eks/composition.yaml

install-eks-infra: install-xrd install-composition
	@echo "XRD and Composition installed."

test-claim:
	@echo "Applying claim example..."
	kubectl apply -f infrastructure/crossplane/eks/claim-example.yaml
	@echo "Watching Composite resource status (timeout 25m)..."
	END=$$(($(date +%s) + 1500))
	while [ $$(date +%s) -lt $$END ]; do \
	  STATUS=$$(kubectl get xeksclusters.platform.io alpha-test -n clusters -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "None"); \
	  echo "Current Ready status: $$STATUS"; \
	  if [ "$$STATUS" = "True" ]; then break; fi; \
	  sleep 30; \
	done
	@echo "Done watching claim."

delete-claim:
	@echo "Deleting claim..."
	kubectl delete -f infrastructure/crossplane/eks/claim-example.yaml --wait
	@echo "Ensuring all composed resources are removed..."
	kubectl delete -f infrastructure/crossplane/eks/composition.yaml --ignore-not-found
	kubectl delete -f infrastructure/crossplane/eks/xrd.yaml --ignore-not-found

.PHONY: argocd-login argocd-bootstrap argocd-status argocd-ui

argocd-login:
	@echo "Retrieving ArgoCD initial admin password..."
	@ARGOCD_PWD=$$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d) && \
	echo "Admin password: $$ARGOCD_PWD" && \
	argocd login localhost:8080 --username admin --password "$$ARGOCD_PWD" --insecure && \
	echo "Logged into ArgoCD CLI."

argocd-bootstrap:
	@echo "=== Step 1/3: Setting up ArgoCD GitHub repository secret ==="
	bash scripts/setup-argocd-github.sh
	@echo ""
	@echo "=== Step 2/3: Applying ArgoCD AppProject ==="
	kubectl apply -f argocd/projects/idp-platform.yaml
	@echo ""
	@echo "=== Step 3/3: Applying ArgoCD root Application ==="
	kubectl apply -f argocd/apps/root-app.yaml
	@echo ""
	@echo "ArgoCD bootstrap complete."
	@echo "Run 'make argocd-status' to check sync state."

argocd-status:
	@echo "ArgoCD application status:"
	@kubectl get applications -n argocd -o custom-columns=\
	NAME:.metadata.name,\
	SYNC:.status.sync.status,\
	HEALTH:.status.health.status,\
	REVISION:.status.sync.revision,\
	PATH:.spec.source.path

argocd-ui:
	@echo "Port-forwarding ArgoCD UI to http://localhost:8080 ..."
	@kubectl port-forward svc/argocd-server -n argocd 8080:443 &
	@echo "ArgoCD UI is available at http://localhost:8080"
	@echo "Retrieve the admin password with:"
	@echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"

.PHONY: argocd-sync-all argocd-sync-claims test-gitops argocd-app-list

argocd-sync-all:
	@echo "Forcing sync of all ArgoCD applications..."
	@for app in $$(kubectl get applications -n argocd -o jsonpath='{.items[*].metadata.name}'); do \
	  echo "Syncing $$app..."; \
	  argocd app sync "$$app" --insecure 2>/dev/null || \
	    kubectl patch application "$$app" -n argocd --type merge \
	      -p '{"operation":{"sync":{"revision":"HEAD"}}}' 2>/dev/null || \
	    echo "  Warning: could not sync $$app"; \
	done
	@echo "All applications synced."

argocd-sync-claims:
	@echo "Forcing sync of cluster-claims application..."
	argocd app sync cluster-claims --insecure 2>/dev/null || \
	  kubectl patch application cluster-claims -n argocd --type merge \
	    -p '{"operation":{"sync":{"revision":"HEAD"}}}' 2>/dev/null || \
	  echo "Warning: could not sync cluster-claims"

test-gitops:
	@echo "Running GitOps flow E2E test..."
	bash scripts/test-gitops-flow.sh

.PHONY: test-kyverno check-aws-resources estimate-cost emergency-cleanup watch-cleanup daily-cost-check
test-kyverno:
	@bash ../scripts/test-kyverno.sh

check-aws-resources:
	@echo "Checking for running Crossplane-managed AWS resources..."
	@echo ""
	@echo "=== EKS Clusters ==="
	@aws eks list-clusters \
		--region $(AWS_DEFAULT_REGION) \
		--query 'clusters' \
		--output table 2>/dev/null || echo "None found"
	@echo ""
	@echo "=== VPCs ==="
	@aws ec2 describe-vpcs \
		--filters "Name=tag:managed-by,Values=crossplane" \
		--query 'Vpcs[*].{VpcId:VpcId,Environment:Tags[?Key==`environment`]|[0].Value,Team:Tags[?Key==`team`]|[0].Value}' \
		--region $(AWS_DEFAULT_REGION) \
		--output table 2>/dev/null || echo "None found"
	@echo ""
	@echo "=== EC2 Instances (Node Groups) ==="
	@aws ec2 describe-instances \
		--filters "Name=tag:managed-by,Values=crossplane" \
		          "Name=instance-state-name,Values=running,pending" \
		--query 'Reservations[*].Instances[*].{Id:InstanceId,Type:InstanceType,Environment:Tags[?Key==`environment`]|[0].Value,Team:Tags[?Key==`team`]|[0].Value}' \
		--region $(AWS_DEFAULT_REGION) \
		--output table 2>/dev/null || echo "None found"
	@echo ""
	@echo "=== IAM Roles (Crossplane-managed) ==="
	@aws iam list-roles \
		--query 'Roles[?contains(RoleName, `idp-`) || contains(RoleName, `crossplane-`)].{Name:RoleName,Created:CreateDate}' \
		--output table 2>/dev/null || echo "None found"
	@echo ""
	@echo "If resources shown above are unexpected run: make emergency-cleanup"

estimate-cost:
	@echo "Estimating cost of currently provisioned clusters..."
	@echo ""
	@kubectl get eksclusters -A \
		-o custom-columns=\
	'NAME:.metadata.name,\
	NAMESPACE:.metadata.namespace,\
	ENV:.spec.parameters.environment,\
	INSTANCE:.spec.parameters.nodeInstanceType,\
	NODES:.spec.parameters.nodeCount,\
	READY:.status.conditions[0].status' \
		2>/dev/null || echo "No clusters found"
	@echo ""
	@echo "Cost reference:"
	@echo "  EKS control plane:  \$$0.10/hr (\$$72/month) per cluster"
	@echo "  t3.medium per node: \$$0.0416/hr (\$$30/month)"
	@echo "  t3.large per node:  \$$0.0832/hr (\$$60/month)"
	@echo "  m5.large per node:  \$$0.096/hr (\$$70/month)"

emergency-cleanup:
	@echo "⚠️  EMERGENCY CLEANUP — deleting all Crossplane claims"
	@echo "This will delete ALL clusters in ALL namespaces"
	@echo "AWS resources will be deprovisioned by Crossplane"
	@echo ""
	@read -p "Type CONFIRM to proceed: " confirm; \
	if [ "$$confirm" != "CONFIRM" ]; then \
		echo "Aborted."; \
		exit 1; \
	fi
	@echo "Deleting all EKSCluster claims..."
	@kubectl delete eksclusters --all -n clusters-dev 2>/dev/null || true
	@kubectl delete eksclusters --all -n clusters-staging 2>/dev/null || true
	@echo ""
	@echo "Claims deleted. Crossplane is now deprovisioning AWS resources."
	@echo "Monitor cleanup with: make check-aws-resources"
	@echo "Full cleanup takes approximately 15-20 minutes."

watch-cleanup:
	@echo "Watching Crossplane managed resource cleanup..."
	@echo "Press Ctrl+C to stop watching"
	@watch -n 30 'kubectl get managed 2>/dev/null | grep -v "True.*True" || echo "All managed resources cleaned up ✅"'

daily-cost-check: check-aws-resources estimate-cost
	@echo ""
	@echo "Daily check complete."
	@echo "If anything unexpected is running: make emergency-cleanup"
	@echo "AWS Budget alerts configured? See: infrastructure/docs/aws-budget-setup.md"

argocd-app-list:
	@echo "ArgoCD applications:"
	@printf "%-28s %-12s %-12s %-10s %s\n" "NAME" "SYNC" "HEALTH" "PROJECT" "PATH"
	@printf "%-28s %-12s %-12s %-10s %s\n" "----" "----" "------" "-------" "----"
	@kubectl get applications -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.sync.status}{"\t"}{.status.health.status}{"\t"}{.spec.project}{"\t"}{.spec.source.path}{"\n"}{end}' 2>/dev/null | \
	  while IFS=$$'\t' read -r name sync health project path; do \
	    printf "%-28s %-12s %-12s %-10s %s\n" "$$name" "$$sync" "$$health" "$$project" "$$path"; \
	  done


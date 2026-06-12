# AWS Budget Alert Setup Guide

To protect your AWS account from unexpected costs, you must set up AWS Budget alerts. Since credentials are not yet configured for automated provisioning, these steps must be performed manually in the AWS Console.

---

## Budget 1: IDP Resource Budget ($10/month)

This budget tracks only the resources created and managed by the Internal Developer Platform (IDP) via Crossplane.

### Setup Steps
1. Log into the [AWS Console](https://console.aws.amazon.com/).
2. Navigate to **Billing** → **Budgets** (or search for "Budgets" in the top search bar).
3. Click **Create budget**.
4. Choose **Budget type**: **Cost budget** (Recommended) and click **Next**.
5. Set the budget parameters:
   * **Period**: Monthly
   * **Budget effective date**: Recurring budget
   * **Budget method**: Fixed
   * **Enter budget amount**: `$10.00`
   * **Budget name**: `idp-crossplane-resource-budget`
6. **Scope your budget (Filters)**:
   * Under **Budget scope**, select **Filter by specific dimensions**.
   * Choose **Tag** as the dimension.
   * Select the Tag key **`managed-by`** and set its value to **`crossplane`**.
   * *This ensures only IDP-managed resources count toward this budget.*
7. Click **Next** to configure alerts.

### Configure Alerts
Set up three alerts based on actual or forecasted spend:

#### Alert 1: Early Warning (20%)
* **Threshold**: 20% of budget amount (`$2.00`)
* **Trigger**: Actual
* **Notification preferences**: Email notification
* **Description/Message**: 
  > Early warning — something may be running unexpectedly in the IDP dev/staging environment.

#### Alert 2: High Spend Warning (80%)
* **Threshold**: 80% of budget amount (`$8.00`)
* **Trigger**: Actual
* **Notification preferences**: Email + SMS (via SNS if configured, or direct SMS)
* **Description/Message**:
  > High spend warning — review running resources immediately.

#### Alert 3: Budget Exceeded (100%)
* **Threshold**: 100% of budget amount (`$10.00`)
* **Trigger**: Actual (or Forecasted)
* **Notification preferences**: Email + SMS
* **Description/Message**:
  > Budget exceeded — run 'make emergency-cleanup' immediately to tear down active resources.

8. Click **Next**, review the budget details, and click **Create budget**.

---

## Budget 2: Stray Resource Warning ($0.01/month)

This budget tracks all AWS services account-wide to catch any forgotten resources running outside of Crossplane management (e.g., resources manually created in the console, or out-of-band volumes/load balancers).

### Setup Steps
1. In the Budgets dashboard, click **Create budget**.
2. Choose **Budget type**: **Cost budget** and click **Next**.
3. Set the budget parameters:
   * **Period**: Monthly
   * **Budget effective date**: Recurring budget
   * **Budget method**: Fixed
   * **Enter budget amount**: `$0.01`
   * **Budget name**: `stray-resource-warning-budget`
4. **Scope your budget**:
   * Under **Budget scope**, select **All AWS services** (do not apply any filters).
5. Click **Next** to configure alerts.

### Configure Alerts

#### Alert 1: Stray Resource Detected (100%)
* **Threshold**: 100% of budget amount (`$0.01`)
* **Trigger**: Actual
* **Notification preferences**: Email notification (sent immediately)
* **Description/Message**:
  > Alert: Stray resource detected outside Crossplane management, or budget exceeded. Check AWS Console immediately for untagged active resources.

6. Click **Next**, review the budget details, and click **Create budget**.

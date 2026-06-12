# Decommission Record — ${{ values.clusterName }}

| Field | Value |
|---|---|
| Cluster | ${{ values.clusterName }} |
| Team | ${{ values.teamName }} |
| Environment | ${{ values.environment }} |
| Region | ${{ values.awsRegion }} |
| Instance type | ${{ values.instanceType }} |
| Node count | ${{ values.nodeCount }} |
| Reason | ${{ values.decommissionReason }} |
| Date | ${{ values.currentDate }} |
| Monthly saving | ${{ values.costSaving }} |

## Status
- Claim deleted from GitOps repo ✅
- Catalog entity unregistered ✅
- AWS cleanup: ${{ 'Automatic (Delete policy)' if values.environment == 'dev' else 'Manual required (Orphan policy)' }}

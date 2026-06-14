# ${{ values.instanceName }}

RDS ${{ values.engine }} database instance managed by the IDP platform.

## Details

| Parameter | Value |
|-----------|-------|
| Team | `${{ values.teamName }}` |
| Environment | `${{ values.environment }}` |
| Engine | `${{ values.engine }} ${{ values.engineVersion }}` |
| Instance Class | `${{ values.instanceClass }}` |
| Storage | `${{ values.storageGb }} GB` |
| Multi-AZ | `${{ values.multiAz }}` |
| AWS Region | `${{ values.awsRegion }}` |
| Requested At | `${{ values.createdAt }}` |

## Connection

Once provisioned, connection credentials are stored in Kubernetes secret:

```bash
kubectl get secret ${{ values.instanceName }}-db-creds -n ${{ values.teamName }}
```

## Decommissioning

To decommission this database, use the IDP **Decommission Database** template in Backstage.
Staging instances require a PR; dev instances can be deleted directly.

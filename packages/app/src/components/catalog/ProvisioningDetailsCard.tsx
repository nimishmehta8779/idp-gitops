import React from 'react';
import {
  Card,
  CardContent,
  CardHeader,
  Table,
  TableBody,
  TableCell,
  TableRow,
  Typography,
} from '@material-ui/core';
import { useEntity } from '@backstage/plugin-catalog-react';

export const ProvisioningDetailsCard = () => {
  const { entity } = useEntity();

  const annotations = entity.metadata?.annotations || {};

  const details = [
    {
      label: 'Cluster Status',
      key: 'idp.platform.io/cluster-status',
      value: annotations['idp.platform.io/cluster-status'] || 'N/A',
    },
    {
      label: 'Node Count',
      key: 'idp.platform.io/node-count',
      value: annotations['idp.platform.io/node-count'] || 'N/A',
    },
    {
      label: 'Instance Type',
      key: 'idp.platform.io/instance-type',
      value: annotations['idp.platform.io/instance-type'] || 'N/A',
    },
    {
      label: 'AWS Region',
      key: 'idp.platform.io/aws-region',
      value: annotations['idp.platform.io/aws-region'] || 'N/A',
    },
    {
      label: 'Monthly Cost Estimate',
      key: 'idp.platform.io/monthly-cost-estimate',
      value: annotations['idp.platform.io/monthly-cost-estimate'] || 'N/A',
    },
  ];

  return (
    <Card>
      <CardHeader title="Provisioning Details" />
      <CardContent>
        <Table size="small">
          <TableBody>
            {details.map((detail) => (
              <TableRow key={detail.key}>
                <TableCell component="th" scope="row">
                  <Typography variant="body2" color="textSecondary">
                    {detail.label}
                  </Typography>
                </TableCell>
                <TableCell align="right">
                  <Typography variant="body2">{detail.value}</Typography>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  );
};

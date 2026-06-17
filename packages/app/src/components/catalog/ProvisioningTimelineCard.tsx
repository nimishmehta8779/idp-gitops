import React from 'react';
import {
  Card,
  CardContent,
  CardHeader,
  Box,
  Chip,
  Typography,
  Timeline,
  TimelineItem,
  TimelineSeparator,
  TimelineConnector,
  TimelineContent,
  TimelineDot,
} from '@material-ui/core';
import { makeStyles } from '@material-ui/core/styles';
import { useEntity } from '@backstage/plugin-catalog-react';
import CheckCircleIcon from '@material-ui/icons/CheckCircle';
import HourglassEmptyIcon from '@material-ui/icons/HourglassEmpty';
import DeleteIcon from '@material-ui/icons/Delete';

const useStyles = makeStyles((theme) => ({
  timeline: {
    padding: 0,
  },
  timelineDot: {
    boxShadow: 'none',
  },
  provisioning: {
    backgroundColor: theme.palette.warning.main,
  },
  ready: {
    backgroundColor: theme.palette.success.main,
  },
  deleting: {
    backgroundColor: theme.palette.error.main,
  },
  chip: {
    marginLeft: theme.spacing(1),
  },
}));

type StatusType = 'provisioning' | 'ready' | 'deleting' | 'unknown';

export const ProvisioningTimelineCard = () => {
  const { entity } = useEntity();
  const classes = useStyles();

  const annotations = entity.metadata?.annotations || {};
  const createdAt = annotations['idp.platform.io/created-at'];
  const status = (annotations['idp.platform.io/cluster-status'] || 'unknown').toLowerCase() as StatusType;

  const getIcon = (status: StatusType) => {
    switch (status) {
      case 'provisioning':
        return <HourglassEmptyIcon />;
      case 'ready':
        return <CheckCircleIcon />;
      case 'deleting':
        return <DeleteIcon />;
      default:
        return <HourglassEmptyIcon />;
    }
  };

  const getColor = (status: StatusType) => {
    switch (status) {
      case 'provisioning':
        return classes.provisioning;
      case 'ready':
        return classes.ready;
      case 'deleting':
        return classes.deleting;
      default:
        return '';
    }
  };

  return (
    <Card>
      <CardHeader title="Provisioning Timeline" />
      <CardContent>
        <Timeline className={classes.timeline}>
          <TimelineItem>
            <TimelineSeparator>
              <TimelineDot className={classes.timelineDot}>
                <CheckCircleIcon style={{ color: '#4caf50' }} />
              </TimelineDot>
              <TimelineConnector />
            </TimelineSeparator>
            <TimelineContent>
              <Box display="flex" alignItems="center">
                <Typography variant="body2">
                  Created at {createdAt || 'N/A'}
                </Typography>
              </Box>
            </TimelineContent>
          </TimelineItem>

          <TimelineItem>
            <TimelineSeparator>
              <TimelineDot className={`${classes.timelineDot} ${getColor(status)}`}>
                {getIcon(status)}
              </TimelineDot>
            </TimelineSeparator>
            <TimelineContent>
              <Box display="flex" alignItems="center">
                <Typography variant="body2">Status:</Typography>
                <Chip
                  label={status.charAt(0).toUpperCase() + status.slice(1)}
                  size="small"
                  className={classes.chip}
                  color={status === 'ready' ? 'primary' : 'default'}
                  variant={status === 'ready' ? 'default' : 'outlined'}
                />
              </Box>
            </TimelineContent>
          </TimelineItem>
        </Timeline>
      </CardContent>
    </Card>
  );
};

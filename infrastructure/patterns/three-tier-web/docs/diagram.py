"""
Architecture diagram for the three-tier-web pattern.

Renders:
  docs/architecture.png
  docs/architecture.svg

The SVG is embedded in docs/index.md for Backstage TechDocs.

Run:
  cd infrastructure/patterns/three-tier-web
  python docs/diagram.py

Prerequisites:
  pip install diagrams
  brew install graphviz  # or: apt-get install graphviz

Components provisioned by this pattern:
  Web tier:  Application Load Balancer (ALB), HTTPS listener, HTTP→HTTPS redirect
  App tier:  ECS Fargate cluster + task definition + service, CloudWatch log group
  Data tier: RDS PostgreSQL (Multi-AZ for staging/prod)
  IAM:       ECS task role + task execution role
  Network:   Security groups only — VPC/subnets are pre-provisioned enterprise infra
"""

import sys
import os

# Allow running from the pattern root or the docs/ subdirectory
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "_lib"))

from diagram_helpers import new_diagram, vpc_cluster, tier_cluster

from diagrams.aws.network import ELB as ALB
from diagrams.aws.compute import ECS
from diagrams.aws.database import RDS
from diagrams.aws.management import Cloudwatch
from diagrams.aws.security import IAMRole
from diagrams.aws.general import InternetGateway

OUTPUT_DIR = os.path.dirname(os.path.abspath(__file__))

with new_diagram("three-tier-web", output_dir=OUTPUT_DIR) as _:
    internet = InternetGateway("Internet")

    with vpc_cluster():
        with tier_cluster("Public subnets (pre-provisioned)", color="#e3f2fd"):
            alb = ALB("ALB\nHTTPS :443\n→ HTTP :80 redirect")

        with tier_cluster("Private subnets (pre-provisioned)", color="#e8f5e9"):
            ecs_svc = ECS("ECS Fargate\nService (awsvpc)")
            cw = Cloudwatch("CloudWatch\nLogs")

        with tier_cluster("Data subnets (pre-provisioned)", color="#fff3e0"):
            rds = RDS("RDS PostgreSQL\nMulti-AZ (staging/prod)")

    iam_exec = IAMRole("Task Execution\nRole")
    iam_task = IAMRole("Task Role\n(least-privilege)")

    internet >> alb >> ecs_svc >> rds
    ecs_svc >> cw
    ecs_svc - iam_exec
    ecs_svc - iam_task

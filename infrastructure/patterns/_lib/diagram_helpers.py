"""
Shared helpers for aws-architect pattern diagrams.

Usage in a pattern's docs/diagram.py:
    from diagram_helpers import new_diagram, vpc_cluster, tier_cluster

Prerequisites:
    pip install diagrams
    apt-get install graphviz   # or: brew install graphviz
"""

from contextlib import contextmanager
from diagrams import Diagram, Cluster


@contextmanager
def new_diagram(name: str, output_dir: str = ".", filename: str = "architecture", show: bool = False):
    """
    Context manager wrapping diagrams.Diagram with standard IDP defaults.

    Args:
        name:       Diagram title shown inside the rendered image.
        output_dir: Directory to write output files into.
        filename:   Output filename stem (default "architecture").
                    Produces <output_dir>/<filename>.png and .svg.
        show:       Open the rendered diagram after generation (default False).

    Yields the Diagram context so callers can add nodes and edges.

    Example:
        with new_diagram("three-tier-web", output_dir="docs") as diag:
            ...
    """
    attrs = {
        "filename": f"{output_dir}/{filename}",
        "outformat": ["png", "svg"],
        "show": show,
        "graph_attr": {
            "pad": "0.5",
            "splines": "ortho",
            "fontname": "Helvetica",
            "fontsize": "14",
            "bgcolor": "white",
        },
        "node_attr": {
            "fontname": "Helvetica",
            "fontsize": "11",
        },
        "edge_attr": {
            "fontname": "Helvetica",
            "fontsize": "10",
        },
    }
    with Diagram(name, **attrs) as diag:
        yield diag


@contextmanager
def vpc_cluster(label: str = "Pre-provisioned VPC (not managed by this pattern)"):
    """
    Dashed-border cluster representing the enterprise VPC boundary.

    This is a CONTEXT ONLY marker — it documents which VPC the resources
    land in, consistent with the Network Reference Rule (we never provision
    VPCs, subnets, NAT gateways, or internet gateways).

    Example:
        with vpc_cluster():
            with tier_cluster("Public subnets"):
                alb = ElasticLoadBalancing("ALB")
    """
    with Cluster(
        label,
        graph_attr={
            "style": "dashed",
            "color": "#999999",
            "fontcolor": "#666666",
            "fontsize": "10",
            "bgcolor": "#fafafa",
        },
    ):
        yield


@contextmanager
def tier_cluster(label: str, color: str = "#e8f4fd"):
    """
    Solid-border cluster representing a network tier (public/private/data).

    Args:
        label: Display label, e.g. "Public subnets (pre-provisioned)".
        color: Background fill color (default light blue).

    Example:
        with tier_cluster("Private subnets (pre-provisioned)", color="#e8f5e9"):
            svc = ECS("ECS Service")
    """
    with Cluster(
        label,
        graph_attr={
            "style": "solid",
            "color": "#aaaaaa",
            "fontcolor": "#444444",
            "fontsize": "10",
            "bgcolor": color,
        },
    ):
        yield

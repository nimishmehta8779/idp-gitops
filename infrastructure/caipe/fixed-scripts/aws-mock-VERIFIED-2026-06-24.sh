#!/bin/sh

# If the command is "eks update-kubeconfig", mock it
if [ "$1" = "eks" ] && [ "$2" = "update-kubeconfig" ]; then
    kubeconfig_path=""
    cluster_name=""
    region=""
    
    # We iterate over arguments without shifting them to preserve "$@"
    next_is_kubeconfig=0
    next_is_name=0
    next_is_region=0
    for arg in "$@"; do
        if [ "$next_is_kubeconfig" = "1" ]; then
            kubeconfig_path="$arg"
            next_is_kubeconfig=0
        elif [ "$next_is_name" = "1" ]; then
            cluster_name="$arg"
            next_is_name=0
        elif [ "$next_is_region" = "1" ]; then
            region="$arg"
            next_is_region=0
        elif [ "$arg" = "--kubeconfig" ]; then
            next_is_kubeconfig=1
        elif [ "$arg" = "--name" ]; then
            next_is_name=1
        elif [ "$arg" = "--region" ]; then
            next_is_region=1
        fi
    done
    
    # Determine the region to query
    aws_region="$region"
    if [ -z "$aws_region" ]; then
        aws_region="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
    fi

    # Query the real AWS CLI to see if this cluster is real
    is_real=0
    if [ -n "$cluster_name" ]; then
        if /usr/local/aws-cli/v2/2.35.4/dist/aws eks list-clusters --region "$aws_region" --output json 2>/dev/null | grep -q "\"$cluster_name\""; then
            is_real=1
        fi
    fi

    if [ "$is_real" = "1" ]; then
        echo "Cluster $cluster_name is a real EKS cluster. Passing call through to real AWS CLI..." >&2
        exec /usr/local/aws-cli/v2/2.35.4/dist/aws "$@"
    else
        echo "Cluster $cluster_name is not a real EKS cluster. Substituting Kind kubeconfig..." >&2
        if [ -n "$kubeconfig_path" ]; then
            cp /app/secrets/kubeconfig.yaml "$kubeconfig_path"
            exit 0
        fi
    fi
fi

# If the command is "eks list-clusters", merge real and mock clusters
if [ "$1" = "eks" ] && [ "$2" = "list-clusters" ]; then
    region=""
    next_is_region=0
    for arg in "$@"; do
        if [ "$next_is_region" = "1" ]; then
            region="$arg"
            next_is_region=0
        elif [ "$arg" = "--region" ]; then
            next_is_region=1
        fi
    done
    aws_region="$region"
    if [ -z "$aws_region" ]; then
        aws_region="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
    fi

    # Fetch real clusters
    real_json=$(/usr/local/aws-cli/v2/2.35.4/dist/aws eks list-clusters --region "$aws_region" --output json 2>/dev/null)
    if [ -n "$real_json" ]; then
        inner=$(echo "$real_json" | tr -d '\n\r' | sed -n 's/.*"clusters": \[\(.*\)\].*/\1/p' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ -n "$inner" ]; then
            echo "{\"clusters\": [\"alpha-dev-general-01\", $inner]}"
        else
            echo '{"clusters": ["alpha-dev-general-01"]}'
        fi
    else
        echo '{"clusters": ["alpha-dev-general-01"]}'
    fi
    exit 0
fi

# If the command is "eks describe-cluster", mock it or pass through if real
if [ "$1" = "eks" ] && [ "$2" = "describe-cluster" ]; then
    cluster_name=""
    region=""
    next_is_name=0
    next_is_region=0
    for arg in "$@"; do
        if [ "$next_is_name" = "1" ]; then
            cluster_name="$arg"
            next_is_name=0
        elif [ "$next_is_region" = "1" ]; then
            region="$arg"
            next_is_region=0
        elif [ "$arg" = "--name" ]; then
            next_is_name=1
        elif [ "$arg" = "--region" ]; then
            next_is_region=1
        fi
    done
    
    aws_region="$region"
    if [ -z "$aws_region" ]; then
        aws_region="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
    fi
    
    is_real=0
    if [ -n "$cluster_name" ]; then
        if /usr/local/aws-cli/v2/2.35.4/dist/aws eks list-clusters --region "$aws_region" --output json 2>/dev/null | grep -q "\"$cluster_name\""; then
            is_real=1
        fi
    fi
    
    if [ "$is_real" = "1" ]; then
        echo "Passing describe-cluster for real cluster $cluster_name to real AWS CLI..." >&2
        exec /usr/local/aws-cli/v2/2.35.4/dist/aws "$@"
    else
        echo '{"cluster": {"name": "alpha-dev-general-01", "status": "ACTIVE", "arn": "arn:aws:eks:us-east-1:415703161648:cluster/alpha-dev-general-01", "endpoint": "https://backstage-dev-control-plane:6443", "resourcesVpcConfig": {"vpcId": "vpc-mock", "subnetIds": ["subnet-mock-1", "subnet-mock-2"], "securityGroupIds": ["sg-mock"]}}}'
        exit 0
    fi
fi

# Fallback to the real aws CLI for any other commands
exec /usr/local/aws-cli/v2/2.35.4/dist/aws "$@"

"""
Architecture diagram for orders-web-cicd, drawn with AWS icons.

Run from the project root:
    python docs/architecture.py

Writes docs/architecture.png. Requires the `diagrams` package and Graphviz.
"""

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.compute import ECR, ECS
from diagrams.aws.management import Cloudwatch
from diagrams.aws.network import ALB
from diagrams.aws.security import IAM
from diagrams.aws.storage import S3
from diagrams.onprem.ci import GithubActions
from diagrams.onprem.client import Users
from diagrams.onprem.iac import Terraform
from diagrams.onprem.vcs import Github

graph_attr = {"fontsize": "13", "pad": "0.6", "nodesep": "0.6", "ranksep": "0.9"}

with Diagram(
    "orders-web-cicd",
    filename="docs/architecture",
    outformat="png",
    show=False,
    direction="LR",
    graph_attr=graph_attr,
):
    users = Users("Users")
    dev = Github("push to main")
    tf = Terraform("Terraform\ninfra/")

    with Cluster("GitHub Actions"):
        build = GithubActions("build-and-push\nOIDC build role")
        deploy = GithubActions("deploy-production\nrequired reviewer")

    with Cluster("AWS account"):
        iam = IAM("OIDC roles\nbuild / deploy")
        ecr = ECR("ECR\nimmutable tags")
        s3 = S3("Terraform state\nS3 native lock")
        logs = Cloudwatch("CloudWatch Logs")

        with Cluster("Default VPC (public subnets)"):
            alb = ALB("ALB :80\ntarget: /api/health")
            ecs = ECS("ECS service\n2 Fargate tasks :3000")

    # Delivery path
    dev >> Edge(label="triggers") >> build
    build >> Edge(label="push image\n(tag = SHA)") >> ecr
    build >> Edge(label="image digest") >> deploy
    deploy >> Edge(label="register revision\nupdate service") >> ecs
    deploy >> Edge(label="health gate\nGET /api/health", style="dashed") >> alb

    # Runtime path
    users >> Edge(label="HTTP") >> alb
    alb >> Edge(label="route to healthy tasks") >> ecs
    ecs >> Edge(label="pull by digest", style="dashed") >> ecr
    ecs >> Edge(label="stdout", style="dashed") >> logs

    # Supporting
    build >> Edge(label="assume role", style="dotted") >> iam
    deploy >> Edge(label="assume role", style="dotted") >> iam
    tf >> Edge(label="state", style="dashed") >> s3

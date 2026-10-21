# ECS on EC2 Demo with NGINX (Terraform)

Single-file Terraform demo (originally "aws-ecs-ec2-nginx-tf") that creates a VPC, an EC2-backed ECS cluster behind an
Application Load Balancer, and runs an `nginx:latest` service on it.

> **Status:** legacy reference (2019), written for Terraform 0.11-era syntax (`"${...}"` interpolation, `type = "string"`, `tags {}` blocks), not actively maintained. Review and update providers/syntax before using.

## Architecture

- VPC `10.0.0.0/16`, Internet Gateway, public route table and 3 public subnets in `us-east-1a/b/c`.
- Security group `main`: 22, 80, 443 and 8080 open from `0.0.0.0/0`, all egress.
- `aws_key_pair` named `main` from an embedded public key (`jalcalaroot.pub` is also tracked).
- IAM: ECS service role (`AmazonEC2ContainerServiceRole`) and ECS instance role + instance profile (`AmazonEC2ContainerServiceforEC2Role`).
- ECS cluster named by `var.ecs_cluster`.
- ALB `ecs-load-balancer` with an HTTP:80 listener forwarding to target group `ecs-target-group` (health check `/`).
- Launch configuration (hardcoded ECS-optimized AMI, `t3.small`, 50 GB gp2, public IP) whose user data registers the instance in the cluster.
- Auto Scaling group fixed at 3 instances across the public subnets.
- ECS service `nginx` (1 task, host port 80) attached to the ALB, logging to CloudWatch log group `/ecs-demo/nginx`.

```
Internet -> ALB :80 -> target group -> ECS (EC2 ASG x3) -> nginx task
```

Outputs: `vpc_id`, `public-subnet-0`.

## Inputs

| Name | Description | Default |
|------|-------------|---------|
| `access_key` | AWS access key ID for the provider | none (required) |
| `secret_key` | AWS secret access key for the provider | none (required) |
| `region` | AWS region (AZs are hardcoded to `us-east-1a/b/c`) | none (required) |
| `ecs_cluster` | ECS cluster name | none (required) |

## Usage

```bash
terraform init
terraform plan  -var 'region=us-east-1' -var 'ecs_cluster=demo' -var 'access_key=<ACCESS_KEY_ID>' -var 'secret_key=<SECRET_ACCESS_KEY>'
terraform apply -var 'region=us-east-1' -var 'ecs_cluster=demo' -var 'access_key=<ACCESS_KEY_ID>' -var 'secret_key=<SECRET_ACCESS_KEY>'
```

No backend is configured; state is local. Replace the embedded public key / `<KEY_PAIR_NAME>` with your own.

## Security notes

- SSH (22) and 8080 open to `0.0.0.0/0`; the same SG is shared by the ALB and the container instances, which have public IPs.
- AWS credentials passed as plain variables (stored in local state); prefer profiles/roles.
- ALB serves HTTP only; root volumes not encrypted; image uses the mutable `nginx:latest` tag.
- Deprecated pieces: `roles` on `aws_iam_instance_profile`, `aws_launch_configuration`, the legacy ECS service role, `count.index` without `count` in route table associations.
- Local state, no provider version pinning.

## Cleanup

```bash
terraform destroy
```

## License

MIT — see [LICENSE](LICENSE).

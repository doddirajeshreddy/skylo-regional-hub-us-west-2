### Skylo Regional Hub

This document describes the design and Terraform implementation for a new Skylo Regional Hub in the `us-west-2` (Oregon) region.

The hub has two main responsibilities:
- Receive high-volume, real-time connectivity data from satellite ground stations via Direct Connect.
- Run containerized 3GPP core workloads for session management and data processing.

The solution is designed for:
- High availability (Operates even one single-AZ goes down)
- Scalability (Scale horizontally to handle growing traffic loads)
- Security (Least privilege, zero trust, SOC 2 compliance)
- Automation (Infrastructure provisioning through Terraform)


### Architecture Design

### Network Design

```
                       Ground Stations
                             |
                       Direct Connect
                             |
                   Direct Connect Gateway
                             |
                       Transit Gateway
                             |
     ======================================================
     |        Skylo Regional Hub VPC (10.20.0.0/16)       |
     ======================================================
                         Internet Gateway
                               ▲
                               |

   ----------------------- Public Subnets -----------------------
   | 10.20.0.0/20        10.20.16.0/20        10.20.32.0/20       |
   ---------------------------------------------------------------
                ^                    ^                    ^
                |  (Outbound traffic from private subnets via NAT → IGW)

   --------------------- Private App Subnets ---------------------
   | 10.20.48.0/20      10.20.64.0/20       10.20.80.0/20          |
   |   EKS Nodes          EKS Nodes            EKS Nodes           |
   ----------------------------------------------------------------

   --------------------- Private Data Subnets --------------------
   | 10.20.96.0/20      10.20.112.0/20      10.20.128.0/20         |
   |    DB/Cache           DB/Cache             DB/Cache           |
   ----------------------------------------------------------------
                 VPC Endpoints (S3, DynamoDB, CloudWatch)
```

### IP Addressing (CIDR) Strategy
- /16 gives plenty of space for future scaling.

- /20 subnets are large enough for EKS and simple to manage.

- Public, application, and data tiers remain clearly separated.

- The same structure is repeated across all three AZs for high availability.

### VPC

  - The VPC uses 10.20.0.0/16 and this gives plenty of private IP space for EKS nodes, pods, NAT gateways, databases, and future growth.

### Subnets

- The VPC /16 block is divided into /20 subnets and each /20 has around 4,000 IPs

### Public Subnets (one per AZ)

- 10.20.0.0/20

- 10.20.16.0/20

- 10.20.32.0/20

Purpose: To Host NAT Gateways, which provide outbound-only internet access for private subnets. These have a route to the Internet Gateway (0.0.0.0/0 → IGW).

### Private Subnets (EKS Worker Nodes)

- 10.20.48.0/20

- 10.20.64.0/20

- 10.20.80.0/20

Purpose: To run containerized 3GPP workloads on EKS.These subnets receive inbound traffic from the Transit Gateway and use NAT for outbound internet access.

### Private Data Subnets (DB/Cache)

- 10.20.96.0/20

- 10.20.112.0/20

- 10.20.128.0/20

Purpose: To host stateful services such as databases and caches and access internal AWS services through VPC Endpoints, keeping them fully private.


### Compute Patform
### Amazon EKS
The containerized 3GPP workloads will run on Amazon EKS. These workloads behave like cloud-native network functions, and Kubernetes is the standard platform used to run them. EKS provides a managed Kubernetes control plane while giving full flexibility for running complex telecom components.

### Why EKS instead of ECS 
Most 3GPP core components are designed to run on Kubernetes. They often come with Helm charts and custom networking requirements that ECS does not support well.

-  Scaling capabilities: This matches the traffic spikes that occur when ground stations send high-volume data.
    EKS supports both Pods (Horizontal Pod Autoscaler) and Worker nodes (Cluster Autoscaler)

- Network flexibility: EKS gives flexibility interms of custom CNI plugins and Pod-level networking
  
- Security: EKS supports IAM Roles for Service Accounts (IRSA) and Network Policies

### Data Storage

  The Regional Hub needs two different types of storage:
  - Fast, short-lived session state that supports real-time 3GPP processing
  - Long-term storage for connection logs that must be kept reliably and cost-effectively

### Short-Term Session State (High-throughput, Low-latency)
3GPP workloads generate constant session updates, device registrations, session metadata, and policy lookups.This data needs to be read and written quickly, often under heavy traffic spikes.

Why DynamoDB fits this pattern well because it provides:
- Consistently low latency
- Automatic scaling when traffic increases
- Multi-AZ availability 
- A simple key-value access model that matches session metadata

### ElastiCache (Redis) for the fastest lookups
Some values need to be retrieved even faster than DynamoDB can deliver. It Supports below options:
- repeat lookups
- temporary session flags
- Data that is accessed many times within a short window

For these situations, Redis (ElastiCache) serves as an in-memory cache. It reduces load on the primary store and ensures the 3GPP components stay responsive, even during high-traffic bursts.

### Long-Term Archival of Connection Logs
Connection logs and session histories must be stored for analytics, troubleshooting, and compliance.These datasets grow quickly and must be retained for long periods, sometimes years.
### Amazon S3: 
It stores the long-term connection logs in a durable and cost-efficient way
- Extremely high durability
- Low cost at scale
- Support for lifecycle rules (e.g., move old logs to Glacier automatically)

### High Availability & Disaster Recovery
### High Availability (within us-west-2)
The Regional Hub is designed to continue operating even if an entire Availability Zone becomes unavailable.
This is achieved by building the VPC and all core components across three AZs, with the same structure repeated in each one:
- A public subnet (with its own NAT Gateway)
- A private application subnet for EKS worker nodes
- A private data subnet for databases and caches

EKS node groups are spread across all three AZs so workloads can shift automatically when one zone experiences issues.
Data services such as DynamoDB and ElastiCache also operate in multi-AZ configurations, ensuring low-latency access even during AZ disruptions.
If one AZ fails, traffic from the Transit Gateway is still routed to healthy AZs, and the system continues to process ground-station data without interruption.

### Disaster Recovery (full region failure)
If the entire us-west-2 region becomes unavailable, the Regional Hub can be brought back online in another AWS region using two main principles.
- Infrastructure as Code : The entire Regional hub - VPC, subnets, Transit Gateway attachment, EKS cluster, and endpoints defined in reusable Terraform modules.
This allows the full environment to be recreated in a secondary region (such as us-east-1) with only a configuration change.

- Cross-region data replication: Critical metadata and long-lived logs can be replicated to another region using:-
  DynamoDB Global Tables for session-related metadata and S3 Cross-Region Replication (CRR) for connection logs and historical data

### Infrastructure as Code (Terraform)

Provisioning the Regional Hub Infrastructure using Terraform, which allows the entire environment to be defined, reviewed, and deployed as code. Instead of manually creating networks, subnets, gateways, or compute resources, everything is described in reusable Terraform modules.

### Folder Structure

```
terraform/
  modules/
    network/
      main.tf
      variables.tf
      outputs.tf
    tgw_attachment/
      main.tf
      variables.tf
      outputs.tf
    eks_cluster/
      main.tf
      variables.tf
      outputs.tf
  envs/
    us-west-2/
      versions.tf
      providers.tf
      variables.tf
      main.tf
      terraform.tfvars
```

### How to Deploy This Infrastructure

Run  below command
```
cd terraform/envs/us-west-2

```
### Set up AWS credentials
Terraform will look for AWS credentials in standard locations:

- AWS SSO (aws sso login)
- AWS Profile (export AWS_PROFILE=yourprofile)
- IAM Role in CI/CD - (Recomended for production)

 Example (local):

 ```
aws sso login --profile skylo
export AWS_PROFILE=skylo

```

### Initialize Terraform

Note:  Make sure you have created the s3 bucket and dynamodb table to store the statefile and locking. Then initialize the terraform using below command
```
terraform init

```

### Validate the configuration
Checks your Terraform files for syntax errors and ensures all modules and providers are defined correctly.

```
terraform validate

```

### Preview the Infrastructure
Shows what Terraform will create, modify, or destroy before making any actual changes.

```
terraform plan

```

### Apply the Infrastructure
Builds the infrastructure in AWS exactly as defined in the Terraform configuration.

```
terraform apply

```

### Security & Observability

### Security
For this hub, each workload uses its own IAM role (IRSA for EKS service accounts) so that permissions are provided as per service and followed least privilege.

Roles I would create

- Session Service Role

  Allows read/write access only to the DynamoDB tables or ElastiCache clusters used for session state.

- Ingress/Egress Service Role

  Allows PutObject to one S3 bucket or prefix for logs/telemetry.

  No ability to list buckets, read objects, or access other prefixes.

- Cluster Autoscaler Role

  Can describe and modify only the node groups belonging to this EKS cluster.

- Load Balancer Controller Role

  Can create/update ALBs/NLBs and target groups in this VPC.

- Log Forwarder Role (Fluent Bit)

  Can push logs to CloudWatch Logs or a dedicated S3 prefix.

- Secrets Access Role

  Can read (GetSecretValue) from exactly one Secrets Manager secret per workload.

  No permission to list or modify secrets.


### Permissions to avoid

- I avoid "*" permissions and full AdministratorAccess so workloads cannot perform actions outside their scope.
- Workloads should never be able to create, update, or delete IAM roles, users, or policies (iam:*).
- Services do not need to modify security groups, route tables, VPC settings, or Transit Gateway attachments.
- I do not allow workloads to read, delete, or list all objects in S3. Each service should only access its own bucket or folder, nothing more.
- A workload should only decrypt data that belongs to it. I avoid giving decrypt permissions to keys owned by other services or any kind of multi-key access.
- Workloads should not delete logs, S3 objects, or database items. Removing shared or historical data can cause data loss and impact troubleshooting.
- I avoid giving permissions that allow scanning unrelated DynamoDB tables, reading shared buckets, or accessing Secrets Manager entries not assigned to them.

### AWS Security Services I Would Enable First

- AWS KMS (Key Management Service) :  KMS comes first, because your hub handles sensitive device traffic, session data, logs, and secrets from the moment it is created, without KMS ready on day one, resources may start storing unencrypted data.

  KMS ensures:
  - S3 buckets for ingress data are encrypted
  - DynamoDB or Redis session state is encrypted
  - EKS node volumes are encrypted
  - Secrets Manager uses CMKs
  - All encryption operations are logged
    
- Amazon GuardDuty : GuardDuty comes next because this hub receives traffic from external ground stations through Direct Connect, which creates a unique risk surface.

  GuardDuty immediately begins monitoring for:

  - Suspicious API calls

  - Compromised IAM roles or keys

  - Unusual behavior inside EKS pods

  - Odd VPC traffic patterns

  - Unexpected DNS activity

- AWS Config: Config is the third service because it prevents misconfigurations, the most common cause of security incidents.

  Config checks:

  - All buckets are encrypted

  - No public access to private subnets

  - Security groups follow least privilege

  - EKS logging stays enabled

  - IAM roles follow least privilege

  - CloudTrail and VPC Flow Logs remain active
 
### Metrics

- Latency:  Latency tells me how quickly each service is responding, Hub that processes real-time satellite data, any increase in latency is one of the first signs that a service is overloaded or something downstream is slowing things down.
- Resource Usage (CPU, Memory, and Pod Restarts):  I would closely monitor CPU and memory usage at both the pod and node level. High CPU, memory pressure, or repeated restarts usually means a workload is running out of resources, memory Leaks, or experiencing instability.
- Network Health (Errors and Traffic Volume):  I would monitor Network errors, Packet drops, Bandwidth usage

### Observability

- Prometheus – Metrics Collection : I would use Prometheus to collect all the operational metrics from the EKS workloads. Prometheus integrates well with Kubernetes and gives detailed visibility into things like:

  - request latency
  - CPU and memory usage
  - pod restarts and failures
  - network traffic and throughput
 
- Grafana – Dashboards and Visualization:  Grafana sits on top of Prometheus and provides easy-to-read dashboards.
  I’d use Grafana to visualize:
    - how services are performing over time
    - how the cluster scales under load
    - node and pod health
    - traffic patterns across the hub
 
- CloudWatch – Logging and Alerts:  CloudWatch would serve as the central place for all logs and alerting signals.
I’d configure CloudWatch to capture:
  - cluster-level logs (EKS control plane)
  - application logs (via CloudWatch agents or EKS integrations)
  - VPC Flow Logs
  - Load balancer access logs

  CloudWatch Alarms:  I’d set up alarms for:
    - high latency
    - high CPU or memory
    - repeated pod failures
    - unhealthy nodes
    - unusual network activity

  Alerts can then be routed to Slack, PagerDuty, or whichever on-call tool the team uses.







# 🛠️ SQL Server Always On Availability Group (AOG) Setup on AWS EC2


## ✅ Overview

This guide walks you through the step-by-step setup of a **SQL Server Always On Availability Group (AOG)** using **EC2 instances on AWS**. 

From spinning up a VPC, EC2 instances, deploying domain controllers, configuring failover clustering, to building a working AOG with listener support across **2 Availability Zones** — this setup has all the pieces in place.

## 🌐 Environment Summary

- **Domain Name:** `RCX-DBA.COM`  
- **Region:** `us-east-1 (N. Virginia)`  
- **VPC CIDR:** `lab-vpc / 10.0.0.0/16`

## Network Preparation
- Create a VPC with the following CIDR 10.0.0.0/16
- Create 6 subnets, with 2 public subnets and 3 private subnets spread out in Availability zones `us-east-1a` and `us-east-1b`

### 🔀 Subnet Layout
**Availability Zone:** `us-east-1a`
- `vpc-pubsub-1a` → `10.0.0.0/20` (Bastion Host)
- `vpc-AD-privsub-1a` → `10.0.128.0/20` (Domain Controller)
- `vpc-DB-privsub-1a` → `10.0.100.0/27` (SQL1)

**Availability Zone:** `us-east-1b`
- `vpc-pubsub-ib` → `10.0.16.0/20`
- `vpc-AD-privsub-1b` → `10.0.144.0/20` (Secondary Domain Controller)
- `vpc-DB-privsub-1b` → `10.0.100.32/27` (SQL2)

## 📍 IP Assignments

| Component       | IP Address        |
|----------------|--------------------|
| SQL1           | `10.0.100.16`      |
| SQL2           | `10.0.100.49`      |
| Cluster IPs    | `10.0.100.20` (1a), `10.0.100.52` (1b) |
| Listener IPs   | `10.0.100.21` (1a), `10.0.100.53` (1b) |


## NAT Gateways
- Deploy a NAT gateway and associate it on the public subnet `vpc-pubsub-1a`
- (Optional) For production best practice, deploy another NAT gateway and associate it on public subnet `vpc-pubsub-1b` 

## Routing Table

**Public Subnet Routing Table**   
| Destination | Target |   
|-------------|--------|
| 0.0.0.0/0   | IGW    |
| 10.0.0.0/16 | Local  |

- Route table name `my-rtb-public`
- Subnet associations `vpc-pubsub-1a`,`vpc-pubsub-1b`

**Private Subnet Routing Table**  
| Destination | Target |   
|-------------|--------|
| 0.0.0.0/0   | NATGW  |
| 10.0.0.0/16 | Local  |    

- Route table name `my-rtb-private1`
- Subnet associations `vpc-AD-privsub-1a`,`vpc-AD-privsub-1b`,`vpc-DB-privsub-1a`,`vpc-DB-privsub-1b`


## Security Group Rules
Create a security group and assign this to both your SQL Nodes (SQL1,SQL2)  
Assign the following protocol and ports below

| Protocol | Port(s)      | Direction | Purpose                     |
|----------|--------------|-----------|-----------------------------|
| ICMP     | All          | Inbound   | Ping                        |
| TCP      | 135          | Inbound   | RPC Endpoint Mapper         |
| TCP      | 3343         | Inbound   | Cluster Communication       |
| TCP      | 445          | Inbound   | SMB                         |
| TCP      | 1433         | Inbound   | SQL Server Default Port     |
| TCP      | 5022         | Inbound   | SQL AG Endpoint (reserved)  |
| TCP      | 1024–65535   | Inbound   | RPC Dynamic Ports           |



## Active Directory Services
This is optional, it depends on your access and company policies, 
you can either join your resources to your current domain controllers or create
a new one. In my case, to completely isolate the resources from our production environment, I deployed the domain controller using AWS Directory Services in a separate AWS account and region to ensure full isolation from our production environment.    
**Note:** Deploy your domain controller in the Private subnet, in different AZ's `vpc-AD-privsub-1a`,`vpc-AD-privsub-1b`

### User accounts
Once your domain controller is ready, create the following Windows users accounts to be used to login to your SQL nodes and Microsoft SQL Server application.

- **SQL Service account**, assign this account as a service account on both SQL nodes.
- **SQL Administrator account**, grant this account a local administrator role in both your SQL nodes and also add this as Systems Administator on your SQL Server.

## Bastion Server Setup     
- Launch an EC2 instance `t3.xlarge` on the Public subnet `vpc-pubsub-1a`
- You can install any Windows Server versions as long as it can handle multiple remote connections
- (Optional) for high availability setup in production environment, deploy a second EC2 instance on another public subnet `vpc-pubsub-1b`


## SQL Servers Setup
- Launch an EC2 instance on each Availability zone `us-east-1a` and `us-east-1b` Private subnet.
- Instance type `R5.xlarge`
- Windows Server 2019 DataCenter and SQL Server 2019 Enterprise Edition (I used this AMI: **`ami-00307dc167da19510`** for youre reference) 
- (Optional) Create additional 3 EBS volumes and attach it on each nodes for separation of datafiles, logfiles and tempfiles.
- Assign a security group in both nodes having the rules layout above.


## Assign Additional IPs
- From the EC2 dashboard select one of the SQL nodes (SQL1)
- Click the Networking tab and scroll down to the Network interfaces
- Click the Interface-ID `(ex. eni-0933ad4968a56ea42)`
- Click Actions and Manage IP addresses
- Expand the eth0 and add 2 IP addresss (one cluster IP and Listener IP) refer to the IP assignments above.
- Once added, click Save.
- Do the same to the other SQL node (SQL2)


## Configure Bastion and SQL Servers
- Login to your bastion server via rdp, install Remote desktop manager of your choice for ease of administration (I recommend Devolutions remote desktop manager)  
  **NOTE:** Do not join your bastion server to domain controller.
- From your bastion server you can access your SQL Nodes via remote desktop manager.
- Setup your SQL Administration account as local administrator on both nodes.
- Setup your SQL Server account as SQL Service on both nodes via the configuration manager.
- Create a database, or restore a database on your SQL1 node server. (You can use the AdventureWorks2019 database for testing).
- **NOTE:** Do not create or restore a database on your SQL2 node server.
- Install Administration tools like (Active Directory Users and Computers, DNS, etc.) on both nodes.


## Failover Cluster Setup

Here’s where the fun starts! 

- Install the **Failover Clustering** feature on both SQL nodes.
- Open the Failover Cluster Manager using your domain controller admin account (right click run as different user).
- Assign **secondary IPs** use the cluster IPs assigned to SQL nodes.
- Create the cluster using `New-Cluster` via PowerShell or gui.
- Verify DNS resolution and cluster name entries if they are properly registered.
- Open required firewall ports: `135`, `3343`, `445`, `1433`, `5022`. (check security groups and verify Windows firewall)
- Verify if your cluster is running as expected. Ran **Test-Cluster** — should pass with flying colors (0 errors).
- Performed both **manual and forced failovers** — should work like a charm.


## Always On AG Configuration

The Always On AG setup was configured with care:

- Enabled the **Always On Availability Group** feature in SQL Server Configuration Manager.
- Set the `TestDB` or `AdventureWorks2019` to **FULL recovery mode**, then performed full and log backups.
- Created an AG named `AG-RCX-SQL` via SSMS wizard.
- Added `SQL2` as a **synchronous replica** with **automatic failover**.
- Configured a **static listener**: `LISTENER-RCX-SQL` with multi-subnet IPs.
- Verified failover using both **T-SQL** and SSMS — all good.

---

## Listener Connection Tests

Verified listener connection using both command line and GUI:

```bash
sqlcmd -S LISTENER-RCX-SQL.rcx-dba.com -d TestDB -E -M A
```

```text
SSMS Connection:
Server Name: LISTENER-RCX-SQL.rcx-dba.com
Options: MultiSubnetFailover = True
```

✅ Both connections worked flawlessly no matter which node was primary.

---

## 🧪 Test Procedures

A full checklist of what I tested (and passed ✅):

### Test 1: Manual Cluster Failover via FCM
- **Action:** Move cluster resources from SQL1 to SQL2.
- **Result:** Cluster name and IP go active on SQL2.

### Test 2: PowerShell Cluster Failover
- **Command:**  
  ```powershell
  Stop-ClusterNode -Name SQL1 -Force
  ```
- **Result:** SQL2 becomes cluster owner, services stay online.

### Test 3: Cluster DNS Resolution
- **Command:**  
  ```bash
  nslookup CL-RCX-SQL.rcx-dba.com
  ```
- **Result:** Resolves to current active cluster IP.

### Test 4: AG Failover using SSMS
- **Action:** Manual failover from SQL1 to SQL2 in SSMS.
- **Result:** `TestDB` becomes primary on SQL2; no connection drop.

### Test 5: AG Failover using T-SQL
- **Command:**  
  ```sql
  ALTER AVAILABILITY GROUP [AG-RCX-SQL] FAILOVER;
  ```
- **Result:** Successful failover; sync state healthy.

### Test 6: Listener Connection Validation
- **Action:** Connect using SSMS or sqlcmd to `LISTENER-RCX-SQL.rcx-dba.com`
- **Result:** Seamless connection regardless of current primary.

### Test 7: WMI Check (RPC/DCOM)
- **Command:**
  ```powershell
  Get-WmiObject Win32_OperatingSystem -ComputerName SQL2
  ```
- **Result:** Successfully retrieves system info — RPC connectivity confirmed.

---

## 🙌 Final Thoughts

This setup wasn’t easy — but it was worth every bit of troubleshooting.

If you're planning to do this:
👉 **Start with solid network design.**  
Your subnets, IPs, DNS, and routes will make or break your cluster setup. (Trust me, I rebuilt my VPC more times than I can count 😅)

But once everything clicks into place… it’s pure magic. You now have enterprise-grade high availability, fully running in your AWS lab — and best of all, you built it from scratch.

---

*Built and documented by James Santos — Cloud Architect, SQL Whisperer, Night Owl*

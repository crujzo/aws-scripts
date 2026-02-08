# 📘 README – Mandatory AWS-Side Configuration for NAT Instance

This document describes the **AWS configuration steps that MUST be completed outside the NAT instance setup script** for the NAT instance to function correctly.

> ⚠️ These settings are **mandatory**.  
> Skipping any of them will result in **partial or complete network failure** for private subnets.

---

## 1️⃣ Disable Source/Destination Check (CRITICAL)

By default, EC2 instances drop traffic that is **not addressed to themselves**.  
A NAT instance **must forward traffic for other instances**, so this check must be disabled.

### Verify
```bash
aws ec2 describe-instances \
  --instance-ids <NAT_INSTANCE_ID> \
  --query 'Reservations[0].Instances[0].SourceDestCheck'
```

Expected:
```
false
```

### Disable
```bash
aws ec2 modify-instance-attribute \
  --instance-id <NAT_INSTANCE_ID> \
  --no-source-dest-check
```

---

## 2️⃣ Attach a Public IPv4 Address

The NAT instance **must have internet reachability**.

Ensure **one of the following**:
- An **Elastic IP** is attached (recommended)
- OR an auto-assigned public IPv4 address exists

### Verify
```bash
aws ec2 describe-instances \
  --instance-ids <NAT_INSTANCE_ID> \
  --query 'Reservations[0].Instances[0].PublicIpAddress'
```

---

## 3️⃣ Place NAT Instance in a Public Subnet

The subnet containing the NAT instance **must have a route to an Internet Gateway**.

### Required route
```
0.0.0.0/0 → igw-xxxxxxxx
```

---

## 4️⃣ Configure Private Subnet Route Table (MOST IMPORTANT)

All outbound internet traffic from **private subnets** must be routed to the NAT instance.

### Required route
```
Destination: 0.0.0.0/0
Target:      <NAT_INSTANCE_PRIMARY_ENI>
```

⚠️ **Do NOT point this route to an Internet Gateway.**

---

## 5️⃣ Security Group Configuration

### NAT Instance Security Group

Inbound:
```
Source: <VPC CIDR>
All traffic
```

Outbound:
```
0.0.0.0/0
All traffic
```

---

### Private Instance Security Group

Outbound (minimum):
```
TCP 443 → 0.0.0.0/0
TCP 1024–65535 → 0.0.0.0/0
```

---

## 6️⃣ Network ACLs (NACLs)

Ensure NACLs **do not block traffic**.

Recommended:
```
Inbound  : ALLOW ALL
Outbound : ALLOW ALL
```

---

## 7️⃣ IAM Role (Optional but Recommended)

Attach:
- AmazonSSMManagedInstanceCore

Benefits:
- Session Manager access
- No SSH required
- Easier debugging

---

## 8️⃣ Post-Deployment Validation

From a **private instance**:
```bash
curl https://api.ipify.org
curl https://ssm.ap-south-1.amazonaws.com
```

From the **NAT instance**:
```bash
iptables -t nat -L POSTROUTING -n -v
```

Expected:
- Packet counters increase
- Internet access works
- SSM shows **Online**

---

## ✅ Final Note

> A NAT instance is simple but unforgiving.  
> AWS-side plumbing **must be correct** before Linux-side NAT can work.

Once configured correctly, this setup is **stable, cost-efficient, and production-safe**.

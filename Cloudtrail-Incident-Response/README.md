# Cloud Security Incident Response: Compromised IAM Credentials & Perimeter Hardening

## Executive Summary
This project simulates a realistic cloud environment breach involving an exposed network perimeter and leaked high-privilege Identity and Access Management (IAM) API keys. Acting as both the threat actor and the SOC Analyst, I deployed a vulnerable virtual machine, executed an attack sequence, used **AWS CloudTrail** logs to perform threat triage, isolated the attacker's source IP address, and successfully executed containment and remediation playbook procedures.

---

## 🛠 Environments & Tools Used
*   **Cloud Platform:** Amazon Web Services (AWS)
*   **Core Services:** EC2, IAM, CloudTrail, Amazon S3
*   **Endpoint Interface:** Windows PowerShell / AWS Command Line Interface (CLI)
*   **Framework Alignment:** MITRE ATT&CK Matrix (Reconnaissance, Initial Access)

---

## 🛡 Phase 1: Environment Provisioning & Security Baseline

To ensure all actions within the environment were thoroughly monitored, a global security audit stream was established prior to launching any infrastructure.

1. **Audit Trail Configuration:** Created a multi-region trail named `Security-Audit-Trail` configured to drop management events into a dedicated, globally unique S3 logging bucket (`security-incident-response-logs-tchamchoum`).
2. **Target Deployment:** Launched a standard Amazon Linux EC2 instance named `Vulnerable-Public-Server`. 
3. **Intentional Misconfiguration:** To simulate a common developer oversight (Shadow IT), the instance's security group (`Insecure-SG`) was provisioned with inbound rule **Port 22 (SSH) open to Anywhere (0.0.0.0/0)**.

![CloudTrail Configuration](screenshots/01_cloudtrail_logging.png)  
*Figure 1: Verification of CloudTrail audit logging status pointing to secure S3 storage.*

![Vulnerable Security Group](screenshots/02_vulnerable_security_group.png)  
*Figure 2: Production firewall misconfiguration showing SSH accessible to the public internet.*

---

## 💥 Phase 2: Threat Simulation (The Attack Vector)

### Vector 1: Perimeter Network Scanning & Brute Force
Using a local endpoint terminal outside the AWS cloud network, a connection request was initiated targeting the exposed public IP address (`3.27.129.97`). Multiple connection attempts were made to simulate public-facing network brute-forcing.

```bash
ssh malicious_actor@3.27.129.97
```

![SSH Attack Connection](screenshots/03_ssh_brute_force_attack.png)  
*Figure 3: Target instance dropping unauthorized external authentication requests.*

### Vector 2: Credential Compromise & Infrastructure Reconnaissance
To simulate a credential leak (e.g., keys accidentally pushed to a public codebase), an IAM user profile `compromised-developer-key` was created with `AdministratorAccess`. Access keys were generated and bound locally to the attacker terminal.

![Access Key Provisioning](screenshots/04_compromised_api_keys.png)  
*Figure 4: Generation of high-privilege cloud API programmatic keys.*

The attacker then executed active cloud reconnaissance commands to enumerate user directories and scan for data stores across the tenant:

```powershell
aws iam list-users
```

![Attacker Recon Output](screenshots/05_attacker_recon_terminal.png)  
*Figure 5: Local command-line execution mapping out internal cloud identity structures.*

---

## 🔍 Phase 3: Detection, Log Analysis & Triage

Pivoting to the role of an Incident Responder, a forensic investigation was performed inside the AWS audit trail console.

### Key Architectural Lesson Learned
*   **The Global Service Routing Rule:** While infrastructure commands were directed at the Sydney (`ap-southeast-2`) endpoints, AWS architecturally routes all identity control-plane logs (IAM service requests) exclusively to the **US East (N. Virginia) `us-east-1`** region registry. Triage filters had to be shifted globally to capture the activity.

Filtering by Event Name for `ListUsers`, the precise footprint of the compromise was extracted from the raw JSON log entry:

```json
{
  "eventVersion": "1.11",
  "userIdentity": {
    "type": "IAMUser",
    "principalId": "AIDA4UF6J6TZA7WTDI5A6",
    "arn": "arn:aws:iam::867982505202:user/compromised-developer-key",
    "accountId": "867982505202",
    "accessKeyId": "AKIA4UF6J6TZHVRVG2AQ",
    "userName": "compromised-developer-key"
  },
  "eventTime": "2026-10-09T12:50:27Z",
  "eventSource": "://amazonaws.com",
  "eventName": "ListUsers",
  "awsRegion": "us-east-1",
  "sourceIPAddress": "203.164.231.56",
  "readOnly": true
}
```

![CloudTrail Analysis](screenshots/06_cloudtrail_listusers_log.png)  
*Figure 6: Expanded CloudTrail JSON log identifying the specific hijacked key and the malicious source IP.*

---

## 🛑 Phase 4: Threat Containment & Remediation Playbook

Following standard Incident Response frameworks, containment actions were taken immediately upon confirming unauthorized programmatic access.

1. **Identity Neutralization:** Navigated to the compromised user profile, immediately revoked, **deactivated, and permanently deleted** the leaked Access Keys to terminate the attacker's CLI session token.
2. **Network Hardening:** Modified the EC2 `Insecure-SG` security group to delete the public `0.0.0.0/0` rule, restricting SSH access solely to trusted bastion systems.

![Remediation Success](screenshots/07_remediation_keys_deleted.png)  
*Figure 7: Complete containment of identity compromise via key demolition.*

---

## 🧠 Strategic Lessons & Defensive Recommendations

To prevent future compromise occurrences within an enterprise environment, the following engineering guardrails are highly recommended:
*   **Enforce Principle of Least Privilege (PoLP):** Developers should never possess standing full administrative access keys; use scoped IAM Roles with temporary Session Tokens.
*   **Deploy Secrets Scanning Automation:** Implement automated scanning tools (like AWS CodeGuru or GitGuardian) inside code repositories to detect and block secret string leaks before commits are pushed.
*   **Enable Automated Anomaly Detection:** Configure **AWS GuardDuty** to monitor CloudTrail streams and automatically flag or auto-remediate unusual API requests originating from unexpected geographic locations or unrecognized source IPs.

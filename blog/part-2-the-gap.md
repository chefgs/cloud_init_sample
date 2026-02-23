# Part 2: 10 Years of Tool Evolution — What Aged, and Why It Matters

*Series: Modernizing a Cloud-Init Repo — from 2012 Shell Scripts to Production-Grade IaC*

---

In Part 1, I showed what a 2012 cloud provisioning repo got right. Cattle-style instances, config-as-code, decoupled orchestration, tag-based lifecycle. The concepts were solid.

But concepts and implementation are different things.

This part is about the implementation — specifically, the parts that haven't aged well and why each one matters. This isn't about criticizing old code. It's about understanding *why* the tooling evolved, because that understanding is what helps you make good decisions going forward.

---

## Problem 1: The AMI ID Is Hardcoded

```bash
aws ec2 run-instances --image-id ami-28e07e50 ...
```

`ami-28e07e50` is a RHEL 7 AMI. Region-specific (us-east-1 only). And RHEL 7 reached end-of-life in **June 2024**.

If you cloned this repo today and ran it, you'd get one of two things: an error because the AMI doesn't exist in your region, or a running instance on an unpatched, EOL operating system with known vulnerabilities.

Hardcoded AMI IDs are a maintenance time bomb. They require manual tracking and updating, they don't travel across regions, and they don't automatically reflect when the base OS vendor drops security support.

**What this teaches:** AMI resolution should be dynamic, not static. Your tooling should look up the latest, patched version of your base OS at deploy time — not at the time you last edited the script.

---

## Problem 2: Bash User-Data Is a Bash Script

```bash
# cloud_init_chef.txt
yum install -y git ruby
gem install chef --no-rdoc --no-ri
git clone https://github.com/chefgs/cloud_init.git /opt/chef-repo
chef-client --local-mode --runlist 'recipe[cloud_init]'
```

This works. But it's bash, which means:

- **No idempotency guarantee.** If this script runs twice (cloud-init re-runs on certain instance events), `gem install` will try to install an already-installed gem. Fine until it isn't.
- **No distro portability.** `yum` breaks on Ubuntu. The script is RHEL-specific and doesn't declare that.
- **No validation.** There's no way to lint or validate this before it runs on a live instance. You find out it's broken when the instance fails to boot correctly.
- **Error handling is manual.** Bash scripts fail silently unless you add `set -e` and `set -o pipefail` throughout.

Cloud-init has a proper YAML format — called `#cloud-config` — that handles packages, users, files, and commands through tested, cross-distro modules. The shell script approach bypasses all of that in favor of raw bash.

**What this teaches:** Use the right abstraction layer. cloud-init's YAML modules exist precisely so you don't have to write bash for common operations like installing packages or creating users.

---

## Problem 3: SSH Keys and Open Port 22

```bash
# The script requires these at invocation time
./create_instance.sh 1 rhel_sg_rule myaws_key chef
#                         ^^^^^^^^^^ ^^^^^^^^^
#                         SG with     Key pair
#                         port 22     for SSH
```

The workflow assumes you have an SSH key pair and a security group with port 22 open. This was standard in 2012. It's a risk pattern today.

Here's why:
- **Key pair management is a liability.** Private keys get shared, backed up in wrong places, forgotten about. Rotating them across a fleet is painful.
- **Port 22 open to the internet** is one of the most scanned and targeted attack surfaces on the internet. Any EC2 instance with 0.0.0.0/0 on port 22 will see brute-force attempts within minutes of launch.
- **No audit trail.** SSH access doesn't automatically log *who* connected, *what* they did, or *when*. You need to set that up separately.

AWS SSM Session Manager was introduced in 2018. It lets you access instances through the AWS control plane — no open ports, no key pairs, full CloudTrail audit log. There's no meaningful argument for keeping port 22 open on managed instances in 2025.

**What this teaches:** Access patterns should use the principle of least privilege from the network layer up. Zero open inbound ports is not just achievable — it's the right default.

---

## Problem 4: No State Tracking

```bash
# create_instance.sh — runs, exits, forgets
aws ec2 run-instances --image-id ami-28e07e50 ...

# terminate_instances.sh — finds by tag, deletes
aws ec2 terminate-instances ...
```

The original approach has no memory. If you run `create_instance.sh` five times, you get five sets of instances — and no record of any of them in the script itself. Cleanup depends on the tag being set correctly. If you ran with different tags, or in different regions, you've got orphaned instances you might not know about.

There's also no concept of a "plan before apply." The script runs, instances are created. If you made a mistake — wrong instance type, wrong security group — you find out after the fact.

**What this teaches:** Infrastructure tooling should track what it created, show you what *will* change before changing it, and reconcile desired state with actual state. This is exactly what Terraform's state file and `plan` command give you.

---

## Problem 5: Every Instance Bootstraps From Scratch

```bash
# Every instance at boot:
yum install -y git ruby
gem install chef --no-rdoc --no-ri    # ~2-3 minutes
git clone https://github.com/...      # network call
chef-client ...                        # another few minutes
```

Every single new instance repeats this sequence: download Chef, download dependencies, clone a repo, run Chef. On a good day this takes 5-7 minutes per instance. On a bad day — if GitHub is slow, if the gem server is flaky, if your repo is large — you could be waiting much longer. And if any of those external dependencies are unavailable, your instances don't configure correctly.

This runtime dependency on external services is fragile. It means the state of your infrastructure at boot depends on services you don't control.

**What this teaches:** Configuration should be baked into the AMI at build time, not downloaded at runtime. Tools like Packer let you build a "golden AMI" with everything pre-installed and tested. Instances launch in seconds instead of minutes, with no runtime network dependencies.

---

## Problem 6: Secrets and Config Are Hardcoded or Positional

```bash
./create_instance.sh 1 rhel_sg_rule myaws_key chef
```

Configuration is passed as positional arguments. There's no secrets management, no parameter validation, no defaults documented anywhere except the comment block at the top of the script. If you pass arguments in the wrong order, the script may silently proceed with the wrong values.

For a demo repo, that's fine. For a team where multiple people run this, it's a support burden. And any sensitive values that ended up hardcoded in those cloud-init scripts would be visible in the EC2 console's instance metadata — a well-known data exposure path.

**What this teaches:** Parameters should be typed, validated, and documented. Secrets should never appear in user-data, scripts, or logs — they should be fetched at runtime from a managed service (AWS Secrets Manager, SSM Parameter Store).

---

## Problem 7: No CI/CD — Everything Is Manual

The whole workflow is: clone repo, run script, wait, check. There's no automated validation, no plan review, no approval step, no audit of who ran what and when.

At personal project scale, that's workable. At team scale — especially once you're touching production — it breaks down. You want infrastructure changes to go through the same code review process as application changes. You want a record of every change. You want safeguards against someone running a script against the wrong account.

**What this teaches:** Infrastructure changes should flow through a pipeline — lint, validate, plan, review, apply. The same discipline you'd apply to a software release.

---

## The Summary Table

| Original approach | Problem | Modern equivalent |
|---|---|---|
| Hardcoded `ami-28e07e50` (RHEL 7 EOL) | Stale, region-locked, unpatched OS | Dynamic AMI data source (Amazon Linux 2023) |
| Bash user-data script | No idempotency, no validation, RHEL-only | `#cloud-config` YAML with built-in modules |
| SSH key pairs + port 22 open | Key sprawl, attack surface, no audit trail | IAM Instance Profile + SSM Session Manager |
| Stateless bash script | No plan, no state, orphaned resources | Terraform with state file + `plan` command |
| Runtime Chef/Ansible download at boot | Slow, fragile, external dependencies | Packer-baked AMI; cloud-config handles only final config |
| Positional bash args | No validation, no secrets management | `variables.tf` + SSM Parameter Store |
| Manual script execution | No review, no audit, no pipeline | GitHub Actions with OIDC + plan/apply workflow |

---

## What Didn't Change

Worth saying clearly: Chef and Ansible are still valid. The config management tools themselves have aged well — they're on major new versions (Chef 18+, Ansible 9+) and are still widely used in production. The patterns they established (desired state, idempotent resource management) are the same ones Kubernetes and Terraform operators use today.

The *concepts* in the original repo are still the right concepts. The *implementation layer* needed the upgrade.

---

## What's Next

Part 3 is where we put it all together — the full modernized stack, working code, and a phased migration path you can actually use.

**Part 3: The Modern Rebuild — Terraform, cloud-config YAML, SSM, and GitHub Actions →**

---

*The original repo: [github.com/chefgs/cloud_init_sample](https://github.com/chefgs/cloud_init_sample)*
*The modernized code is in the `/modern` directory of the same repo*

---
`#DevOps` `#AWS` `#InfrastructureAsCode` `#CloudSecurity` `#Terraform` `#CloudInit` `#IaC` `#CloudEngineering`

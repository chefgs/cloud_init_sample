# Part 1: I Wrote This in 2012. Here's What It Got Right.

*Series: Modernizing a Cloud-Init Repo — from 2012 Shell Scripts to Production-Grade IaC*

---

Back in 2012, I was working on a problem that most teams hadn't fully named yet: how do you provision a bunch of identical EC2 instances, reliably, without doing it by hand every single time?

There was no Terraform. No AWS CDK. No Launch Templates. CloudFormation existed but felt like writing XML for a living.

So I wrote a shell script.

---

## What the Repo Does

The idea was simple. You want 10 EC2 instances — all identical, all configured the same way. You shouldn't have to click through the console 10 times or run 10 slightly different commands. You should run one script and walk away.

```bash
./create_instance.sh 5 rhel_sg_rule myaws_key chef
```

That one command would:
- Spin up 5 RHEL 7 EC2 instances via AWS CLI
- Pass a `cloud-init` script as `user-data` to each one
- That script would install Chef or Ansible (your choice), clone the config repo from GitHub, and run it
- Each instance would come up fully configured — hostname set, monitoring agent installed, users created, all of it

When you were done, one more script to clean up:

```bash
./terminate_instances.sh
```

That's it. No console. No manual steps. Repeatable every time.

---

## The Core Idea: Cattle, Not Pets

The term "cattle vs pets" wasn't mainstream yet in 2012, but the pattern was already the right one.

**Pet** servers are ones you name, maintain, SSH into, patch carefully, and worry about. If one dies, it's a problem.

**Cattle** servers are identical, disposable, and replaceable. If one dies, you spin up another one. You don't fix it — you replace it.

The whole repo was built around this idea. The `DEMO` tag applied to every instance meant you could find them all, track them, and terminate them in one shot. Config was not stored on the machine — it lived in Git and was applied at boot. No snowflake servers.

This was the right mental model. It still is.

---

## How cloud-init Fit In

`cloud-init` is the piece most people overlook. It's the system that runs when a cloud instance first boots — before you can even SSH into it.

The repo used it as a bootstrap mechanism: pass a shell script as `user-data`, and cloud-init executes it on first boot. That script installs your config management tool (Chef or Ansible), pulls your config from GitHub, and runs it.

```bash
# cloud_init_chef.txt — simplified
yum install -y git ruby
gem install chef --no-rdoc --no-ri
git clone https://github.com/chefgs/cloud_init.git /opt/chef-repo
chef-client --local-mode --runlist 'recipe[cloud_init]'
```

The key decision here was using cloud-init as the *delivery mechanism* and Chef/Ansible as the *configuration engine*. Separation of concerns, even then.

---

## What Was Genuinely Ahead of Its Time

Looking back at this code with 2025 eyes, a few things stand out as architecturally correct:

**1. Config-as-Code from day one.** All instance configuration lived in Git — the Chef cookbook, the Ansible playbook, the cloud-init script. Nothing was set by hand.

**2. Idempotent provisioning.** The same script could be run repeatedly. Terminate all instances, run the script again — same result every time.

**3. Decoupled orchestration from configuration.** `create_instance.sh` handles *launching* instances. `cloud_init_chef.txt` handles *configuring* them. Swapping between Chef and Ansible required changing one argument, not rewriting the script.

**4. Local-mode Chef.** No Chef Server needed. Chef ran in `--local-mode` (Chef Zero), which eliminated a whole category of infrastructure dependency. That's still a valid pattern today.

**5. Tag-based lifecycle.** Every instance got tagged with `DEMO`. Cleanup was one script that found instances by tag and terminated them. This is exactly how AWS Resource Groups work today.

---

## The Stack in 2012

| Layer | Tool |
|---|---|
| Cloud API | AWS CLI (`aws ec2 run-instances`) |
| Instance bootstrap | cloud-init (shell script as user-data) |
| Configuration management | Chef 14 or Ansible |
| Source control | GitHub |
| OS | RHEL 7 |
| Instance type | t2.micro |

---

## What This Taught

The patterns in this repo became mainstream. Immutable infrastructure, GitOps, infrastructure-as-code, cattle provisioning — all of these are now the default way serious teams operate. In 2012, putting this together took deliberate effort and real architectural thinking.

The concepts were right. The tools were the best available at the time.

But 13 years have passed, and the implementation has aged. The AMI ID is for a region that may not match yours. RHEL 7 reached end-of-life in June 2024. The script has no state tracking — if something fails halfway through, you're debugging manually. SSH keys and port 22 open in the security group is a risk pattern we've learned to eliminate.

---

## What's Next

In Part 2, I'll walk through exactly what aged poorly in this repo — not to criticize the original work, but because understanding *why* things changed is how you make better decisions the next time around.

The shell scripting approach isn't wrong. It's just that we now have better tools for every layer of this stack, and the gaps matter at production scale.

**Part 2: The Gap — 10 Years of Tool Evolution and Why the Implementation Needs a Rebuild →**

---

*The original repo: [github.com/chefgs/cloud_init_sample](https://github.com/chefgs/cloud_init_sample)*
*The modernized version: covered in Part 3*

---
`#DevOps` `#CloudInit` `#AWS` `#InfrastructureAsCode` `#CloudEngineering` `#IaC` `#Terraform` `#AWSCloud`

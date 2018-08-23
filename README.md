# Cloud Init Sample code Repo
## 1. AWS EC2 Instance creation with cloud-init script passed as user_data 
### `create_instance.sh` is the wrapper script which does the following
-  Creates 'n' number EC2 instances of type t2.micro with RHEL 7 OS <br>
-  Each instance will be having below configurations set when the instances creation is completed <br>
   - Set a hostname on operating system level <br>
   - Install a package called “my-monitoring-agent”. Assume that the package repository is already configured <br>
   - Set the hostname in the configuration of the monitoring agent. Config file located at “/etc/mon-agent/agent.conf”  <br>
   - Ensure that the two users, “alice” and “bob”, exist and are part of the group “my-staff” <br>
- Also the instances will be assigned with tag name 'DEMO', so all instances will be grouped under the tag and can be deleted easily later (if not required)

### Goal
- The script can be used to create the bulk instances, applied with similar config across all the instances. Hence achieving the goal of "Cattle" instance provisioning. <br>
- In case the instances needed to be updated with new config, We can update the new config as code in Chef recipe (push the code to git, after the change). <br>
- We can terminate all previously created instances and then can re-create the instances in bulk by simply executing the script. <br>

### Script functionality 
- `Create_instance.sh` script uses the AWS CLI command to invoke the resource creation in AWS.
- The AWS CLI command for instance creation is `aws ec2 run-instance`. 
- We are sending the Cloud-init script file to AWS CLI user-data option. It contains the bash script and is executed by `Cloud-init` process when the EC2 instance is created.
- System config could be set using different technologies like Chef or Ansible. So I've created two different Cloud-init scripts to show the possibility of using the same AWS resource creation script with config management tool passed an option (refer example [below](https://github.com/chefgs/cloud_init_sample/blob/master/README.md#script-running-procedure-from-terminal-prompt-or-gitbash)).
#### Chef way
- The `cloud_init_chef.txt` is a shell script and has the code for installing the required installers, checking out repo from git and running `Chef-client` command to set the desired VM config 
#### Ansible way
- The `cloud_init_ansible.txt` is a shell script and has the code for installing the required installers, checking out repo from git and running `ansible-playbook` command to set the desired VM config 

### Technologies used
- `AWS CLI` command for instance creation <br>
- `Cloud-init` script passed in instance creation user_data section <br>
- `bash shell` scripting used to code the `cloud-init` script <br>
- `rpm-build` used for creation of dummy rpm package <br
- `Chef` used for setting the required system state <br>
- `Ansible` also used for setting the required system state <br>
- `Github` used as source repo and git commands extensively used while development <br>
- `Chef-client` run in local-mode eliminating the need of Chef server. <br>

## 2. Instance creation steps 
### Pre-requisite Setup
- AWS CLI setup / config : <a href="https://docs.aws.amazon.com/cli/latest/userguide/installing.html">AWS CLI</a> and <a href="https://docs.aws.amazon.com/cli/latest/reference/configure/">Configure CLI</a><br>
- Install Git for Linux using the command `yum install git -y` or <br>
- <a href="https://git-scm.com/downloads">Git Bash for Windows</a> to access Git repo and to run the shell script in Windows. 

### Pre-requisite to be done in AWS
- Setup Security group rule for rhel in AWS. In-bound SG rule with SSH port 22 should be enabled.  
- Setup AWS keypair to be used for login to instance

### Script running procedure (from terminal prompt or Gitbash)
- Clone the cloud_init_sample repo : `git clone  https://github.com/chefgs/cloud_init_sample`
- cd cloud_init_sample
- Fetch the SG-rule name and key-pair name by executing the script `./get_sg_key.sh`
- Script takes the below options,
  - Instance count
  - SG rule name
  - AWS key for accessing instance
  - chef or ansible
- Example script execution command structure, `./create_instance.sh 1 rhel_sg_rule myaws_key chef` .  This command will create 1 EC2 instance of type t2.micro with RHEL OS, with desired state set using Chef <br>
- Example script execution command structure, `./create_instance.sh 1 rhel_sg_rule myaws_key ansible` .  This command will create 1 EC2 instance of type t2.micro with RHEL OS, with desired state set using Ansible <br>

## 3. Terminate Instances
- Run `./terminate_instances.sh` . This command will terminate all the instances with tag name "DEMO".

## 4. Source code repo details making this entire functionality
- I've pushed all the source code in Github, <br>
[AWS CLI instance create repo](https://github.com/chefgs/cloud_init_sample.git) <br>
[Chef cookbook repo](https://github.com/chefgs/cloud_init.git) <br>
[Dummy rpm create repo](https://github.com/chefgs/create_dummy_rpm.git) <br>

## 5. Best practices followed
- Cloud-init and Chef run outputs are captured in log to identify any script failures.
- Cloud-init output is redirected to the path `/var/log/userdata.out`
- Chef-client output is redirected to the path `/var/log/chefrun.out`
- Shell script has been coded with validation check to avoid the error scenarios
- Chef cookbook coded with below best practices,
  - Variables stored as attributes
  - Gaurd check has been added while installing RPM from local path
- Enough comment has been added in all the scripts for anyone to understand the code.
- Every source code has been preserved in Github SCM. 
- Enitre repo detail has been documented in Github readme.


## 6. Possible alternatives of Chef
- The instance desired state configuration could also be possible with Chef "kind-of" alternative technologies like Puppet or Ansible etc.
- So with the same Cloud-init script structure as a base, it can be modified to alternative Infra as code tool installation and execution.
- One such possibility is depicted in this repo with Chef and Ansible cloud-init scripts

## 7. Output details

#### Hostname set in OS and agent.conf
```
[root@cloud-init-server log]# hostname
cloud-init-server
[root@cloud-init-server log]# cat /etc/mon-agent/agent.conf
hostname="cloud-init-server"
```
#### RPM package added
```
[root@cloud-init-server log]# rpm -qa | grep monitor
my-monitoring-agent-1.0-1.noarch
```
#### Group and users added
```
[root@cloud-init-server]# cat /etc/group | grep my-staff
my-staff:x:1001:

[root@cloud-init-server]# cat /etc/passwd | grep 1001
alice:x:1001:1001::/home/alice:/bin/bash
bob:x:1002:1001::/home/bob:/bin/bash
```
#### Chef client run sets the desired config state, while the instance is created
```
[2018-08-11T02:23:17+00:00] WARN: No config file found or specified on command line, using command line options.
Starting Chef Client, version 14.3.37
[2018-08-11T02:23:19+00:00] WARN: Run List override has been provided.
[2018-08-11T02:23:19+00:00] WARN: Original Run List: []
[2018-08-11T02:23:19+00:00] WARN: Overridden Run List: [recipe[cloud_init]]
resolving cookbooks for run list: ["cloud_init"]
Synchronizing Cookbooks:
  - cloud_init (0.1.0)
Installing Cookbook Gems:
Compiling Cookbooks...
Recipe: cloud_init::default
  * hostname[cloud-init-server] action set
    * ohai[reload hostname] action nothing (skipped due to action :nothing)
    * execute[set hostname to cloud-init-server] action run
      - execute /bin/hostname cloud-init-server
    * file[/etc/hosts] action create
      - update content in file /etc/hosts from 6768ce to 4f1182
      --- /etc/hosts    2018-03-23 17:51:30.543000000 +0000
      +++ /etc/.chef-hosts20180811-1377-136lrva 2018-08-11 02:23:19.402334478 +0000
      @@ -1,4 +1,4 @@
       127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
       ::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
      -
      +172.31.25.53 cloud-init-server cloud-init-server
      - restore selinux security context
    * execute[hostnamectl set-hostname cloud-init-server] action run
      - execute hostnamectl set-hostname cloud-init-server
    * ohai[reload hostname] action reload
      - re-run ohai and merge results into node attributes

  Converging 7 resources
  * hostname[cloud-init-server] action set
    * ohai[reload hostname] action nothing (skipped due to action :nothing)
    * execute[set hostname to cloud-init-server] action run (skipped due to not_if)
    * file[/etc/hosts] action create (skipped due to not_if)
    * execute[hostnamectl set-hostname cloud-init-server] action run (skipped due to not_if)
     (up to date)
  * rpm_package[my-monitoring-agent] action install
    - install version 1.0-1 of package my-monitoring-agent
  * directory[/etc/mon-agent/] action create
    - create new directory /etc/mon-agent/
    - restore selinux security context
  * template[/etc/mon-agent/agent.conf] action create
    - create new file /etc/mon-agent/agent.conf
    - update content in file /etc/mon-agent/agent.conf from none to e38ed0
    --- /etc/mon-agent/agent.conf       2018-08-11 02:23:19.810334478 +0000
    +++ /etc/mon-agent/.chef-agent20180811-1377-5g91rv.conf     2018-08-11 02:23:19.809334478 +0000
    @@ -1 +1,2 @@
    +hostname="cloud-init-server"
    - restore selinux security context
  * group[my-staff] action create
    - create group my-staff
  * linux_user[alice] action create
    - create user alice
  * linux_user[bob] action create
    - create user bob
[2018-08-11T02:23:19+00:00] WARN: Skipping final node save because override_runlist was given

Running handlers:
Running handlers complete
Chef Client finished, 11/17 resources updated in 01 seconds

```
#### Cloud-init output log
```
[root@cloud-init-server log]# cat userdata.out
Loaded plugins: amazon-id, rhui-lb, search-disabled-repos
Resolving Dependencies
--> Running transaction check
---> Package wget.x86_64 0:1.14-15.el7_4.1 will be installed
--> Finished Dependency Resolution

Dependencies Resolved

================================================================================
 Package Arch      Version            Repository                           Size
================================================================================
Installing:
 wget    x86_64    1.14-15.el7_4.1    rhui-REGION-rhel-server-releases    547 k

Transaction Summary
================================================================================
Install  1 Package

Total download size: 547 k
Installed size: 2.0 M
Downloading packages:
Running transaction check
Running transaction test
Transaction test succeeded
Running transaction
  Installing : wget-1.14-15.el7_4.1.x86_64                                  1/1
  Verifying  : wget-1.14-15.el7_4.1.x86_64                                  1/1

Installed:
  wget.x86_64 0:1.14-15.el7_4.1

Complete!
Installing chef client
Thank you for installing Chef!
Loaded plugins: amazon-id, rhui-lb, search-disabled-repos
Resolving Dependencies
--> Running transaction check
---> Package git.x86_64 0:1.8.3.1-14.el7_5 will be installed
--> Processing Dependency: perl-Git = 1.8.3.1-14.el7_5 for package: git-1.8.3.1-14.el7_5.x86_64
--> Processing Dependency: perl >= 5.008 for package: git-1.8.3.1-14.el7_5.x86_64
--> Processing Dependency: /usr/bin/perl for package: git-1.8.3.1-14.el7_5.x86_64
--> Processing Dependency: perl(Error) for package: git-1.8.3.1-14.el7_5.x86_64
--> Processing Dependency: perl(Exporter) for package: git-1.8.3.1-14.el7_5.x86_64
--> Processing Dependency: perl(File::Basename) for package: git-1.8.3.1-14.el7_5.x86_64
--> Processing Dependency: perl(File::Copy) for package: git-1.8.3.1-14.el7_5.x86_64
--> Processing Dependency: perl(File::Find) for package: git-1.8.3.1-14.el7_5.x86_64
--> Processing Dependency: perl(File::Path) for package: git-1.8.3.1-14.el7_5.x86_64
--> Processing Dependency: perl(File::Spec) for package: git-1.8.3.1-14.el7_5.x86_64
--> Processing Dependency: perl(File::Temp) for package: git-1.8.3.1-14.el7_5.x86_64
--> Processing Dependency: perl(File::stat) for package: git-1.8.3.1-14.el7_5.x86_64
--> Processing Dependency: perl(Getopt::Long) for package: git-1.8.3.1-14.el7_5.x86_64
--> Processing Dependency: perl(Git) for package: git-1.8.3.1-14.el7_5.x86_64
--> Processing Dependency: perl(Term::ReadKey) for package: git-1.8.3.1-14.el7_5.x86_64
--> Processing Dependency: perl(lib) for package: git-1.8.3.1-14.el7_5.x86_64
--> Processing Dependency: perl(strict) for package: git-1.8.3.1-14.el7_5.x86_64
--> Processing Dependency: perl(vars) for package: git-1.8.3.1-14.el7_5.x86_64
--> Processing Dependency: perl(warnings) for package: git-1.8.3.1-14.el7_5.x86_64
--> Processing Dependency: libgnome-keyring.so.0()(64bit) for package: git-1.8.3.1-14.el7_5.x86_64
--> Running transaction check
---> Package libgnome-keyring.x86_64 0:3.12.0-1.el7 will be installed
---> Package perl.x86_64 4:5.16.3-292.el7 will be installed
--> Processing Dependency: perl-libs = 4:5.16.3-292.el7 for package: 4:perl-5.16.3-292.el7.x86_64
--> Processing Dependency: perl(Scalar::Util) >= 1.10 for package: 4:perl-5.16.3-292.el7.x86_64
--> Processing Dependency: perl(Socket) >= 1.3 for package: 4:perl-5.16.3-292.el7.x86_64
--> Processing Dependency: perl(Carp) for package: 4:perl-5.16.3-292.el7.x86_64
--> Processing Dependency: perl(Filter::Util::Call) for package: 4:perl-5.16.3-292.el7.x86_64
--> Processing Dependency: perl(Pod::Simple::Search) for package: 4:perl-5.16.3-292.el7.x86_64
--> Processing Dependency: perl(Pod::Simple::XHTML) for package: 4:perl-5.16.3-292.el7.x86_64
--> Processing Dependency: perl(Scalar::Util) for package: 4:perl-5.16.3-292.el7.x86_64
--> Processing Dependency: perl(Socket) for package: 4:perl-5.16.3-292.el7.x86_64
--> Processing Dependency: perl(Storable) for package: 4:perl-5.16.3-292.el7.x86_64
--> Processing Dependency: perl(Time::HiRes) for package: 4:perl-5.16.3-292.el7.x86_64
--> Processing Dependency: perl(Time::Local) for package: 4:perl-5.16.3-292.el7.x86_64
--> Processing Dependency: perl(constant) for package: 4:perl-5.16.3-292.el7.x86_64
--> Processing Dependency: perl(threads) for package: 4:perl-5.16.3-292.el7.x86_64
--> Processing Dependency: perl(threads::shared) for package: 4:perl-5.16.3-292.el7.x86_64
--> Processing Dependency: perl-libs for package: 4:perl-5.16.3-292.el7.x86_64
--> Processing Dependency: perl-macros for package: 4:perl-5.16.3-292.el7.x86_64
--> Processing Dependency: libperl.so()(64bit) for package: 4:perl-5.16.3-292.el7.x86_64
---> Package perl-Error.noarch 1:0.17020-2.el7 will be installed
---> Package perl-Exporter.noarch 0:5.68-3.el7 will be installed
---> Package perl-File-Path.noarch 0:2.09-2.el7 will be installed
---> Package perl-File-Temp.noarch 0:0.23.01-3.el7 will be installed
---> Package perl-Getopt-Long.noarch 0:2.40-3.el7 will be installed
--> Processing Dependency: perl(Pod::Usage) >= 1.14 for package: perl-Getopt-Long-2.40-3.el7.noarch
--> Processing Dependency: perl(Text::ParseWords) for package: perl-Getopt-Long-2.40-3.el7.noarch
---> Package perl-Git.noarch 0:1.8.3.1-14.el7_5 will be installed
---> Package perl-PathTools.x86_64 0:3.40-5.el7 will be installed
---> Package perl-TermReadKey.x86_64 0:2.30-20.el7 will be installed
--> Running transaction check
---> Package perl-Carp.noarch 0:1.26-244.el7 will be installed
---> Package perl-Filter.x86_64 0:1.49-3.el7 will be installed
---> Package perl-Pod-Simple.noarch 1:3.28-4.el7 will be installed
--> Processing Dependency: perl(Pod::Escapes) >= 1.04 for package: 1:perl-Pod-Simple-3.28-4.el7.noarch
--> Processing Dependency: perl(Encode) for package: 1:perl-Pod-Simple-3.28-4.el7.noarch
---> Package perl-Pod-Usage.noarch 0:1.63-3.el7 will be installed
--> Processing Dependency: perl(Pod::Text) >= 3.15 for package: perl-Pod-Usage-1.63-3.el7.noarch
--> Processing Dependency: perl-Pod-Perldoc for package: perl-Pod-Usage-1.63-3.el7.noarch
---> Package perl-Scalar-List-Utils.x86_64 0:1.27-248.el7 will be installed
---> Package perl-Socket.x86_64 0:2.010-4.el7 will be installed
---> Package perl-Storable.x86_64 0:2.45-3.el7 will be installed
---> Package perl-Text-ParseWords.noarch 0:3.29-4.el7 will be installed
---> Package perl-Time-HiRes.x86_64 4:1.9725-3.el7 will be installed
---> Package perl-Time-Local.noarch 0:1.2300-2.el7 will be installed
---> Package perl-constant.noarch 0:1.27-2.el7 will be installed
---> Package perl-libs.x86_64 4:5.16.3-292.el7 will be installed
---> Package perl-macros.x86_64 4:5.16.3-292.el7 will be installed
---> Package perl-threads.x86_64 0:1.87-4.el7 will be installed
---> Package perl-threads-shared.x86_64 0:1.43-6.el7 will be installed
--> Running transaction check
---> Package perl-Encode.x86_64 0:2.51-7.el7 will be installed
---> Package perl-Pod-Escapes.noarch 1:1.04-292.el7 will be installed
---> Package perl-Pod-Perldoc.noarch 0:3.20-4.el7 will be installed
--> Processing Dependency: perl(HTTP::Tiny) for package: perl-Pod-Perldoc-3.20-4.el7.noarch
--> Processing Dependency: perl(parent) for package: perl-Pod-Perldoc-3.20-4.el7.noarch
---> Package perl-podlators.noarch 0:2.5.1-3.el7 will be installed
--> Running transaction check
---> Package perl-HTTP-Tiny.noarch 0:0.033-3.el7 will be installed
---> Package perl-parent.noarch 1:0.225-244.el7 will be installed
--> Finished Dependency Resolution

Dependencies Resolved

================================================================================
 Package         Arch   Version          Repository                        Size
================================================================================
Installing:
 git             x86_64 1.8.3.1-14.el7_5 rhui-REGION-rhel-server-releases 4.4 M
Installing for dependencies:
 libgnome-keyring
                 x86_64 3.12.0-1.el7     rhui-REGION-rhel-server-releases 110 k
 perl            x86_64 4:5.16.3-292.el7 rhui-REGION-rhel-server-releases 8.0 M
 perl-Carp       noarch 1.26-244.el7     rhui-REGION-rhel-server-releases  19 k
 perl-Encode     x86_64 2.51-7.el7       rhui-REGION-rhel-server-releases 1.5 M
 perl-Error      noarch 1:0.17020-2.el7  rhui-REGION-rhel-server-releases  32 k
 perl-Exporter   noarch 5.68-3.el7       rhui-REGION-rhel-server-releases  28 k
 perl-File-Path  noarch 2.09-2.el7       rhui-REGION-rhel-server-releases  27 k
 perl-File-Temp  noarch 0.23.01-3.el7    rhui-REGION-rhel-server-releases  56 k
 perl-Filter     x86_64 1.49-3.el7       rhui-REGION-rhel-server-releases  76 k
 perl-Getopt-Long
                 noarch 2.40-3.el7       rhui-REGION-rhel-server-releases  56 k
 perl-Git        noarch 1.8.3.1-14.el7_5 rhui-REGION-rhel-server-releases  54 k
 perl-HTTP-Tiny  noarch 0.033-3.el7      rhui-REGION-rhel-server-releases  38 k
 perl-PathTools  x86_64 3.40-5.el7       rhui-REGION-rhel-server-releases  83 k
 perl-Pod-Escapes
                 noarch 1:1.04-292.el7   rhui-REGION-rhel-server-releases  51 k
 perl-Pod-Perldoc
                 noarch 3.20-4.el7       rhui-REGION-rhel-server-releases  87 k
 perl-Pod-Simple noarch 1:3.28-4.el7     rhui-REGION-rhel-server-releases 216 k
 perl-Pod-Usage  noarch 1.63-3.el7       rhui-REGION-rhel-server-releases  27 k
 perl-Scalar-List-Utils
                 x86_64 1.27-248.el7     rhui-REGION-rhel-server-releases  36 k
 perl-Socket     x86_64 2.010-4.el7      rhui-REGION-rhel-server-releases  49 k
 perl-Storable   x86_64 2.45-3.el7       rhui-REGION-rhel-server-releases  77 k
 perl-TermReadKey
                 x86_64 2.30-20.el7      rhui-REGION-rhel-server-releases  31 k
 perl-Text-ParseWords
                 noarch 3.29-4.el7       rhui-REGION-rhel-server-releases  14 k
 perl-Time-HiRes x86_64 4:1.9725-3.el7   rhui-REGION-rhel-server-releases  45 k
 perl-Time-Local noarch 1.2300-2.el7     rhui-REGION-rhel-server-releases  24 k
 perl-constant   noarch 1.27-2.el7       rhui-REGION-rhel-server-releases  19 k
 perl-libs       x86_64 4:5.16.3-292.el7 rhui-REGION-rhel-server-releases 688 k
 perl-macros     x86_64 4:5.16.3-292.el7 rhui-REGION-rhel-server-releases  43 k
 perl-parent     noarch 1:0.225-244.el7  rhui-REGION-rhel-server-releases  12 k
 perl-podlators  noarch 2.5.1-3.el7      rhui-REGION-rhel-server-releases 112 k
 perl-threads    x86_64 1.87-4.el7       rhui-REGION-rhel-server-releases  49 k
 perl-threads-shared
                 x86_64 1.43-6.el7       rhui-REGION-rhel-server-releases  39 k

Transaction Summary
================================================================================
Install  1 Package (+31 Dependent packages)

Total download size: 16 M
Installed size: 59 M
Downloading packages:
--------------------------------------------------------------------------------
Total                                               12 MB/s |  16 MB  00:01
Running transaction check
Running transaction test
Transaction test succeeded
Running transaction
  Installing : 1:perl-parent-0.225-244.el7.noarch                          1/32
  Installing : perl-HTTP-Tiny-0.033-3.el7.noarch                           2/32
  Installing : perl-podlators-2.5.1-3.el7.noarch                           3/32
  Installing : perl-Pod-Perldoc-3.20-4.el7.noarch                          4/32
  Installing : 1:perl-Pod-Escapes-1.04-292.el7.noarch                      5/32
  Installing : perl-Text-ParseWords-3.29-4.el7.noarch                      6/32
  Installing : perl-Encode-2.51-7.el7.x86_64                               7/32
  Installing : perl-Pod-Usage-1.63-3.el7.noarch                            8/32
  Installing : 4:perl-macros-5.16.3-292.el7.x86_64                         9/32
  Installing : 4:perl-libs-5.16.3-292.el7.x86_64                          10/32
  Installing : perl-Storable-2.45-3.el7.x86_64                            11/32
  Installing : perl-Exporter-5.68-3.el7.noarch                            12/32
  Installing : perl-constant-1.27-2.el7.noarch                            13/32
  Installing : perl-Time-Local-1.2300-2.el7.noarch                        14/32
  Installing : perl-Socket-2.010-4.el7.x86_64                             15/32
  Installing : perl-Carp-1.26-244.el7.noarch                              16/32
  Installing : 4:perl-Time-HiRes-1.9725-3.el7.x86_64                      17/32
  Installing : perl-PathTools-3.40-5.el7.x86_64                           18/32
  Installing : perl-Scalar-List-Utils-1.27-248.el7.x86_64                 19/32
  Installing : perl-File-Temp-0.23.01-3.el7.noarch                        20/32
  Installing : perl-File-Path-2.09-2.el7.noarch                           21/32
  Installing : perl-threads-shared-1.43-6.el7.x86_64                      22/32
  Installing : perl-threads-1.87-4.el7.x86_64                             23/32
  Installing : perl-Filter-1.49-3.el7.x86_64                              24/32
  Installing : 1:perl-Pod-Simple-3.28-4.el7.noarch                        25/32
  Installing : perl-Getopt-Long-2.40-3.el7.noarch                         26/32
  Installing : 4:perl-5.16.3-292.el7.x86_64                               27/32
  Installing : 1:perl-Error-0.17020-2.el7.noarch                          28/32
  Installing : perl-TermReadKey-2.30-20.el7.x86_64                        29/32
  Installing : libgnome-keyring-3.12.0-1.el7.x86_64                       30/32
  Installing : perl-Git-1.8.3.1-14.el7_5.noarch                           31/32
  Installing : git-1.8.3.1-14.el7_5.x86_64                                32/32
  Verifying  : perl-HTTP-Tiny-0.033-3.el7.noarch                           1/32
  Verifying  : libgnome-keyring-3.12.0-1.el7.x86_64                        2/32
  Verifying  : perl-threads-shared-1.43-6.el7.x86_64                       3/32
  Verifying  : perl-Storable-2.45-3.el7.x86_64                             4/32
  Verifying  : perl-Exporter-5.68-3.el7.noarch                             5/32
  Verifying  : perl-constant-1.27-2.el7.noarch                             6/32
  Verifying  : perl-PathTools-3.40-5.el7.x86_64                            7/32
  Verifying  : 4:perl-macros-5.16.3-292.el7.x86_64                         8/32
  Verifying  : 1:perl-parent-0.225-244.el7.noarch                          9/32
  Verifying  : 4:perl-5.16.3-292.el7.x86_64                               10/32
  Verifying  : perl-TermReadKey-2.30-20.el7.x86_64                        11/32
  Verifying  : perl-File-Temp-0.23.01-3.el7.noarch                        12/32
  Verifying  : 1:perl-Pod-Simple-3.28-4.el7.noarch                        13/32
  Verifying  : perl-Time-Local-1.2300-2.el7.noarch                        14/32
  Verifying  : 4:perl-libs-5.16.3-292.el7.x86_64                          15/32
  Verifying  : perl-Socket-2.010-4.el7.x86_64                             16/32
  Verifying  : git-1.8.3.1-14.el7_5.x86_64                                17/32
  Verifying  : perl-Carp-1.26-244.el7.noarch                              18/32
  Verifying  : 1:perl-Error-0.17020-2.el7.noarch                          19/32
  Verifying  : 4:perl-Time-HiRes-1.9725-3.el7.x86_64                      20/32
  Verifying  : perl-Scalar-List-Utils-1.27-248.el7.x86_64                 21/32
  Verifying  : 1:perl-Pod-Escapes-1.04-292.el7.noarch                     22/32
  Verifying  : perl-Pod-Usage-1.63-3.el7.noarch                           23/32
  Verifying  : perl-Git-1.8.3.1-14.el7_5.noarch                           24/32
  Verifying  : perl-Encode-2.51-7.el7.x86_64                              25/32
  Verifying  : perl-Pod-Perldoc-3.20-4.el7.noarch                         26/32
  Verifying  : perl-podlators-2.5.1-3.el7.noarch                          27/32
  Verifying  : perl-File-Path-2.09-2.el7.noarch                           28/32
  Verifying  : perl-threads-1.87-4.el7.x86_64                             29/32
  Verifying  : perl-Filter-1.49-3.el7.x86_64                              30/32
  Verifying  : perl-Getopt-Long-2.40-3.el7.noarch                         31/32
  Verifying  : perl-Text-ParseWords-3.29-4.el7.noarch                     32/32

Installed:
  git.x86_64 0:1.8.3.1-14.el7_5

Dependency Installed:
  libgnome-keyring.x86_64 0:3.12.0-1.el7
  perl.x86_64 4:5.16.3-292.el7
  perl-Carp.noarch 0:1.26-244.el7
  perl-Encode.x86_64 0:2.51-7.el7
  perl-Error.noarch 1:0.17020-2.el7
  perl-Exporter.noarch 0:5.68-3.el7
  perl-File-Path.noarch 0:2.09-2.el7
  perl-File-Temp.noarch 0:0.23.01-3.el7
  perl-Filter.x86_64 0:1.49-3.el7
  perl-Getopt-Long.noarch 0:2.40-3.el7
  perl-Git.noarch 0:1.8.3.1-14.el7_5
  perl-HTTP-Tiny.noarch 0:0.033-3.el7
  perl-PathTools.x86_64 0:3.40-5.el7
  perl-Pod-Escapes.noarch 1:1.04-292.el7
  perl-Pod-Perldoc.noarch 0:3.20-4.el7
  perl-Pod-Simple.noarch 1:3.28-4.el7
  perl-Pod-Usage.noarch 0:1.63-3.el7
  perl-Scalar-List-Utils.x86_64 0:1.27-248.el7
  perl-Socket.x86_64 0:2.010-4.el7
  perl-Storable.x86_64 0:2.45-3.el7
  perl-TermReadKey.x86_64 0:2.30-20.el7
  perl-Text-ParseWords.noarch 0:3.29-4.el7
  perl-Time-HiRes.x86_64 4:1.9725-3.el7
  perl-Time-Local.noarch 0:1.2300-2.el7
  perl-constant.noarch 0:1.27-2.el7
  perl-libs.x86_64 4:5.16.3-292.el7
  perl-macros.x86_64 4:5.16.3-292.el7
  perl-parent.noarch 1:0.225-244.el7
  perl-podlators.noarch 0:2.5.1-3.el7
  perl-threads.x86_64 0:1.87-4.el7
  perl-threads-shared.x86_64 0:1.43-6.el7

Complete!
Creating dummmy rpm
Cloning into 'create_dummy_rpm'...
Loaded plugins: amazon-id, rhui-lb, search-disabled-repos
Resolving Dependencies
--> Running transaction check
---> Package rpm-build.x86_64 0:4.11.3-32.el7 will be installed
--> Processing Dependency: elfutils >= 0.128 for package: rpm-build-4.11.3-32.el7.x86_64
--> Processing Dependency: patch >= 2.5 for package: rpm-build-4.11.3-32.el7.x86_64
--> Processing Dependency: /usr/bin/gdb-add-index for package: rpm-build-4.11.3-32.el7.x86_64
--> Processing Dependency: bzip2 for package: rpm-build-4.11.3-32.el7.x86_64
--> Processing Dependency: perl(Thread::Queue) for package: rpm-build-4.11.3-32.el7.x86_64
--> Processing Dependency: system-rpm-config for package: rpm-build-4.11.3-32.el7.x86_64
--> Processing Dependency: unzip for package: rpm-build-4.11.3-32.el7.x86_64
--> Running transaction check
---> Package bzip2.x86_64 0:1.0.6-13.el7 will be installed
---> Package elfutils.x86_64 0:0.170-4.el7 will be installed
---> Package gdb.x86_64 0:7.6.1-110.el7 will be installed
---> Package patch.x86_64 0:2.7.1-10.el7_5 will be installed
---> Package perl-Thread-Queue.noarch 0:3.02-2.el7 will be installed
---> Package redhat-rpm-config.noarch 0:9.1.0-80.el7 will be installed
--> Processing Dependency: dwz >= 0.4 for package: redhat-rpm-config-9.1.0-80.el7.noarch
--> Processing Dependency: perl-srpm-macros for package: redhat-rpm-config-9.1.0-80.el7.noarch
--> Processing Dependency: zip for package: redhat-rpm-config-9.1.0-80.el7.noarch
---> Package unzip.x86_64 0:6.0-19.el7 will be installed
--> Running transaction check
---> Package dwz.x86_64 0:0.11-3.el7 will be installed
---> Package perl-srpm-macros.noarch 0:1-8.el7 will be installed
---> Package zip.x86_64 0:3.0-11.el7 will be installed
--> Finished Dependency Resolution

Dependencies Resolved

================================================================================
 Package           Arch   Version        Repository                        Size
================================================================================
Installing:
 rpm-build         x86_64 4.11.3-32.el7  rhui-REGION-rhel-server-releases 147 k
Installing for dependencies:
 bzip2             x86_64 1.0.6-13.el7   rhui-REGION-rhel-server-releases  52 k
 dwz               x86_64 0.11-3.el7     rhui-REGION-rhel-server-releases  99 k
 elfutils          x86_64 0.170-4.el7    rhui-REGION-rhel-server-releases 282 k
 gdb               x86_64 7.6.1-110.el7  rhui-REGION-rhel-server-releases 2.4 M
 patch             x86_64 2.7.1-10.el7_5 rhui-REGION-rhel-server-releases 110 k
 perl-Thread-Queue noarch 3.02-2.el7     rhui-REGION-rhel-server-releases  17 k
 perl-srpm-macros  noarch 1-8.el7        rhui-REGION-rhel-server-releases 4.7 k
 redhat-rpm-config noarch 9.1.0-80.el7   rhui-REGION-rhel-server-releases  79 k
 unzip             x86_64 6.0-19.el7     rhui-REGION-rhel-server-releases 170 k
 zip               x86_64 3.0-11.el7     rhui-REGION-rhel-server-releases 260 k

Transaction Summary
================================================================================
Install  1 Package (+10 Dependent packages)

Total download size: 3.6 M
Installed size: 9.9 M
Downloading packages:
--------------------------------------------------------------------------------
Total                                              7.0 MB/s | 3.6 MB  00:00
Running transaction check
Running transaction test
Transaction test succeeded
Running transaction
  Installing : perl-srpm-macros-1-8.el7.noarch                             1/11
  Installing : dwz-0.11-3.el7.x86_64                                       2/11
  Installing : unzip-6.0-19.el7.x86_64                                     3/11
  Installing : patch-2.7.1-10.el7_5.x86_64                                 4/11
  Installing : gdb-7.6.1-110.el7.x86_64                                    5/11
  Installing : elfutils-0.170-4.el7.x86_64                                 6/11
  Installing : perl-Thread-Queue-3.02-2.el7.noarch                         7/11
  Installing : zip-3.0-11.el7.x86_64                                       8/11
  Installing : redhat-rpm-config-9.1.0-80.el7.noarch                       9/11
  Installing : bzip2-1.0.6-13.el7.x86_64                                  10/11
  Installing : rpm-build-4.11.3-32.el7.x86_64                             11/11
  Verifying  : bzip2-1.0.6-13.el7.x86_64                                   1/11
  Verifying  : rpm-build-4.11.3-32.el7.x86_64                              2/11
  Verifying  : zip-3.0-11.el7.x86_64                                       3/11
  Verifying  : perl-Thread-Queue-3.02-2.el7.noarch                         4/11
  Verifying  : elfutils-0.170-4.el7.x86_64                                 5/11
  Verifying  : redhat-rpm-config-9.1.0-80.el7.noarch                       6/11
  Verifying  : gdb-7.6.1-110.el7.x86_64                                    7/11
  Verifying  : patch-2.7.1-10.el7_5.x86_64                                 8/11
  Verifying  : unzip-6.0-19.el7.x86_64                                     9/11
  Verifying  : dwz-0.11-3.el7.x86_64                                      10/11
  Verifying  : perl-srpm-macros-1-8.el7.noarch                            11/11

Installed:
  rpm-build.x86_64 0:4.11.3-32.el7

Dependency Installed:
  bzip2.x86_64 0:1.0.6-13.el7         dwz.x86_64 0:0.11-3.el7
  elfutils.x86_64 0:0.170-4.el7       gdb.x86_64 0:7.6.1-110.el7
  patch.x86_64 0:2.7.1-10.el7_5       perl-Thread-Queue.noarch 0:3.02-2.el7
  perl-srpm-macros.noarch 0:1-8.el7   redhat-rpm-config.noarch 0:9.1.0-80.el7
  unzip.x86_64 0:6.0-19.el7           zip.x86_64 0:3.0-11.el7

Complete!
Processing files: my-monitoring-agent-1.0-1.noarch
Provides: my-monitoring-agent = 1.0-1
Requires(rpmlib): rpmlib(FileDigests) <= 4.6.0-1 rpmlib(PayloadFilesHavePrefix) <= 4.0-1 rpmlib(CompressedFileNames) <= 3.0.4-1
Checking for unpackaged file(s): /usr/lib/rpm/check-files /rpmbuild/BUILDROOT/my-monitoring-agent-1.0-1.x86_64
Wrote: /rpmbuild/RPMS/noarch/my-monitoring-agent-1.0-1.noarch.rpm
Executing(%clean): /bin/sh -e /var/tmp/rpm-tmp.GdiDuY
Cookbook Repo cloning
Cloning into 'cloud_init'...
Executing chef-client

```

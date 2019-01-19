# SSH-Copy-Disk
Bash scriopt that makes a backup copy of a Linode's disk over SSH, then compresses the image  
Written by Tommy Davidson


**Usage:**
```
copydisk.sh <Linode Label> <Linode Manager Username> <Datacenter>  
```
**Examples:**
```
copydisk.sh TestLinode username newark
copydisk.sh TestLinode2 username singapore
```
**Supported Platforms:**
- MacOS
- Linux

**Dependencies:**
- Bash
- [Linode CLIv4](https://www.linode.com/docs/platform/api/using-the-linode-cli/)

**Assumptions:**
- You have only one data disk in your Linode's Configuration Profile. I may update this later to account for multiple disk configurations, but I haven't considered what that will look like yet, so I don't know when.
<br>
Pretty straightforward - copies a disk over SSH by rebooting a Linode into Rescue Mode, and performing the instructions in Linode's guide on [Copying a Disk Over SSH](https://www.linode.com/docs/migrate-to-linode/disk-images/copying-a-disk-image-over-ssh). The script uses public key authentication, but sets a random root password because SSH won't let you login if a password isn't set. You don't need this password for anything, and it can be safely ignored, since it's only relevant to Rescue Mode, and is unset when the script reboots the Linode at the end, anyway.

As indicated above, this script is tested, and confirmed to work on MacOS and Linux. It requires that the Linode CLIv4 be installed in order to reboot the Linode and to place it in Rescue Mode.


**Datacenters**
- atlanta
- dallas
- fremont
- frankfurt
- london
- newark
- singapore
- tokyo2

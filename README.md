# SSH-Copy-Disk
Makes a backup copy of a Linode's disk over SSH  
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
Pretty straightforward - copies a disk over SSH by rebooting a Linode into Rescue Mode, and performing the instructions in Linode's guide on [Copying a Disk Over SSH](https://www.linode.com/docs/migrate-to-linode/disk-images/copying-a-disk-image-over-ssh). The script uses public key authentication, but sets a random root password because SSH won't let you login without one. You can ignore this password, since it is only relevant to Rescue Mode, and goes away when the script reboots at the end, anyway.

This script is tested, and confirmed to work on MacOS and Linux, and requires the [Linode CLIv4](https://www.linode.com/docs/platform/api/using-the-linode-cli/) in order to reboot the Linode and to place it in Rescue Mode.


**Datacenters**
- atlanta
- dallas
- fremont
- frankfurt
- london
- newark
- singapore
- tokyo2

#!/bin/bash

## CopyDisk.sh - Copies a Linode's SSD to a file on your local machine
## called 'linodeImage.img'

## Check to ensure that arguments were passed at the command line, and error out if not.
[[ ! "${@}" ]] && {
  echo "No arguments specified. You must specify the name of the Linode, the username for your Linode account,"
  echo "and the datacenter in which the Linode resides."
}

## We need some data in order to make this work.
Label="${1}"
UserName="${2}"
DC="${3}"
LinodeID=$(linode-cli linodes list --text | grep "\b$Label\b" | awk '{print $1}')
DiskID=$(linode-cli linodes disks-list $LinodeID --text | awk '/ext4/{print $1}')
IP=$(linode-cli linodes list --text | grep $LinodeID | awk '{print $7}')
pubkey=$(cat ~/.ssh/id_rsa.pub)

## Clear the screen before running.
clear

## Reboot the Linode specified in "${LinodeID} into Rescue Mode using the Linode CLI v4.
linode-cli linodes rescue $LinodeID --devices.sda.disk_id $DiskID

echo "Waiting for the Linode to reboot into Rescue Mode..."
until [[ $(linode-cli linodes list --text | grep "\b${Label}\b" | grep "\brunning") ]]; do
  sleep 1
done


## Define the Here Document, which will be used to pass commands into the Linode running in Rescue Mode.
CMDS=$(cat <<-CMD
  /etc/init.d/ssh start
  echo "root:ZWZmYzQzNTgzYmEzNjEzYjg4MDA0Nzlk" | chpasswd

  echo "Adding SSH Public Key..."
  mkdir -p /root/.ssh/
  echo "${pubkey}" > /root/.ssh/authorized_keys
  chmod -R 700 /root/.ssh/
  chown -R root:root /root/.ssh/
  chmod 600 /root/.ssh/authorized_keys

  echo "Enabling Public Key Authentication for SSH..."
  sed -i -e "s/PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
  sed -i -e "s/#PasswordAuthentication no/PasswordAuthentication no/" /etc/ssh/sshd_config
  /etc/init.d/ssh restart
CMD
)

## Connect to Rescue Mode via LiSH and run  the commands, then fork the process into the background.
## The process is forked into the background using the '&' symbol at the end of the line to work
## around the fact that I can't find a good way to automate the pressing of Ctrl+A and Ctrl+D to exit LiSH.
echo "${CMDS}" | ssh -t -t ${UserName}@lish-${DC}.linode.com ${Label} &


## Allow 10 seconds to ensure that the commands finish running in Rescue Mode.
## This feels like it should be unnecessary, but I've found that the script behaves a bit too
## unpredictably for my taste if I remove it. You may be able to lower the value, I haven't really
## played with it too much.
sleep 10

## Clear the screen again.
clear


## Login to the Linode in Rescue Mode and copy the disk via SSH and DD.
echo "Copying the disk to the file linodeImage.img..."
echo "This is going to take a long time."
ssh -o 'StrictHostKeyChecking no' \
    -o "UserKnownHostsFile /dev/null" \
        root@${IP} "dd if=/dev/sda " | dd of=./linodeImage.img

## Reboot the Linode back to normal when finished.
echo "Rebooting the Linode..."
linode-cli linodes reboot $LinodeID
echo "Waiting for the Linode to reboot..."
until [[ $(linode-cli linodes list --text | grep "\b${Label}\b" | grep "\brunning") ]]; do
  sleep 1
done

## Remove free space from the image to reduce it's size a bit.
echo "Removing empty space from the image..."
echo "Size before compression: " $(ls -lh | grep linodeImage | awk '{print $5}')

if [ -x /usr/loca/bin/7z ]; then
  7z a linodeImage.img.7z linodeImage.img
else
  gzip linodeImage.img
fi && echo "Size after compression: " $(ls -lh | grep linodeImage | awk '{print $5}')


## Kill off any backgrounded SSH processes.
SSH_PIDs=($(ps aux | grep "\b${Label}\b" | awk '{print $2}'))

for i in "${SSH_PIDs[@]}"; do
  echo "Killing PID $i..."
  kill $i || kill -9 $i
  echo "Done"
done
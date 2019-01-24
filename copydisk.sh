#!/bin/bash

## Bash script that makes a backup copy of a Linode's disk over SSH, then compresses the image
## Written by Tommy Davidson

function arg_parse {
    ## We need some data in order to make this work.
    ## Use the arguments passed at the command line to assign some variables.
    local -r Local_Label="${1}"
    local -r Local_UserName="$(echo ${2} | tr '[:upper:]' '[:lower:]')"
    local -r Local_DC="$(echo ${3} | tr '[:upper:]' '[:lower:]')"
    local -r Local_LinodeID=$(linode-cli linodes list --text | grep "\b${Local_Label}\b" | awk '{print $1}')
    local -r Local_DiskID=$(linode-cli linodes disks-list ${Local_LinodeID} --text | awk '/ext4/{print $1}')
    local -r Local_IP="$(linode-cli linodes list --text | grep ${Local_LinodeID} | awk '{print $7}')"
    local -a Return_Array=("${Local_Label}" "${Local_UserName}" "${Local_DC}" $Local_LinodeID $Local_DiskID "${Local_IP}")

    ## Echo the parsed data back to the array in the calling function.
    echo "${Return_Array[@]}"
}


function reboot_linode {
    local -r Local_Mode="${1}"
    local -r Local_Label="${2}"
    local -r Local_LinodeID=$3
    local -r Local_DiskID=$4

    if [[ "${Local_Mode}" == 'rescue' ]]; then
        ## Reboot the Linode specified in "${LinodeID} into Rescue Mode using the Linode CLI v4.
        linode-cli linodes rescue $Local_LinodeID --devices.sda.disk_id $Local_DiskID && {
            printf "Waiting for the Linode to reboot into Rescue Mode...\n"
            until [[ $(linode-cli linodes list --text | grep "\b${Local_Label}\b" | grep "\brunning") ]]; do
                sleep 5
            done
        }
    elif [[ "${Local_Mode}" == 'normal' ]]; then
        ## Reboot the Linode back to normal.
        printf "Rebooting the Linode...\n"
        linode-cli linodes reboot $Local_LinodeID && {
            printf "Waiting for the Linode to reboot...\n"
            until [[ $(linode-cli linodes list --text | grep "\b${Local_Label}\b" | grep "\brunning") ]]; do
                sleep 5
            done
        }
    fi
}


function configure_ssh {
    local -r Local_Label="${1}"
    local -r Local_UserName="${2}"
    local -r Local_DC="${3}"
    local -r Local_PubKey="$(cat ~/.ssh/id_rsa.pub)"

    ## Define the Here Document, which will be used to pass commands into the Linode running in Rescue Mode.
    ## Excuse the odd indentation in this part - Here Documents are weird.
    CMDS=$(cat <<-CMD
        echo "root:YzViMmQxYTc5NmNjMDViYzY0ZDg0YWQy" | chpasswd
        /etc/init.d/ssh start

        printf "Adding SSH Public Key...\n"
        mkdir -p /root/.ssh/
        echo "${Local_PubKey}" > /root/.ssh/authorized_keys
        chmod -R 700 /root/.ssh/
        chown -R root:root /root/.ssh/
        chmod 600 /root/.ssh/authorized_keys

        printf "Disabling Password Authentication for SSH...\n"
        sed -i -e "s/PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
        sed -i -e "s/#PasswordAuthentication no/PasswordAuthentication no/" /etc/ssh/sshd_config
        /etc/init.d/ssh restart
CMD
)

    ## Connect to Rescue Mode via LiSH and run the commands listed in the Here Document, then fork the process
    ## into the background. The process is forked into the background to work around the fact that I haven't
    ## found a good way to automate the pressing of Ctrl+A and Ctrl+D to exit LiSH. I consider this whole approach
    ## to be a bit of an awkward hack, and I don't care for it - but it works.
    ##
    ## UDATE - I may have found a better way to do this - will look into it and update this code if it pans out.
    echo "${CMDS}" | ssh -t -t ${Local_UserName}@lish-${Local_DC}.linode.com ${Local_Label} &
}


function copy_disk {
    local -r Local_IP="${1}"

    ## Login to the Linode in Rescue Mode and copy the disk via SSH and DD.
    ## If 'pv' is installed, indicate progress, otherwise, copy it anyway.
    printf "Copying the disk to the file linodeImage.img...\n"
    printf "This is going to take a while.\n"
    if [ -x /usr/local/bin/pv ]; then
        ssh -o 'StrictHostKeyChecking no' \
            -o "UserKnownHostsFile /dev/null" \
                root@"${Local_IP}" "dd if=/dev/sda " | pv | dd of=./linodeImage.img
    else
        printf "pv is not installed, so I'm not able to indicate progress during the transfer. The image is copying now...\n"
        printf "If you're running this on a Mac, you can press Ctrl+T at any time to get status updates.\n"
        ssh -o 'StrictHostKeyChecking no' \
            -o 'UserKnownHostsFile /dev/null' \
                root@"${Local_IP}" "dd if=/dev/sda " | dd of=./linodeImage.img
    fi
}


function compress_image {
    ## Compress the image to reduce it's size a bit.
    printf "Removing empty space from the image...\n"
    printf "Size before compression: %s\n" $(ls -lh | grep linodeImage | awk '{print $5}')

    ## Use 7zip if available, otherwise use gzip
    if [ -x /usr/loca/bin/7z ]; then
        7z a linodeImage.img.7z linodeImage.img
    else
        gzip linodeImage.img
    fi && printf "Size after compression: %s\n" $(ls -lh | awk '/linodeImage/{print $5}')
}



## *** MAIN CODE BLOCK ***

## Clear the screen before running.
clear

## Check to ensure that arguments were passed at the command line, and error out if not.
## Otherwise, execute the script.
[[ ! "${@}" ]] && {
    printf "No arguments specified. You must specify the name of the Linode, the username for your Linode account,\n"
    printf "and the datacenter in which the Linode resides.\n"
} || {
    ## You can use '-v' or '--verbose' to output errors to the LISH console if you're
    ## having trouble. Be forewarned - it's pretty verbose, due largely to some of the
    ## loops that wait for the Linode to reboot, etc...
    [[ $(echo "${4}" | egrep '\-v|\-\-verbose') ]] && set -x

    ## Parse command line arguments into usable data, and assign that data into the 'Settings' array.
    declare -a Settings=($(arg_parse "${@}"))

    ## Assign the contents of the settings array to variables with meaningful names.
    readonly Label="${Settings[0]}"
    readonly UserName="${Settings[1]}"
    readonly DC="${Settings[2]}"
    readonly LinodeID=${Settings[3]}
    readonly DiskID=${Settings[4]}
    readonly IP="${Settings[5]}"

    ## Reboot the Linode into Rescue Mode.
    reboot_linode "rescue" "${Label}" ${LinodeID} ${DiskID} || {
        printf "Something went wrong rebooting the Linode.\n"
        exit 1
    }

    ## Enable SSH, and configure it to use Public Key Authentication.
    configure_ssh "${Label}" "${UserName}" "${DC}" && sleep 10 || {
        printf "Something went wrong configuring SSH.\n"
        exit 1
    }

    ## Clear the screen again.
    clear

    ## Pretty straightforward - copy the disk, reboot the Linode to normal, and
    ## compress the copied image.
    copy_disk "${IP}"
    reboot_linode "normal" "${Label}" ${LinodeID} ${DiskID}
    compress_image

    ## Kill off any backgrounded ssh processes that may still be running.
    killall ssh
}

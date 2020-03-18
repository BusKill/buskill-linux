#!/bin/bash
#set -x

################################################################################
# File:    buskill-selfdestruct.sh
# Purpose: Self-destruct trigger script for BusKill Kill Cord
#          For more info, see: https://buskill.in/
# WARNING: THIS IS EXPERIMENTAL SOFTWARE THAT IS DESIGNED TO CAUSE PERMANENT,
#          COMPLETE AND IRREVERSIBLE DATA LOSS!
# Note   : This script will *not* execute unless it's passed the '--yes'
#          argument. Be sure to test this trigger before depending on it!
# Authors: Michael Altfield <michael@buskill.in>
# Created: 2020-03-11
# Updated: 2020-03-11
# Version: 0.1
################################################################################

############
# SETTINGS #
############

BUSKILL_LOCK='/usr/local/bin/buskill-lock.sh'
[ -f ${BUSKILL_LOCK} ] || echo "ERROR: Unable to find buskill-lock.sh"

CRYPTSETUP=`which cryptsetup` || echo "ERROR: Unable to find cryptsetup"
LS=`which ls` || echo "ERROR: Unable to find ls"
CAT=`which cat` || echo "ERROR: Unable to find cat"
GREP=`which grep` || echo "ERROR: Unable to find grep"
ECHO=`which echo` || echo "ERROR: Unable to find echo"
AWK=`which awk` || echo "ERROR: Unable to find awk"
LSBLK=`which lsblk` || echo "ERROR: Unable to find lsblk"

##############
# ROOT CHECK #
##############

# TODO: attempt to become root or fail

###########
# CONFIRM #
###########

# for safety, exit if this script is executed without a '--yes' argument
${ECHO} "${@}" | ${GREP} '\--yes' &> /dev/null
if [ $? -ne 0 ]; then
	${ECHO} "WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING"
	${ECHO} "================================================================================"
	${ECHO} "WARNING: THIS IS EXPERIMENTAL SOFTWARE THAT IS DESIGNED TO CAUSE PERMANENT,  COMPLETE AND IRREVERSIBLE DATA LOSS!"
	${ECHO} "================================================================================"
	${ECHO} "WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING"
	${ECHO}
	${ECHO} "cowardly refusing to execute without the '--yes' argument for your protection. If really you want to proceed with damaging your system, retry with the '--yes' argument"
	exit 1
fi

###########################
# (DELAYED) HARD SHUTDOWN #
###########################

# The most secure encrypted computer is an encrypted computer that is *off*
# This is our highest priority; initiate a hard-shutdown to occur in 5 minutes regardless
# of what happens later in this script

# TODO: uncomment & test
#nohup sleep 300 && echo o > /proc/sysrq-trigger &
#nohup sleep 301 && shutdown -h now &
#nohup sleep 302 && poweroff --force --no-sync &

###############
# LOCK SCREEN #
###############

# first action: lock the screen!
# TODO: uncomment
#${BUSKILL_LOCK} &

#########
# TMPFS #
#########

# now we create a slim rootfs execution environment in memory that has the tools
# we need and is not dependent on encrypted volumes that we're about to destroy

# TODO: bash, dd, sync, shutdown, poweroff, echo, ls, awk, grep, cryptsetup, lsblk
# https://github.com/vianney/arch-luks-suspend/blob/master/arch-luks-suspend

#####################
# WIPE LUKS VOLUMES #
#####################

# clear page caches in memory
sync; echo 3 > /proc/sys/vm/drop_caches

# suspend each currently-decrypted LUKS volume
${ECHO} "INFO: removing decryption keys from memory"
for device in $( ${LS} -1 "/dev/mapper" ); do

	${ECHO} -e "\t${device}";
	# TODO: uncomment
	#${CRYPTSETUP} luksSuspend $device &

	# clear page caches in memory (again)
	sync; echo 3 > /proc/sys/vm/drop_caches

done

# overwrite luks headers
${ECHO} "INFO: shredding LUKS header (master encryption keys)"
writes=''
IFS=$'\n'
for line in $( ${LSBLK} --list --output 'PATH,FSTYPE' | ${GREP} 'crypto_LUKS' ); do
	device="`${ECHO} \"${line}\" | ${AWK} '{print \$1}'`"
	${ECHO} -e "\t${device}"

	# TODO luksErase || head -c 20M /dev/urandom > ${device} &

	writes="${writes} $!"
	# TODO: store pid of amped-off write tasks
done

# TODO: wait until all the write tasks above have completed
wait "${writes}"

# clear write buffer to ensure headers overwrites are actually synced to disks
sync; echo 3 > /proc/sys/vm/drop_caches

#############################
# (IMMEDIATE) HARD SHUTDOWN #
#############################

# do whatever works; this is important.
# TODO: uncomment
#echo o > /proc/sysrq-trigger &
#sleep 1
#shutdown -h now &
#sleep 1
#poweroff --force --no-sync

# exit cleanly (lol)
exit 0

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
HEAD=`which head` || echo "ERROR: Unable to find head"
LSBLK=`which lsblk` || echo "ERROR: Unable to find lsblk"
OD=`which od` || echo "ERROR: Unable to find od"

##############
# ROOT CHECK #
##############

# re-run as root
if [[ $EUID -ne 0 ]];
then
    exec sudo /bin/bash "$0" "$@"
fi

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

nohup sleep 300 && echo o > /proc/sysrq-trigger &
nohup sleep 301 && shutdown -h now &
nohup sleep 302 && poweroff --force --no-sync &

###############
# LOCK SCREEN #
###############

# first action: lock the screen!
${BUSKILL_LOCK} &

#####################
# WIPE LUKS VOLUMES #
#####################

# overwrite luks headers
${ECHO} "INFO: shredding LUKS header (plaintext metadata and keyslots with encrypted master decryption key)"
writes=''
IFS=$'\n'
for line in $( ${LSBLK} --list --output 'PATH,FSTYPE' | ${GREP} 'crypto_LUKS' ); do

	device="`${ECHO} \"${line}\" | ${AWK} '{print \$1}'`"
	${ECHO} -e "\t${device}"

	###########################
	# OVERWRITE LUKS KEYSLOTS #
	###########################

	# erases all keyslots, making the LUKS container "permanently inaccessible"
	${CRYPTSETUP} luksErase --batch-mode "${device}" || ${HEAD} --bytes 20M /dev/urandom > ${device} &

	# store the pid of the above write tasks so we can try to wait for it to
	# flush to disk later -- before triggering a brutal hard-shutdown
	writes="${writes} $!"

	#####################################
	# OVERWRITE LUKS PLAINTEXT METADATA #
	#####################################

	luksVersion=`${OD} --skip-bytes 6 --read-bytes 2 --format d2 --endian=big --address-radix "n" "${device}"`

	# get the end byte to overwrite. For more info, see:
	# https://security.stackexchange.com/questions/227359/how-to-determine-start-and-end-bytes-of-luks-header
	if [[ $luksVersion -eq 1 ]]; then
		# LUKS1: https://gitlab.com/cryptsetup/cryptsetup/-/wikis/LUKS-standard/on-disk-format.pdf

	 	# in LUKS1, the whole header ends at 512 * the `payload-offset`
		# this is actually more than we need (includes keyslots), but
		# it's the fastest/easiest to bound to fetch in LUKS1
		payloadOffset=`${OD} --skip-bytes 104 --read-bytes 4 --format d4 --endian=big --address-radix "n" "${device}"`
		luksEndByte=$(( 512 * ${payloadOffset} ))

	elif [[ $luksVersion -eq 2 ]]; then
		# LUKS2: https://gitlab.com/cryptsetup/LUKS2-docs/blob/master/luks2_doc_wip.pdf

		# in LUKS2, the end of the plaintext metadata area is twice the
		# size of the `hdr_size` field
		hdr_size=`${OD} --skip-bytes 8 --read-bytes 8 --format d8 --endian=big --address-radix "n" "${device}"`
		luksEndByte=$(( 2 * ${hdr_size} ))

	else
		# version unclear; just overwrite 20 MiB
		luksEndByte=20971520

	fi
		
	# finally, shred that plaintext metadata; we do this in a new file descriptor
	# to prevent bash from truncating if ${device} is a file
	exec 5<> "${device}"
	${HEAD} --bytes "${luksEndByte}" /dev/urandom >&5 &
	writes="${writes} $!"
	exec 5>&-
done

#######################
# WAIT ON DISK WRITES #
#######################

# wait until all the write tasks above have completed
wait "${writes}"

# clear write buffer to ensure headers overwrites are actually synced to disks
sync; echo 3 > /proc/sys/vm/drop_caches

#################################
# WIPE DECRYPTION KEYS FROM RAM #
#################################

# suspend each currently-decrypted LUKS volume
${ECHO} "INFO: removing decryption keys from memory"
for device in $( ${LS} -1 "/dev/mapper" ); do

	${ECHO} -e "\t${device}";
	${CRYPTSETUP} luksSuspend "${device}" &

	# clear page caches in memory (again)
	sync; echo 3 > /proc/sys/vm/drop_caches

done

#############################
# (IMMEDIATE) HARD SHUTDOWN #
#############################

# do whatever works; this is important.
echo o > /proc/sysrq-trigger &
sleep 1
shutdown -h now &
sleep 1
poweroff --force --no-sync

# exit cleanly (lol)
exit 0

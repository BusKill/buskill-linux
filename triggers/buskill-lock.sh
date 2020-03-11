#!/bin/bash
set -x

################################################################################
# File:    buskill-lock.sh
# Purpose: Cross-platform screen locking trigger script for BusKill Kill Cord
#          For more info, see: https://buskill.in/
# Authors: Michael Altfield <michael@buskill.in>
# Created: 2020-03-10
# Updated: 2020-03-10
# Version: 0.1
################################################################################

############
# SETTINGS #
############

XSCREENSAVER_COMMAND=`which xscreensaver-command`
XDG_SCREENSAVER=`which xdg-screensaver`
W=`which w`
CAT=`which cat`
TR=`which tr`
GREP=`which grep`
AWK=`which awk`
ECHO=`which echo`
PGREP=`which pgrep`

###############
# LOCK SCREEN #
###############

# use `xscreensaver-command` if possible
if [ -f "${XSCREENSAVER_COMMAND}" ]; then
	${XSCREENSAVER_COMMAND} -lock && exit 0
fi

# use `xdg-screensaver` if possible
if [ -f "${XDG_SCREENSAVER}" ]; then
	
	# get a list of users currently logged in
	w=`${W} --no-header`

	# loop through all of the logged-in users, attempting to lock the screen
	# until it works
	IFS=$'\n'
	for line in $(${ECHO} "${w}"); do

		username="`${ECHO} "${line}" | ${AWK} '{print \$1}'`"

		# getting the pid from `w` or `who` is unreliable as it's not a well designed
		# tool for scripting, and the time formats may differ yielding unpredictable
		# output data delimitation; we use `pgrep` instead.
		pid="`${PGREP} --uid \"${username}\" Xorg`"

		if [[ -n "${username}" && -n "${pid}" ]]; then
			# continue only if we found both a username and a pid for this login

			# get this logged-in user's XDG_RUNTIME_DIR, which is necessary
			# for the lock call to xdg-screensaver
			env=`${CAT} "/proc/${pid}/environ" | ${TR} "\0" "\n" | ${GREP} XDG_RUNTIME_DIR`

			# attempt to lock the screen
			sudo -u "${username}" ${env} ${XDG_SCREENSAVER} lock && exit 0

		fi
	done

fi

# if we made it this far, exit non-zero with error msg
${ECHO} "ERROR: Can't find way to lock screen. Unsupported system?"
exit 2

#!/bin/sh
#
# Mac OS does not really require something like RelativeLink.c
# However, we do want to have the same look and feel with similar features.
# In the future, we may want this to be a C binary with a custom icon but at the moment
# it's quite simple to just use a shell script
#
# To run in debug mode, simply pass -debug or --debug on the command line.
#
# WARNING: In debug mode, this script may cause dyld to write to the system
#          log file.
#
# Copyright 2010 The Tor Project.  See LICENSE for licensing information.

DEBUG_TBB=0
#set this to 1 to enable sandboxing.
SANDBOX_ENABLE=1
HOMEDIR=$HOME
export HOMEDIR

if [ "x$1" = "x--debug" -o "x$1" = "x-debug" ]; then
	DEBUG_TBB=1
	printf "\nDebug enabled.\n\n"
fi

# If the user hasn't requested 'debug mode', close whichever of stdout
# and stderr are not ttys, to keep Firefox and the stuff loaded by/for
# it (including the system's shared-library loader) from printing
# messages to be logged in /var/log/system.log .  (Users wouldn't have
# seen messages there anyway.)
#
# If the user has requested 'debug mode', don't muck with the FDs.
if [ "$DEBUG_TBB" -ne 1 ]; then
  if [ '!' -t 1 ]; then
    # stdout is not a tty
    exec >/dev/null
  fi
  if [ '!' -t 2 ]; then
    # stderr is not a tty
    exec 2>/dev/null
  fi
fi

HOME="${0%%Contents/MacOS/TorBrowserBundle}"
export HOME

DYLD_LIBRARY_PATH=${HOME}/Contents/Frameworks
export LDPATH
export DYLD_LIBRARY_PATH

if [ "$DEBUG_TBB" -eq 1 ]; then
	DYLD_PRINT_LIBRARIES=1
	export DYLD_PRINT_LIBRARIES
fi

if [ "$DEBUG_TBB" -eq 1 ]; then
	printf "\nStarting Tor Browser now\n"
	cd "${HOME}"
	printf "\nLaunching Tor Browser from: `pwd`\n"
    ./Contents/MacOS/TorBrowser.app/Contents/MacOS/firefox-bin -jsconsole -no-remote -profile "${HOME}/Data/Browser/profile.default"
	printf "\nTor Browser exited with the following return code: $?\n"
	exit
fi

if [ "$SANDBOX_ENABLE" -eq 1 ]; then
	OSXVER=`/usr/bin/sw_vers -productVersion`
	MYUID=`/usr/bin/id -u`
	if [ "$OSXVER" == "10.9" ]; then
		printf "\nStarting tbb in sandbox.\n"
		cd "${HOME}"
		HOME=`echo $HOME | sed 's=/$==g'`
		MYTMP=`echo $TMPDIR | sed 's=/$==g'`
		# clean up the sandbox
		mkdir ${HOME}/osx-sandbox/tmpdata
		/usr/bin/sed -e "s=%%TBB_ROOT%%=${HOME}=g" -e "s=%%TMPDIR%%=$MYTMP=g" -e "s=%%UID%%=$MYUID=g" -e "s=%%HOMEDIR%%=$HOMEDIR=g" "${HOME}/osx-sandbox/10.9.sb" > "${HOME}/osx-sandbox/tmpdata/10.9.sb"
		# ensure user can read and write to downloads
		echo "(allow file-read* file-write*" >> "${HOME}/osx-sandbox/tmpdata/10.9.sb"
		echo "(subpath \"${HOMEDIR}/Downloads\"))" >> "${HOME}/osx-sandbox/tmpdata/10.9.sb"
		# ensure that sandbox will allow traversing to the downloads area,
		# else tbb will have trouble with open file diag.
		echo "(allow file-read*" >> "${HOME}/osx-sandbox/tmpdata/10.9.sb"
		echo "(literal \"$HOMEDIR\")" >> "${HOME}/osx-sandbox/tmpdata/10.9.sb"
		while [ "$HOMEDIR" != "/" ]; do
			HOMEDIR=`echo $HOMEDIR | sed 's=\(/.*\)/\(.*\)$=\1=g'`
			echo "(literal \"$HOMEDIR\")" >> "${HOME}/osx-sandbox/tmpdata/10.9.sb"
			if [ "`echo $HOMEDIR| sed 's=[^/]==g'`" == "/" ]; then
				HOMEDIR=/
				echo "(literal \"$HOMEDIR\"))" >> "${HOME}/osx-sandbox/tmpdata/10.9.sb"
			fi
		done
		/usr/bin/sandbox-exec -f "${HOME}/osx-sandbox/tmpdata/10.9.sb" "${HOME}/Contents/MacOS/TorBrowser.app/Contents/MacOS/firefox"
		exit
	else
		exit
		echo "Sandboxing for $OSXVER not supported atm. starting without."
		cd "${HOME}"
		open "${HOME}/Contents/MacOS/TorBrowser.app" --args -no-remote -profile "${HOME}/Data/Browser/profile.default"
		exit
	fi
fi

# not in debug mode, run proceed normally
printf "\nLaunching Tor Browser Bundle for OS X in ${HOME}\n"
cd "${HOME}"
open "${HOME}/Contents/MacOS/TorBrowser.app" --args -no-remote -profile "${HOME}/Data/Browser/profile.default"

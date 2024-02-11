#!/bin/bash

if [ -t 1 ]; then
    ANSI_RESET="$(tput sgr0)"
    ANSI_RED="`[ $(tput colors) -ge 16 ] && tput setaf 9 || tput setaf 1 bold`"
    ANSI_GREEN="`[ $(tput colors) -ge 16 ] && tput setaf 10 || tput setaf 2 bold`"
    ANSI_YELLOW="`[ $(tput colors) -ge 16 ] && tput setaf 11 || tput setaf 3 bold`"
    ANSI_BLUE="`[ $(tput colors) -ge 16 ] && tput setaf 12 || tput setaf 4 bold`"
    ANSI_CYAN="`[ $(tput colors) -ge 16 ] && tput setaf 14 || tput setaf 6 bold`"
fi

while getopts "v" OPT; do
    case $OPT in
        v)  VERBOSE=$(( VERBOSE + 1 )) ;;
        \?) echo "${ANSI_RED}Invalid option: -$OPTARG!${ANSI_RESET}" >&2 ; exit 254 ;;
        :)  echo "${ANSI_RED}Option -$OPTARG requires an argument!${ANSI_RESET}" >&2 ; exit 254 ;;
    esac
done
shift $(( OPTIND - 1 ))

if [[ "$#" -ne 0 ]]; then
    echo "${ANSI_RED}Too many arguments!${ANSI_RESET}" >&2
    exit 1
fi

if ! [[ "$USER" == "root" ]]; then
    echo "${ANSI_RED}Must be root (sudo)!${ANSI_RESET}" >&2
    exit 2
fi


FOUND=0
PROCESSED=0

for MNT in "/boot" "/boot/efi"; do

    DISK=`findmnt -n -o source $MNT`
    if [[ "$DISK" == "" ]]; then
        echo "${ANSI_YELLOW}Cannot find $MNT mount point${ANSI_RESET}"
        continue
    fi

    PARTUUID=`blkid -s PARTUUID -o value $DISK`
    if [[ "$PARTUUID" == "" ]]; then
        echo "${ANSI_YELLOW}Cannot determine partition UUID for $MNT${ANSI_RESET}"
        continue
    fi

    FOUND=$((FOUND+1))

    echo -n "${ANSI_CYAN}$MNT${ANSI_RESET}"
    echo -n " ${ANSI_GREEN}$DISK${ANSI_RESET}"

    MATCHED_DISK=0
    for DISK2 in `lsblk -np --output KNAME`; do  # first try UUID match
        if [[ $VERBOSE -ge 1 ]]; then
            echo
            echo -n "  ${ANSI_BLUE}Checking $DISK2${ANSI_RESET}"
        fi
        if [[ "$DISK" != "$DISK2" ]]; then
            PARTUUID2=`blkid -s PARTUUID -o value $DISK2`
            if [[ "$PARTUUID" == "$PARTUUID2" ]]; then
                echo -n " ${ANSI_YELLOW}$DISK2${ANSI_RESET}"
                echo
                dd if=$DISK of=$DISK2 bs=1M |& sed -e 's/^/ /'
                PROCESSED=$((PROCESSED+1))
                MATCHED_DISK=1
                break
            elif [[ $VERBOSE -ge 2 ]]; then
                if [[ "$PARTUUID2" == "" ]]; then
                    echo -n " ${ANSI_BLUE}(no PARTUUID)${ANSI_RESET}"
                else
                    echo -n " ${ANSI_BLUE}($PARTUUID2 not matching $PARTUUID)${ANSI_RESET}"
                fi
            fi
        fi
    done

    if [[ "$MATCHED_DISK" -eq 0 ]]; then
        echo " ${ANSI_RED}-${ANSI_RESET}"
    fi

done

if [[ "$FOUND" -eq 0 ]]; then
    echo "${ANSI_RED}Cannot find any boot partitions${ANSI_RESET}"
    exit 1
fi

if [[ "$PROCESSED" -eq 0 ]]; then
    echo "${ANSI_RED}No boot partitions processed${ANSI_RESET}"
    exit 1
fi

exit 0

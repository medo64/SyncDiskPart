#!/bin/bash

if [ -t 1 ]; then
    ANSI_RESET="$(tput sgr0)"
    ANSI_RED="`[ $(tput colors) -ge 16 ] && tput setaf 9 || tput setaf 1 bold`"
    ANSI_GREEN="`[ $(tput colors) -ge 16 ] && tput setaf 10 || tput setaf 2 bold`"
    ANSI_YELLOW="`[ $(tput colors) -ge 16 ] && tput setaf 11 || tput setaf 3 bold`"
    ANSI_BLUE="`[ $(tput colors) -ge 16 ] && tput setaf 12 || tput setaf 4 bold`"
    ANSI_CYAN="`[ $(tput colors) -ge 16 ] && tput setaf 14 || tput setaf 6 bold`"
fi

DRY_RUN=0
VERBOSE=0

while getopts "nv" OPT; do
    case $OPT in
        n)  DRY_RUN=1 ;;
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

    PART_SRC=`findmnt -n -o source $MNT`
    if [[ "$PART_SRC" == "" ]]; then
        echo "${ANSI_YELLOW}Cannot find $MNT mount point${ANSI_RESET}"
        continue
    fi

    PART_SRC_SIZE=`blockdev --getsz $PART_SRC`
    PART_SRC_UUID=`blkid -s PARTUUID -o value $PART_SRC`
    PART_SRC_LABEL=`blkid -s PARTLABEL -o value $PART_SRC`
    if [[ "$PART_SRC_UUID" == "" ]] && [[ "$PART_SRC_LABEL" == "" ]]; then
        echo "${ANSI_YELLOW}Cannot determine partition UUID or LABEL for $MNT${ANSI_RESET}"
        continue
    fi

    FOUND=$((FOUND+1))

    echo -n "${ANSI_CYAN}$MNT${ANSI_RESET}"
    echo -n " ${ANSI_GREEN}$PART_SRC${ANSI_RESET}"

    sync -f $MNT

    MATCHED_PART=0
    for PART_DST in `lsblk -np --output KNAME`; do  # first try UUID match
        if [[ $VERBOSE -ge 1 ]]; then
            echo
            echo -n "  ${ANSI_BLUE}Checking UUIDs for $PART_DST${ANSI_RESET}"
        fi
        if [[ "$PART_SRC" != "$PART_DST" ]]; then
            PART_DST_UUID=`blkid -s PARTUUID -o value $PART_DST`
            if [[ "$PART_SRC_UUID" == "$PART_DST_UUID" ]]; then
                MATCHED_PART=1
                break
            elif [[ $VERBOSE -ge 2 ]]; then
                if [[ "$PART_DST_UUID" == "" ]]; then
                    echo -n " ${ANSI_BLUE}(no PARTUUID)${ANSI_RESET}"
                else
                    echo -n " ${ANSI_BLUE}($PART_DST_UUID not matching $PART_SRC_UUID)${ANSI_RESET}"
                fi
            fi
        fi
    done

    if [[ "$MATCHED_PART" -eq 0 ]] && [[ "$PART_SRC_LABEL" != "" ]]; then
        for PART_DST in `lsblk -np --output KNAME`; do  # first try UUID match
            if [[ $VERBOSE -ge 1 ]]; then
                echo
                echo -n "  ${ANSI_BLUE}Checking LABELs for $PART_DST${ANSI_RESET}"
            fi
            if [[ "$PART_SRC" != "$PART_DST" ]]; then
                PART_DST_LABEL=`blkid -s PARTLABEL -o value $PART_DST`
                if [[ "$PART_SRC_LABEL" == "$PART_DST_LABEL" ]]; then
                    PART_DST_SIZE=`blockdev --getsz $PART_DST`
                    if [[ "$PART_SRC_SIZE" == "$PART_DST_SIZE" ]]; then
                        MATCHED_PART=1
                        break
                    fi
                elif [[ $VERBOSE -ge 2 ]]; then
                    if [[ "$PART_DST_UUID" == "" ]]; then
                        echo -n " ${ANSI_BLUE}(no PARTUUID)${ANSI_RESET}"
                    else
                        echo -n " ${ANSI_BLUE}($PART_DST_UUID not matching $PART_SRC_UUID)${ANSI_RESET}"
                    fi
                fi
            fi
        done
    fi

    if [[ "$MATCHED_PART" -ne 0 ]]; then
        echo -n " ${ANSI_YELLOW}$PART_DST${ANSI_RESET}"
        echo
        if [[ "$DRY_RUN" -eq 0 ]]; then
            dd if=$PART_SRC of=$PART_DST bs=1M |& sed -e 's/^/ /'
        fi
        PROCESSED=$((PROCESSED+1))
    else
        echo " ${ANSI_RED}-${ANSI_RESET}"
    fi

done

if [[ "$FOUND" -eq 0 ]]; then
    echo "${ANSI_RED}Cannot match any boot partitions${ANSI_RESET}"
    exit 1
fi

if [[ "$PROCESSED" -eq 0 ]]; then
    echo "${ANSI_RED}No boot partitions processed${ANSI_RESET}"
    exit 1
fi

exit 0


if [ "$#" -eq 2 ] && [ -d "$1" ];
then
	BASE_DIR="."
	HOST_NAME=$(echo "${2}" | tr [:lower:] [:upper:])
	SRC_JSON_FILE="${HOST_NAME}_source.json"
	TRG_JSON_FILE="${HOST_NAME}_target.json"
	[[ -f $1/$SRC_JSON_FILE ]] || { echo "ERROR : Source json file : ${SRC_JSON_FILE} does not exist in folder : ${1}";exit;}
	[[ -f $1/$TRG_JSON_FILE ]] || { echo "ERROR : Target json file : ${TRG_JSON_FILE} does not exist in folder : ${1}";exit;}
	for JSON_FILE in $1/$SRC_JSON_FILE $1/$TRG_JSON_FILE
	do
	        [[ $(echo "${JSON_FILE: -12}") == "_source.json" ]] && { MIG_STAGE="source";} || { MIG_STAGE="target";}
		OUTPUT_DIR="${BASE_DIR}/${MIG_STAGE}/${HOST_NAME}"
		mkdir -p "${OUTPUT_DIR}"
		sed "s/.*Operating System\":\"//;s/\",.*//" $JSON_FILE > $OUTPUT_DIR/os_name
		sed "s/.*Version Number\":\"//;s/\",.*//" $JSON_FILE > $OUTPUT_DIR/os_version
		sed "s/.*\"Domain\":\"//;s/\",.*//" $JSON_FILE > $OUTPUT_DIR/domain_name
		sed "s/.*ipconfig\":\[\"//;s/\"\],.*//" $JSON_FILE \
					| sed -e $'s/","/\\\n/g'  > $OUTPUT_DIR/ip_details
		sed "s/.*\"Persistent Route\":\"//;s/\",.*//" $JSON_FILE > $OUTPUT_DIR/persistent_gw
		sed "s/.*Autostart services\":\[\"//;s/\"\],.*//" $JSON_FILE \
				| sed -e $'s/","/\\\n/g' | sed -e 's/_.*//' |sort |uniq > $OUTPUT_DIR/auto_start_services
		sed "s/.*Services started by service accounts\":\[//;s/\"}\],.*//" $JSON_FILE \
					| sed -e $'s/},{/\\\n/g'  > $OUTPUT_DIR/srv_acc_Services
		sed "s/.*\"Local disk details\"://;s/}\]//" $JSON_FILE | sed -e $'s/},{/\\\n/g' > $OUTPUT_DIR/local_disk_details
	done
else
	echo "Usage : ksh collect_win_config.ksh <Folder path of JSON files> <HostName>";exit 
fi
###=============================================###
SOURCE_DIR="${BASE_DIR}/source/${HOST_NAME}"
TARGET_DIR="${BASE_DIR}/target/${HOST_NAME}"
OUTPUT_DIR="${BASE_DIR}/compare/${HOST_NAME}"
CDATE="$(date +"%F-%H_%M_%S")"

mkdir -p "${OUTPUT_DIR}"
if [ -d "$SOURCE_DIR" ];then
        if [ -d "$TARGET_DIR" ];then
                LOGFILE="${HOST_NAME}_compare_${CDATE}"
                echo "====================================================================" |tee ${OUTPUT_DIR}/${LOGFILE}
                echo "Comparing Pre-Migration Vs Post Migration configuration.." |tee -a ${OUTPUT_DIR}/${LOGFILE}
                echo "====================================================================" |tee -a ${OUTPUT_DIR}/${LOGFILE}
                echo "======= SERVER NAME : ${HOST_NAME}" |tee -a ${OUTPUT_DIR}/${LOGFILE}
                echo "====================================================================" |tee -a ${OUTPUT_DIR}/${LOGFILE}
                echo "======= DATE-TIME : ${CDATE}" |tee -a ${OUTPUT_DIR}/${LOGFILE}
                echo "Pre Migration configuration files folder given is : ${SOURCE_DIR}" |tee -a ${OUTPUT_DIR}/${LOGFILE}
                echo "Post Migration configuration files folder given is : ${TARGET_DIR}" |tee -a ${OUTPUT_DIR}/${LOGFILE}
                echo "====================================================================" |tee -a ${OUTPUT_DIR}/${LOGFILE}
        else
                echo "Post Migration directory does not exist : ${TARGET_DIR}";exit
        fi
else
        echo "Pre Migration directory does not exist : ${SOURCE_DIR}";exit
fi
ERROR_CNT=0

_displayprogress()
{

        LISTED_ITEM="yes"
        case $1 in
                auto_start_services)    DISPLAY_MSG="Auto Start Services Information"
                                        ;;
                domain_name)            DISPLAY_MSG="Domain name"
                                        ;;
                ip_details)             DISPLAY_MSG="IP Addresses"
                                        ;;
                local_disk_details)     DISPLAY_MSG="Local disk details"
                                        ;;
                os_name)                DISPLAY_MSG="Operating System Name"
                                        ;;
                os_version)             DISPLAY_MSG="Operating System version"
                                        ;;
                persistent_gw)          DISPLAY_MSG="Persistant Gateway"
                                        ;;
                srv_acc_Services)       DISPLAY_MSG="Service Account Services"
                                        ;;
                                *)      LISTED_ITEM="no"
                                        ;;
        esac

[[ ${LISTED_ITEM} == "yes" ]] && { echo -e "Comparing ${DISPLAY_MSG}" | tee -a ${OUTPUT_DIR}/${LOGFILE}; }

}

for CFGFILE in $SOURCE_DIR/*
do
        STATUS=""
        CFGFILE=$(basename "${CFGFILE}")
        _displayprogress "${CFGFILE}"
        if [ -f "$TARGET_DIR/$CFGFILE" ];then
                IFS=$'\n' STATUS=($(awk 'NR==FNR{LIST[$0];next}(!($0 in LIST)){print $0}' $TARGET_DIR/$CFGFILE $SOURCE_DIR/$CFGFILE))
                if [ "${#STATUS[@]}" -ne 0 ];then
                        echo -e "**** ERROR **** Found some mismatch in file $TARGET_DIR/$CFGFILE" |tee -a ${OUTPUT_DIR}/${LOGFILE}
                        for E_LINE in ${STATUS[@]}
                        do
                                echo "${E_LINE}" |tee -a ${OUTPUT_DIR}/${LOGFILE}
                        done
                        echo
                        ERROR_CNT=$((ERROR_CNT+1))
                else
                        echo "                                  ..... OK" |tee -a ${OUTPUT_DIR}/${LOGFILE}
                fi
        else
                echo -e "\nThe file - ${CFGFILE} - does not exist in $TARGET_DIR"
                echo -n "Do you wish to [C]ontinue or [E]xit ? "
                read STATUS
                case $STATUS in
                        C | c)  continue;
                                ;;
                        *)      break;
                                ;;
                esac
        fi

done

echo -e "\n\n=============================================================" |tee -a ${OUTPUT_DIR}/${LOGFILE}
echo -e "\n Total number of issues found : ${ERROR_CNT}" |tee -a ${OUTPUT_DIR}/${LOGFILE}
echo -e " DATE : $(date +"%F-%T")" |tee -a ${OUTPUT_DIR}/${LOGFILE}
echo -e " Log stored in : ${OUTPUT_DIR}/${LOGFILE}" |tee -a ${OUTPUT_DIR}/${LOGFILE}
echo -e "\n====================  END  ==================================" |tee -a ${OUTPUT_DIR}/${LOGFILE}


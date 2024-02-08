#!/bin/bash
#### Description: Does a MySQL Backup, writes logs and optionally sends an e-mail on error
#### On debian the script can use the credentials from the debian-sys-maint user so you can put the script in a cronjob and forget about it
#### If you don't want to use the debian-sys-maint user modify the MUSER and MPASS variables
####
#### Important Parameters:
#### STORAGEDIR = Folder where the script stores your backup.
#### LOGDIR = Folder where the script stores the logfiles
#### IGNOREDB = List of Databases to ignore.
#### ROTATION = Number of days the backup should rotate. Default is 7.
#### MUSER = MySQL Username
#### MPASS = MySQL Password
#### SENMAIL = Set to 1 to send an e-mail on error
#### MAILREC = Mail recipient who should get the notification e-mail
####
#### Example cron entry, will create a full backup every day at 2am
####
#### 0 2 * * * root /usr/local/sbin/backupmysql
####
#### Written by webstylr (http://www.webstylr.com/2012/09/10/simples-shellscript-fr-mysql-backup/)
#### Extended by Michael Neese - madic@geekbundle.org

start=$(date +%s)
NOWD=$(date +"%Y-%m-%d")
STORAGEDIR="/backups/mysql"
LOGDIR="/backups/logs"
BACKUPDIR="${STORAGEDIR}/${NOWD}"

DIRS="${STORAGEDIR} ${LOGDIR} ${BACKUPDIR}"
set -- $DIRS
for i in "$@"; do
  if [ ! -d "$i" ]; then
    mkdir -p "$i"
  fi
  if [ ! "$?" = "0" ]; then
    echo "Error: Couldn't create folder $i. Check folder permissions and/or disk quota!" >>"/tmp/$NOWD-mysql-backup.log"
  fi
done
### Defaults Setup ###
SENDMAIL="0"
MAILREC=""
MACHINE=$(hostname)@$(hostname -d)
FQDN=$(hostname -f)
NOWD=$(date +%Y-%m-%dT%H:%M:%S%z)
LOG="${LOGDIR}/${NOWD}-mysql-backup.log"
NOW=$(date "+%s")
OLDESTDIR=$(ls $STORAGEDIR | head -1)
OLDEST=$(date -d "${OLDESTDIR}" "+%s")
DIFF=$((${NOW} - ${OLDEST}))
DAYS=$((${DIFF} / (60 * 60 * 24)))
ROTATION="7"
XZCHECK=()
### Server Setup ###
MUSER="root"
MPASS="${MYSQL_ROOT_PASSWORD}"
MHOST="${MYSQL_HOST}"
MPORT="3306"
IGNOREDB="
information_schema
mysql
performance_schema
test
ndoutils
"
MYSQL=$(which mysql)
MYSQLDUMP=$(which mysqldump)
XZ=$(which xz)
XZ_OPTIONS="--threads=4 -z"
PT_SHOW_GRANTS=$(which pt-show-grants)

# Write to $LOGDIR
exec &>"$LOG"

### Get the list of available databases ###
DBS="$(${MYSQL} --user=${MUSER} --password=${MPASS} --host=${MHOST} --port=${MPORT} -Bse 'show databases')"

### Backup Users ###
"${PT_SHOW_GRANTS}" \
  --host=$MYSQL_HOST \
  --user=root \
  --password=${MPASS} \
  --port=${MPORT} \
| ${XZ} ${XZ_OPTIONS} > "${BACKUPDIR}/${NOWD}-users.sql.xz"

### Backup DBs ###
for db in $DBS; do
  DUMP="yes"
  if [ "$IGNOREDB" != "" ]; then
    for i in ${IGNOREDB}; do
      if [ "${db}" == "${i}" ]; then
        DUMP="NO"
      fi
    done
  fi

  if [ "${DUMP}" == "yes" ]; then
    FILE="${BACKUPDIR}/${NOWD}-${db}.sql.xz"
    echo -e "\nInfo: BACKING UP ${db}"
    "${MYSQLDUMP}" \
      --add-drop-database \
      --opt \
      --lock-all-tables \
      --user="${MUSER}" \
      --password="${MPASS}" \
      --host="${MHOST}" \
      --port="${MPORT}" \
      --databases "${db}" \
    | ${XZ} ${XZ_OPTIONS} >"${FILE}"

    if [ "$?" = "0" ]; then
      ${XZ} -t "${FILE}"
      if [ "$?" = "0" ]; then
        XZCHECK+=(1)
        echo $(ls -alh ${FILE})
      else
        XZCHECK+=(0)
        echo "Error: Exit, xz test failed."
      fi
    else
      echo "Error: Dump of $db failed!"
    fi
  fi
done

### Check if xz test for all files was ok ###
CHECKOUTS=${#XZCHECK[@]}
for ((i = 0; i < $CHECKOUTS; i++)); do
  CHECKSUM=$((${CHECKSUM} + ${XZCHECK[${i}]}))
done

### If all files check out, delete the oldest dir ###
if [ "${CHECKSUM}" == "${CHECKOUTS}" ]; then
  echo -e "\nInfo: All files checked out ok. Deleting dirs older than ${ROTATION} day(s)."
  ## Check if Rotation is true ###
  if [ "$DAYS" -ge ${ROTATION} ]; then
    rm -rf ${STORAGEDIR}/${OLDESTDIR}
    if [ "$?" = "0" ]; then
      echo -e "Info: ${OLDESTDIR} deleted.\nBackup successful."
    else
      DIRLIST=$(ls -lRh "${BACKUPDIR}")
      ### Error message with listing of all dirs ###
      echo "Error: Couldn't delete oldest dir."
      echo "Contents of current Backup at ${BACKUPDIR}:"
      echo " "
      echo ${DIRLIST}
    fi
  fi
fi

end=$(($(date +%s) - ${start}))
runtime=$(date -u -d @${end} +"%T")
echo -e "\n$(date +"%Y-%m-%d %H:%M:%S") Script runtime: ${runtime}"

# If error, send mail with contents of logfile
if [ "${SENDMAIL}" == "1" ]; then
  if grep -q 'Error' "${LOG}" || grep -q 'Error' "/tmp/${NOWD}-mysql-backup.log" &>/dev/null; then
    IFS=
    MESSAGE=$(cat "${LOG}" && cat "/tmp/${NOWD}-mysql-backup.log")
    echo ${MESSAGE} | mail -s "$FQDN - MySQL Backuplog" "${MAILREC}"
    #echo ${MESSAGE} | mail -a "From: ${MACHINE}" -s "${FQDN} - MySQL Backuplog" "${MAILREC}"
  fi
fi

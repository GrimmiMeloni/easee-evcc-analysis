#!/bin/bash

usage() { 
  echo converts evcc logs for easee into a annotated csv format for consumption into influx
  echo
  echo "Usage: $0 [-n] <evcc.log>" 
  echo
  echo "-n prevents start of influx/grafana stack and automatic import of results"
  echo
  exit 1
}

NOSTART=0

while getopts "n" o; do
    case "${o}" in
        n)
            NOSTART=1
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

[ -z "$1" ] && usage

OUTPUT=$1_processed.csv

echo processing $1 into $OUTPUT

#print some headers into CSV
cat << EOF > $OUTPUT
#datatype measurement,tag,dateTime:2006/01/02 15:04:05,string
measurement,charger,timestamp,apicall
EOF

# filter and processing as follows
# only easee
# filters for charger commands, api replies and command responses
# sed then 
#  trims left up to timestamp 
#  replaces blank behind timestamp with comma
#  for each api call, prefixes the line with 'apicall,<charger>,'
#  for each api reply, prefixes the line with 'apireply,<charger>,'
#  for each api reply, replaces double quotes with singles
#  for each commandresponse, prefixes the line with 'commandresponse,<charger>,'

cat $1 | \
grep '\[easee' | \
egrep 'POST https:\/\/api.easee.com\/api\/chargers\/........\/commands|\{"device"|CommandResponse' | \
sed \
  -e 's/^.*\[easee \] TRACE //' \
  -e 's/^\(.\{19\}\) /\1,/' \
  -e '/api.easee.com\/api\/chargers\/\(........\)\// s/.*chargers\/\(........\)\/.*/apicall,\1,&/' \
  -e '/"device"/ s/.*"device":"\(........\)".*/apireply,\1,&/' \
  -e '/"device"/ s/"/'\''/g' \
  -e '/CommandResponse / s/.*CommandResponse \(........\):.*/commandresponse,\1,&/' \
  >> $OUTPUT

# these would extract values needed for calculating the duration. 
# But influx does not allow more than one timestamp in a measurement

##datatype measurement,tag,dateTime:2006/01/02 15:04:05,string,dateTime:2006-01-02 15:04:05.999999,dateTime:2006-01-02 15:04:05.999999
#measurement,charger,timestamp,apicall,timestamp,delivery
#  -e '/CommandResponse / s/.*Timestamp:\(.*\) +0000 UTC DeliveredAt.*/&,\1/' \
#  -e '/CommandResponse / s/.*DeliveredAt:\(.*\) +0000 UTC WasAccepted.*/&,\1/' \

echo "done. See results in $OUTPUT" 

[ $NOSTART -eq 1 ] && exit 0

echo "Importing into influx now."
podman-compose up -d
export INFLUX_TOKEN=2-kbA15f2YQjk0_NEt91GxyQ1wutrdL8eqTnlbEhWc69SFdcXQbCKNQu5hoJh6c0rkIecVIeZTqGkHMe0Nemtg==
influx write --host http://localhost:8086 --org grimmi --bucket easee -f $OUTPUT

echo 
echo "Stack spun up, data imported. Go to http://localhost:8086 to inspect"
echo 
echo "use podman-compose down to stop stack"

#!/bin/bash

# converts evcc logs for easee into a annotated csv format for consumption into influx

[ -z "$1" ] && echo param missing && exit 1
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
  -e 's/^.*: \[easee \] TRACE //' \
  -e 's/^\(.\{19\}\) /\1,/' \
  -e '/api.easee.com\/api\/chargers\/\(........\)\// s/.*chargers\/\(........\)\/.*/apicall,\1,&/' \
  -e '/"device"/ s/.*"device":"\(........\)".*/apireply,\1,&/' \
  -e '/"device"/ s/"/'\''/g' \
  -e '/CommandResponse / s/.*CommandResponse \(........\):.*/commandresponse,\1,&/' >> $OUTPUT

echo "done. Import into influx now via:"
echo
echo "influx write --host http://localhost:8086 --org mhess --bucket easee -f $OUTPUT"

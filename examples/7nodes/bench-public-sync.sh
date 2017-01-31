#!/bin/bash
set -u
set -e
# c = number of concurrent connections (sending transactions over and over)
# d = duration, e.g. 30 (30 seconds), 5m, 1h
# t = threads Wrk should use, e.g. 2
#
# Example: ./bench-public-sync.sh 10 1m 2
c=$1
d=$2
t=$3

# Time to wait before checking for Tx receipts
DELAY=10
URL=http://localhost:22000/

txListFile="txs-$c-$d-$t.out"
failedTxFile="failed-txs-$c-$d-$t.out"

# curl -d '' http://localhost:22000/
wrk -s send-public-sync.lua -c $c -d $d -t $t $URL | sed -ne 's/.*\(0[xX][0-9a-fA-F]*\).*/\1/p' > $txListFile
echo "Finished submitting transactions"
echo -e "Sleeping for $DELAY seconds, before requesting transaction receipts..."
sleep $DELAY

echo -e "Requesting Tx receipts..."\\n
failedCount=0
totalChecked=0
failedList=""
while read -r tx; do
	totalChecked=$(($totalChecked + 1))
	result=`curl -s -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getTransactionReceipt\",\"params\":[\"$tx\"],\"id\":1}" $URL`
	if [ `echo $result | grep -c 'blockNumber'` -eq 0 ]; then
		failedCount=$(($failedCount + 1))
		failedList="$tx\n$failedList"
	fi
	echo -n -e Failed: $failedCount, Total checked: $totalChecked Percentage failure: $((($failedCount * 100) / $totalChecked))% \\r
done < $txListFile

echo
echo -e $failedList > $failedTxFile

#!/usr/bin/env bash

peers=$(ls ./outputs/network)
router_pid=$(cat outputs/log/router/*.txt | rg PID | grep -o '[^ ]*$')
sed -i "s/${router_pid}/RO/" $dot_file
idx=0
for pid in ${peers[@]}; do
    idx=$((idx+1))
    echo "P${idx}: $pid"
done
echo "RO: $router_pid"

modify() {
    dot_file=$1
    sed -i 's/graph {/graph {\n    layout=circo/' $dot_file
    idx=0
    for pid in ${peers[@]}; do
        idx=$((idx+1))
        sed -i "s/${pid}/P${idx}/" $dot_file
    done
    sed -i "s/${router_pid}/RO/" $dot_file
}


for dot_file in $(ls ./outputs/network/*/*.dot); do
    modify $dot_file &
done
wait

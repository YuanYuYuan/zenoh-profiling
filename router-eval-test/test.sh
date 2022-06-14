#!/usr/bin/env bash


tmp_dir="$(mktemp -d)"
pid_list_file="$tmp_dir/pid"


function finalize() {
    while read pid; do
        pgid="$(ps -ef -o pgid= -p "$pid" | tr -d ' ')"
        if [ -n "$pgid" ] ; then
            echo killing pgid "$pgid" >&2
            kill -- -"$pgid"
        fi
    done < "$pid_list_file"
    rm -rf "$tmp_dir"
    exit
}

function start() {
    setsid "$@" &
    echo $! >> "$pid_list_file"
}

trap "finalize" SIGINT SIGTERM EXIT

endpoint="tcp/127.0.0.1:7447"

start ../../zenoh/target/release/zenohd -l "$endpoint"
sleep 1
start ./target/release/router-eval-test -m 'peer' -n 64 -d -c "$endpoint"
# start cargo flamegraph -- -m 'peer' -n 64 -d -c "$endpoint"
sleep 3
start ../../zenoh/target/release/examples/z_get --no-multicast-scouting -s "/key/1" -e "$endpoint"
# ../../zenoh/target/release/examples/z_get -s "/key/1" &

wait

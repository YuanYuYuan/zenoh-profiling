#!/usr/bin/env bash

DATA_DIR="$1"
for PEER_DIR in $(find ${DATA_DIR} -type d -name 'peer-*'); do
    if [ ! -d ${DATA_DIR}/network ]; then
        echo "${DATA_DIR}/network not existed."
        exit
    fi
    mkdir -p ${PEER_DIR}/network
    for PID in $(rg "Using PID" $PEER_DIR | sed "s/.*: //g"); do
        mv ${DATA_DIR}/network/${PID} ${PEER_DIR}/network
    done
done

if rmdir ${DATA_DIR}/network > /dev/null; then
    echo "Finshed."
else
    echo "Failed to rearrange!"
    exit
fi

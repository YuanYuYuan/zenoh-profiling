#!/usr/bin/env bash

ROUTER_PROGRAM_PATH="../../zenoh/target/release/zenohd"
EVAL_PROGRAM_PATH="./target/release/z_eval"
QUERY_PROGRAM_PATH="./target/release/z_query"

ROUTER_PROGRAM="$(basename $ROUTER_PROGRAM_PATH)"
EVAL_PROGRAM="$(basename $EVAL_PROGRAM_PATH)"
QUERY_PROGRAM="$(basename $QUERY_PROGRAM_PATH)"

if ! command -v $ROUTER_PROGRAM_PATH &> /dev/null; then
    echo "$ROUTER_PROGRAM_PATH could not be found!"
    exit
fi

if ! command -v $EVAL_PROGRAM_PATH &> /dev/null; then
    echo "$EVAL_PROGRAM_PATH could not be found!"
    exit
fi

if ! command -v $QUERY_PROGRAM_PATH &> /dev/null; then
    echo "$QUERY_PROGRAM_PATH could not be found!"
    exit
fi

OUTPUT_DIR="outputs"
rm -rf $OUTPUT_DIR

USAGE_DIR="${OUTPUT_DIR}/usage"
ROUTER_USAGE_DIR="${USAGE_DIR}/router"
EVAL_USAGE_DIR="${USAGE_DIR}/eval"
QUERY_USAGE_DIR="${USAGE_DIR}/query"

mkdir -p $EVAL_USAGE_DIR
mkdir -p $QUERY_USAGE_DIR
mkdir -p $ROUTER_USAGE_DIR

LOG_DIR="${OUTPUT_DIR}/log"
ROUTER_LOG_DIR="${LOG_DIR}/router"
EVAL_LOG_DIR="${LOG_DIR}/eval"
QUERY_LOG_DIR="${LOG_DIR}/query"

mkdir -p $EVAL_LOG_DIR
mkdir -p $QUERY_LOG_DIR
mkdir -p $ROUTER_LOG_DIR

function cleanup() {
    pkill $ROUTER_PROGRAM
    pkill $EVAL_PROGRAM
    pkill $QUERY_PROGRAM
}

trap ctrl_c INT

function ctrl_c() {
    cleanup
    exit
}


ENDPOINT="tcp/127.0.0.1:7447"
EVAL_MODE="peer"
# EVAL_MODE="client"
EVAL_TIMEOUT=15
QUERY_TIMEOUT=15

export PYTHONWARNINGS="ignore"

cleanup
for NUM_PEERS in {32..48}; do
    echo -n "Testing $NUM_PEERS peers ... "
    psrecord "
        $ROUTER_PROGRAM_PATH \
            --listen "$ENDPOINT" 2>&1 > ${ROUTER_LOG_DIR}/${NUM_PEERS}.txt
    " \
        --log ${ROUTER_USAGE_DIR}/${NUM_PEERS}.txt \
        --plot ${ROUTER_USAGE_DIR}/${NUM_PEERS}.png \
        --include-children 2>&1 > /dev/null &

    sleep 1

    psrecord "
        $EVAL_PROGRAM_PATH \
            --mode $EVAL_MODE \
            --num-peers $NUM_PEERS \
            --disable-multicast \
            --timeout $EVAL_TIMEOUT \
            --connect "$ENDPOINT" 2>&1 > ${EVAL_LOG_DIR}/${NUM_PEERS}.txt
    " \
        --log ${EVAL_USAGE_DIR}/${NUM_PEERS}.txt \
        --plot ${EVAL_USAGE_DIR}/${NUM_PEERS}.png \
        --include-children 2>&1 > /dev/null &

    # # Add --disable-peers-autoconnect
    # psrecord "
    #     $EVAL_PROGRAM_PATH \
    #         --mode $EVAL_MODE \
    #         --num-peers $NUM_PEERS \
    #         --disable-multicast \
    #         --disable-peers-autoconnect \
    #         --timeout $EVAL_TIMEOUT \
    #         --connect "$ENDPOINT" 2>&1 > ${EVAL_LOG_DIR}/${NUM_PEERS}.txt
    # " \
    #     --log ${EVAL_USAGE_DIR}/${NUM_PEERS}.txt \
    #     --plot ${EVAL_USAGE_DIR}/${NUM_PEERS}.png \
    #     --include-children 2>&1 > /dev/null &

    sleep 3

    psrecord "
        $QUERY_PROGRAM_PATH \
            --mode 'peer' \
            --disable-multicast \
            --timeout $QUERY_TIMEOUT \
            --connect "$ENDPOINT" 2>&1 > ${QUERY_LOG_DIR}/${NUM_PEERS}.txt
    " \
        --log ${QUERY_USAGE_DIR}/${NUM_PEERS}.txt \
        --plot ${QUERY_USAGE_DIR}/${NUM_PEERS}.png \
        --include-children 2>&1 > /dev/null

    cleanup
    sleep 1

    NUM_REPLIES=$(tail -n 1 ${QUERY_LOG_DIR}/${NUM_PEERS}.txt | cut -d ' ' -f 4)
    if [ "$NUM_REPLIES" = "$NUM_PEERS" ]; then
        echo "passed."
    else
        echo "failed."
    fi
done

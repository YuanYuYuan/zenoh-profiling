#!/usr/bin/env bash

if [ $(ulimit -n) = 1024 ]; then
    echo "Avaiable file descriptors is too low. Try to run 'ulimit -n unlimited'"
    exit
fi

ROUTER_PROGRAM_PATH="../../zenoh/target/release/zenohd"
EVAL_PROGRAM_PATH="./target/release/z_eval"
# EVAL_PROGRAM_PATH="cargo flamegraph --bin=z_eval -- "
QUERY_PROGRAM_PATH="./target/release/z_query"

ROUTER_PROGRAM="zenohd"
EVAL_PROGRAM="z_eval"
QUERY_PROGRAM="z_query"

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
rm -rvf $OUTPUT_DIR

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
# QUERY_MODE="peer"
QUERY_MODE="client"
EVAL_TIMEOUT=120
QUERY_TIMEOUT=30
WARMUP=30
# WARMUP=3


export PYTHONWARNINGS="ignore"

cleanup

# for NUM_PEERS in {48..24..2}; do
# for NUM_PEERS in {8..12..2}; do
for NUM_PEERS in 8; do
    echo -n "Testing $NUM_PEERS peers ... "

    # output directories
    LOG_DIR=${OUTPUT_DIR}/peer-${NUM_PEERS}/log
    USAGE_DIR=${OUTPUT_DIR}/peer-${NUM_PEERS}/usage
    mkdir -p $LOG_DIR
    mkdir -p $USAGE_DIR

    psrecord "
        $ROUTER_PROGRAM_PATH \
            --listen "$ENDPOINT" > ${LOG_DIR}/router.txt 2>&1
    " \
        --log ${USAGE_DIR}/router.txt \
        --plot ${USAGE_DIR}/router.png \
        --include-children > /dev/null &

    sleep 1

    psrecord "
        $EVAL_PROGRAM_PATH \
            --mode $EVAL_MODE \
            --no-gossip \
            --use-peer-linkstate \
            --num-peers $NUM_PEERS \
            --disable-multicast \
            --timeout $EVAL_TIMEOUT \
            --connect "$ENDPOINT" > ${LOG_DIR}/eval.txt 2>&1
    " \
        --log ${USAGE_DIR}/eval.txt \
        --plot ${USAGE_DIR}/eval.png \
        --include-children > /dev/null &

    sleep $WARMUP

    psrecord "
        $QUERY_PROGRAM_PATH \
            --mode $QUERY_MODE \
            --disable-multicast \
            --timeout $QUERY_TIMEOUT \
            --connect "$ENDPOINT" > ${LOG_DIR}/query.txt 2>&1
    " \
        --log ${USAGE_DIR}/query.txt \
        --plot ${USAGE_DIR}/query.png \
        --include-children > /dev/null

    cleanup
    sleep 1

    NUM_REPLIES=$(cat ${LOG_DIR}/query.txt | rg -i 'Received reply' | sort | uniq | wc --lines)
    if [ "$NUM_REPLIES" = "$NUM_PEERS" ]; then
        echo "passed." | tee -a ${LOG_DIR}/query.txt
    else
        echo "failed." | tee -a ${LOG_DIR}/query.txt
    fi
done

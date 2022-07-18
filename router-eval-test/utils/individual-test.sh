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
EVAL_TIMEOUT=120
QUERY_TIMEOUT=30
WARMUP=30

export PYTHONWARNINGS="ignore"

cleanup

# for NUM_PEERS in {12..32}; do
for NUM_PEERS in 24; do
    echo -n "Testing $NUM_PEERS peers ... "
    psrecord "
        $ROUTER_PROGRAM_PATH \
            --listen "$ENDPOINT" > ${ROUTER_LOG_DIR}/${NUM_PEERS}.txt 2>&1
    " \
        --log ${ROUTER_USAGE_DIR}/${NUM_PEERS}.txt \
        --plot ${ROUTER_USAGE_DIR}/${NUM_PEERS}.png \
        --include-children > /dev/null &

    sleep 1

    for PEER_ID in $(seq 1 $NUM_PEERS); do
        psrecord "
            $EVAL_PROGRAM_PATH \
                --mode $EVAL_MODE \
                --num-peers 1 \
                --disable-multicast \
                --timeout $EVAL_TIMEOUT \
                --connect "$ENDPOINT" 2>&1 | tee ${EVAL_LOG_DIR}/${NUM_PEERS}-${PEER_ID}.txt
        " \
            --log ${EVAL_USAGE_DIR}/${NUM_PEERS}-${PEER_ID}.txt \
            --plot ${EVAL_USAGE_DIR}/${NUM_PEERS}-${PEER_ID}.png \
            --include-children &
    done

    sleep $WARMUP

    psrecord "
        $QUERY_PROGRAM_PATH \
            --mode 'peer' \
            --disable-multicast \
            --timeout $QUERY_TIMEOUT \
            --connect "$ENDPOINT" > ${QUERY_LOG_DIR}/${NUM_PEERS}.txt 2>&1
    " \
        --log ${QUERY_USAGE_DIR}/${NUM_PEERS}.txt \
        --plot ${QUERY_USAGE_DIR}/${NUM_PEERS}.png \
        --include-children > /dev/null

    cleanup
    sleep 1

    NUM_REPLIES=$(cat ${QUERY_LOG_DIR}/${NUM_PEERS}.txt | grep "\[Query\] Ended with" | cut -d ' ' -f 4)
    if [ "$NUM_REPLIES" = "$NUM_PEERS" ]; then
        echo "passed." | tee -a ${QUERY_LOG_DIR}/${NUM_PEERS}.txt
    else
        echo "failed." | tee -a ${QUERY_LOG_DIR}/${NUM_PEERS}.txt
    fi
done
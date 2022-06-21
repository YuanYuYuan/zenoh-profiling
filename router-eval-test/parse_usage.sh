#!/usr/bin/env bash

USAGE_DIR="$1"

if [ "" = "$USAGE_DIR" ]; then
    echo "Please specify the usage directory to be used."
    exit
fi

if [ ! -d "$USAGE_DIR" ]; then
    echo "The usage directory '$USAGE_DIR' not existed."
    exit
fi

OUTPUT_DIR="csv"
mkdir -p $OUTPUT_DIR
echo -n "Parsing $USAGE_DIR ... "
for f in $(ls $USAGE_DIR/*.txt); do
    OUT_FILE="${OUTPUT_DIR}/$(basename $f .txt).csv"
    cat $f | tr -s ' ' | sed 's/^ //g' | sed '1 s/.*/t,CPU,MEM,VMEM/' | sed 's/ /,/g' > $OUT_FILE
done

echo "done."

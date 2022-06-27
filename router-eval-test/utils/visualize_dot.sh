#!/usr/bin/env bash

compile() {
    dot_file=$1
    png_file=$(echo $dot_file | sed 's/network/visualization/')
    png_file=${png_file%.dot}.png
    mkdir -p $(dirname $png_file)
    dot $dot_file -T png > $png_file
}
for dot_file in $(ls ./outputs/network/*/*.dot); do
    compile $dot_file &
done
wait

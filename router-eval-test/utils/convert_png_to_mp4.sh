#!/usr/bin/env bash

plots_dir=$1
if [ ! -d $plots_dir ] || [ -z $plots_dir ]; then
    echo "PLOTS_DIR: $plots_dir not existed."
    echo "Usage: ./convert_png_to_mp4.sh PLOTS_DIR"
fi

out_dir="$(dirname $plots_dir)/videos"
mkdir -p $out_dir
for d in $(ls $plots_dir); do
    in_dir=${plots_dir}/${d}
    cat $(find ${plots_dir}/${d} -maxdepth 1 -name "*.png" | sort -V)  | ffmpeg -framerate 10 -i - -y -c:v libx265 -crf 0 -y ${out_dir}/${d}.mp4 &
done
wait

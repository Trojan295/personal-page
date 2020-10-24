#!/bin/bash

if [[ -z $1 ]]; then
    echo Please specify an path to the image
    exit 1
fi

if [[ -z $2 ]]; then
    echo Please specify the image size
    exit 1
fi

if [[ -z $3 ]]; then
    echo Please specify the image quality
    exit 1
fi

file=$1
size=$2
quality=$3

mogrify -resize $size $file
mogrify -strip -quality $quality $file

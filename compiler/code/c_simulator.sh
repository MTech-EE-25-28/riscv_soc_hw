#!/bin/bash

help() {
    # display help
   echo "Simulate the c program"
   echo
   echo "Usage: ./c_simulator.sh -h, -f <file_path>"
   echo "options:"
   echo "h     Print this Help."
   echo "f     Path of the C program file."
   echo
}

if [ "$#" -eq 2 ]; then
    while getopts "hf:" opt; do
        case "$opt" in
            f) file_path=$OPTARG ;;
            h) help ;;
            :) echo "argument missing for $ARG" ;;
            \?) echo "Something is wrong" ;;
        esac
    done
else
    help
    exit 1
fi

echo; echo "================================"
echo; echo "          C Simulator           ";
echo; echo "--------------------------------"; echo

echo "Executing file: $file_path"

echo; echo "================================"; echo

if [ ! -f "$file_path" ]; then
    echo "File $file_path does not exist."
    exit 1
fi

gcc "$file_path" -o output_file
if [ $? -ne 0 ]; then
    echo; echo "Compilation failed, kindly check for errors."
    exit 1
fi

./output_file
rm -f output_file
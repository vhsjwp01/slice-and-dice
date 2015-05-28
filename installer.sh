#!/bin/bash
#set -x

BASE_DIR=""
START_DIR=`dirname "${0}"`
cd "${START_DIR}" && BASE_DIR=`pwd`

if [ "${BASE_DIR}" != "" ]; then
    TARGET_DIR="/usr/local/bin"
    SOURCE_FILES=`ls *.pl | sed -e 's?\.pl$??g'`
    
    for i in ${SOURCE_FILES} ; do
        cp "${BASE_DIR}/${i}.pl" "${TARGET_DIR}" && 
        ln -s "${TARGET_DIR}/${i}.pl" "${TARGET_DIR}/${i}" ||
        echo "Could not create targets in directory \"${TARGET_DIR}\""
    done

else
    echo "Could not determine base directory"
fi

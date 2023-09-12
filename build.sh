#!/bin/bash -xe
set -xe

source share/scripts/helper-functions.sh

function skip(){
    local target="x86"
    parseArgs $@

    if [ "${clean}" == "true" ]; then 
        return 0
    fi

    local builddir="${target}-build"
    local SHA="$(sudo git config --global --add safe.directory .;sudo git rev-parse --verify --short HEAD)"
    local package="${library}-${SHA}-${target}.tar.xz"

    if [ "$target" == "mingw" ] && \
        [ -f "${builddir}/libssl-3-x64.dll" ] && \
        [ -f "${builddir}/libcrypto-3-x64.dll" ] && \
        [ -f "${builddir}/${package}" ]; then 
        return 1
    elif [ "$target" == "x86" ] && \
        [ -f "${builddir}/libssl.so.3" ] && \
        [ -f "${builddir}/libcrypto.so.3" ] && \
        [ -f "${builddir}/${package}" ]; then 
        return 1
    elif [ "$target" == "arm" ] && \
        [ -f "${builddir}/libssl.so.3" ] && \
        [ -f "${builddir}/libcrypto.so.3" ] && \
        [ -f "${builddir}/${package}" ]; then 
        return 1
    fi
    return 0
}

function build(){
    local clean=""
    local target="x86"
    parseArgs $@
    
    local builddir="${target}-build"
    # local postfix="-1.1.1t"

    if [ "$clean" == "true" ]; then
        rm -fr ${builddir}
    fi

    # local script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
    mkdir -p "${builddir}"
    pushd "${builddir}"
    #CROSS_COMPILE="x86_64-w64-mingw32-" \
    if [ "$target" == "mingw" ]; then
        source "../share/toolchains/x86_64-w64-mingw32.sh"
        ../Configure mingw64 no-asm shared --openssldir=$PWD/../mingw64
    elif [ "$target" == "arm" ]; then
        local perl=$(sudo find ${SDK_DIR} -name perl)
        # sudo mv -f ${SDK_DIR}/sysroots/x86_64-fslcsdk-linux/usr/bin/perl ${SDK_DIR}/sysroots/x86_64-fslcsdk-linux/usr/bin/perl.backup
        sudo ln -sf /usr/bin/perl ${perl}
        source "${SDK_DIR}/environment-setup-cortexa72-oe-linux"
        unset CROSS_COMPILE
        ../Configure linux-armv4 no-asm shared
    else
 		export STRIP="$(which strip)"
       ../Configure linux-x86_64 no-asm shared
    fi
    VERBOSE=1 make -j
    popd
}

function main(){
    local library="openssl"
    local target="x86"
    parseArgs $@

    skip $@ library="${library}"
    build $@
    
    local builddir="/tmp/${library}/${target}-build" # $(mktemp -d)/installs
    copyBuildFilesToInstalls $@ builddir="${builddir}"
    mv ${builddir}/installs/include/include/crypto/* ${builddir}/installs/include/crypto/
    
    mkdir -p ${builddir}/installs/include/openssl
    mv ${builddir}/installs/include/include/openssl/* ${builddir}/installs/include/openssl/
    mv ${builddir}/installs/include/${target}-build/include/openssl/* ${builddir}/installs/include/openssl/
    compressInstalls $@ builddir="${builddir}" library="${library}"
}

time main $@
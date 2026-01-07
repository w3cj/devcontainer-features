#!/usr/bin/env bash

clean_download() {
    url=$1
    output_location=$2
    tempdir=$(mktemp -d)
    downloader_installed=""

    function _apt_get_install() {
        tempdir=$1

        # Copy apt list state to revert later (minimize container layer size)
        cp -p -R /var/lib/apt/lists $tempdir
        apt-get update -y
        apt-get -y install --no-install-recommends wget ca-certificates
    }

    function _apt_get_cleanup() {
        tempdir=$1

        apt-get -y purge wget --auto-remove

        rm -rf /var/lib/apt/lists/*
        rm -r /var/lib/apt/lists && mv $tempdir/lists /var/lib/apt/lists
    }

    function _apk_install() {
        tempdir=$1
        # Copy apk cache state to revert later (minimize container layer size)
        cp -p -R /var/cache/apk $tempdir

        apk add --no-cache wget
    }

    function _apk_cleanup() {
        tempdir=$1

        apk del wget
    }

    # Use existing wget or curl if available
    if type curl >/dev/null 2>&1; then
        downloader=curl
    elif type wget >/dev/null 2>&1; then
        downloader=wget
    else
        downloader=""
    fi

    # Install wget temporarily if no downloader available
    if [ -z $downloader ]; then
        if [ -x "/usr/bin/apt-get" ]; then
            _apt_get_install $tempdir
        elif [ -x "/sbin/apk" ]; then
            _apk_install $tempdir
        else
            echo "distro not supported"
            exit 1
        fi
        downloader="wget"
        downloader_installed="true"
    fi

    if [ $downloader = "wget" ]; then
        wget -q $url -O $output_location
    else
        curl -sfL $url -o $output_location
    fi

    # Cannot use `trap X RETURN` because Alpine lacks bash (RETURN is not valid in sh)
    if ! [ -z $downloader_installed ]; then
        if [ -x "/usr/bin/apt-get" ]; then
            _apt_get_cleanup $tempdir
        elif [ -x "/sbin/apk" ]; then
            _apk_cleanup $tempdir
        else
            echo "distro not supported"
            exit 1
        fi
    fi

}

ensure_nanolayer() {
    local variable_name=$1
    local required_version=$2

    if ! [[ $required_version == v* ]]; then
        required_version=v$required_version
    fi

    local nanolayer_location=""

    if [[ -z "${NANOLAYER_FORCE_CLI_INSTALLATION}" ]]; then
        if [[ -z "${NANOLAYER_CLI_LOCATION}" ]]; then
            if type nanolayer >/dev/null 2>&1; then
                echo "Found a pre-existing nanolayer in PATH"
                nanolayer_location=nanolayer
            fi
        elif [ -f "${NANOLAYER_CLI_LOCATION}" ] && [ -x "${NANOLAYER_CLI_LOCATION}" ]; then
            nanolayer_location=${NANOLAYER_CLI_LOCATION}
            echo "Found a pre-existing nanolayer which were given in env variable: $nanolayer_location"
        fi

        if ! [[ -z "${nanolayer_location}" ]]; then
            local current_version
            current_version=$($nanolayer_location --version)
            if ! [[ $current_version == v* ]]; then
                current_version=v$current_version
            fi

            if ! [ $current_version == $required_version ]; then
                echo "skipping usage of pre-existing nanolayer. (required version $required_version does not match existing version $current_version)"
                nanolayer_location=""
            fi
        fi

    fi

    # Download temporarily if no existing installation found
    if [[ -z "${nanolayer_location}" ]]; then

        if [ "$(uname -sm)" == "Linux x86_64" ] || [ "$(uname -sm)" == "Linux aarch64" ]; then
            tmp_dir=$(mktemp -d -t nanolayer-XXXXXXXXXX)

            clean_up() {
                ARG=$?
                rm -rf $tmp_dir
                exit $ARG
            }
            trap clean_up EXIT

            if [ -x "/sbin/apk" ]; then
                clib_type=musl
            else
                clib_type=gnu
            fi

            tar_filename=nanolayer-"$(uname -m)"-unknown-linux-$clib_type.tgz

            clean_download https://github.com/devcontainers-extra/nanolayer/releases/download/$required_version/$tar_filename $tmp_dir/$tar_filename

            tar xfzv $tmp_dir/$tar_filename -C "$tmp_dir"
            chmod a+x $tmp_dir/nanolayer
            nanolayer_location=$tmp_dir/nanolayer

        else
            echo "No binaries compiled for non-x86-linux architectures yet: $(uname -m)"
            exit 1
        fi
    fi

    # Expose outside the resolved location
    declare -g ${variable_name}=$nanolayer_location

}

#! /bin/bash

set -e

source conf/env
source lib/common

if [[ EUID -ne 0 ]] ; then
    die "Root privilege is required to run setup script"
fi

packages=(
    git
    devscripts
    cowbuilder
    eatmydata
    git-review
)

sudoers=examples/sudoers

info "Install required packages"
apt-get install ${packages[@]}

if [[ -f ${sudoers} ]] ; then
    info "Install sudoers configuration"
    install -m 600 -v $sudoers /etc/sudoers.d/deepin.conf
fi

info "create executable link"
ln -sfv ${scriptdir}/deepin-buildpkg /usr/local/bin

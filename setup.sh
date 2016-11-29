#! /bin/bash

set -e

declare -r scriptdir=$(dirname $(readlink -ef $0))

source conf/env
source lib/common

if [[ EUID -ne 0 ]] ; then
    die "Root privilege is required to run setup script"
fi

packages=(
    build-essential
    cowbuilder
    devscripts
    eatmydata
    git
    git-review
    tmux
    quilt
    dput
)

sudoers=examples/sudoers

info "Install required packages"
apt-get install ${packages[@]}

if [[ -f ${sudoers} ]] ; then
    info "Install sudoers configuration"
    install -m 600 -v $sudoers /etc/sudoers.d/deepin_pbuilder
fi

info "create executable link"
ln -sfv ${scriptdir}/cowimage /usr/local/bin
ln -sfv ${scriptdir}/deepin-buildpkg /usr/local/bin

mkdir -pv ${WORKBASE}/artifacts

if [[ -d ${WORKBASE}/pkg_debian/.git ]] ; then
	info "A copy of pkg_debian repository has been detected"
else
	info "clone pkg_debian repository"
	git clone https://github.com/linuxdeepin/pkg_debian.git ${WORKBASE}/pkg_debian
fi

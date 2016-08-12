#! /bin/bash
# TODO:
#	1. rewrite
# 	2. add gerrit/git-review support

set -e

declare -r WORKBASE=/mnt/packages
declare -r BASEURI='http://cr.deepin.io'
declare -r REPOBASE=${WORKBASE}/git-repos
declare -r BOPTS="-e USE_GGCGO=1 -e CGO_ENABLED=1 -us -uc -sa -j8"
declare -r SVERSION="v0.0.1"
declare PKGVER=

declare -r dde_components=(
    dde-account-faces
    dde-api
    dde-calendar
    dde-control-center
    dde-daemon
    dde-desktop
    dde-dock
    dde-file-manager
    dde-help
    dde-launcher
    dde-session-ui
    libdui
    startdde
)

declare -r raccoon_components=(
    dbus-factory
    dde-control-center
    dde-daemon
    dde-desktop
    dde-dock
    dde-launcher
    dde-session-ui
    deepin-desktop-schemas
    deepin-desktop-base
)

printVersion() {
    echo "$0 version $SVERSION"
    exit 0
}

printHelp() {
    cat <<EOF >&2
Usage:
  $0 [-c changelog] [-l clnumber] -n pkgname -w workdir [-b] [-h] [-v]

Build script for deepin mipsel package team

Help Options:
  -h, --help            Show help options
Application Options:
  -c, --changelog=CHANGE    Use CHANGE as debian package changelog      
  -l, --cl=NUMBER       Build package based on CL: NUMBER
  -n, --pkgname=PKGNAME     Build PKGNAME
  -w, --workdir=DIR     Override the default workdir
  -b, --build           Start the real build, otherwise the script will
                                just do preparation for a package build
  -v, --version         Show version
EOF
    exit 0
}

die() {
    echo "$BASH_LINENO: $@" >&2
    exit 1
}

assert() {
    local ret
    eval ret=\$${1}
    [[ -n $ret ]] || die "I'm confused, var: ${1} is empty"
}

pushd() {
    builtin pushd $@ >& /dev/null
}

popd() {
    builtin popd $@ >& /dev/null
}

contains() {
    local element
    local result=1
    for element in ${@:2}; do
    if [[ $element == $1 ]] ; then
        result=0
        break
    fi
    done
    echo $result
}

createdir() {
    local dir=$1
    local desc=$2
    if [[ ! -d ${dir} ]];then
        echo "create $2 directory: $dir"
        mkdir -p $dir
    fi
}

has_patch() {
    if [[ -d $patchdir ]] ; then
        return 0
    else
        return 1
    fi
}

pkgIsDebianized() {
    if [[ -d debian ]] ; then
        return 0
    else
        return 1
    fi
}

dquilt() {
    quilt --quiltrc=${HOME}/.quiltrc-dpkg -f $@
}

debsrcFormatter() {
    local sformat=
    local sformatfile=debian/source/format
    local quilt="3.0 (quilt)"

    if [[ -f $sformatfile ]] ; then
        sformat=$(cat $sformatfile)
    fi

    if [[ $sformat =~ 3.0[[:space:]]\((native|quilt)\) ]] ; then
	echo "${pkgname} has debsrc 3.0 format: $sformat"
    fi

    if has_patch; then
        echo "Found patches, set package source format to debsrc 3.0 quilt"
        sformat=$quilt
        createdir ${sformatfile//format}; echo $sformat > ${sformatfile}
    fi

    if [[ $sformat == $quilt ]] ; then
        PKGVER="${PKGVER}-1"
        echo -e "\n\n\n\n\t\t\tI'm here PKGVER=${PKGVER}\n\n\n"
    fi
}

fixBuildDeps() {
	
}

apply_patches() {
    pkgIsDebianized || \
        die "You should debianize your package, workdir: $PWD!!!"

    if has_patch $patchdir ; then
	debsrcFormatter

        for patch in $patchdir/*.patch; do
            echo "Import mipsel specific patch: $(basename $patch)"
            dquilt import $patch
        done
    fi
}

print_build_info() {
cat <<EOF
We're working on
    pkgname:		$pkgname
    workdir:		$workdir
    changelog:		$changelog
    CL:			$cl
    repository:		$repository
EOF
}

[[ $EUID -eq 0 ]] && die "Don't build package with priviledged users"

OPTS=$(getopt -n build-package -o 'c:l:n:w:bhv' \
          --long changelog:,cl:,pkgname:,workdir:,build,help,version -- "$@")

[[ $? -eq 0 ]] || die "Something went wrong!!!"

eval set -- "${OPTS}"

while : ; do
    case $1 in
        -c|--changelog)
        changelog=$2
        shift 2
        ;;
        -l|--cl)
        if [[ $2 =~ [0-9]+ ]]; then
            cl=$2
        else
            echo "CL is ilegal"
            exit 3
        fi
        shift 2
        ;;
        -n|--pkgname)
        pkgname=$2
        shift 2
        ;;
        -w|--workdir)
        workdir=${WORKBASE}/${2}
        shift 2
        ;;
            -b|--build)
        do_build=0
        shift
        ;;
            -v|--version)
        printVersion
        shift
        ;;
        -h|--help)
        printHelp
        shift
        ;;
        --)
        shift
        break
        ;;
        *)
        printHelp
        shift
        ;;
    esac
done

assert pkgname

# sane default values
[[ -z $workdir ]]      && workdir=${WORKBASE}/${pkgname}
[[ -z $changelog ]]    && changelog="Rebuild on mipsel"

createdir $workdir
createdir $REPOBASE

# set git repository
if [[ $(contains $pkgname ${dde_components[@]}) -eq 0 ]]; then
    repository=${BASEURI}/dde/${pkgname}
else
    repository=${BASEURI}/${pkgname}
fi

patchdir=${WORKBASE}/patches/${pkgname}

make_orig_tarball() {
    local work_branch=master
    local repodir=${REPOBASE}/${pkgname}
    local has_raccoon=$(contains ${pkgname} ${raccoon_components[@]})

    if [[ $has_raccoon -eq 0 ]] ; then
        work_branch=raccoon
    fi

    # fetch git repository
    [[ -d ${repodir}/.git ]] || git clone ${repository} ${repodir}

    pushd ${repodir}

    git pull origin ${work_branch}
    git checkout ${work_branch}

    local commit_id=$(git rev-parse HEAD | cut -b 1-6)
    assert commit_id
    local tag=$(git describe --tags --abbrev=0)
    local revision=$(git log ${tag}..origin/${work_branch} --oneline | wc -l)
    assert revision

    if [[ -z ${tag} ]] ;then
        echo "tag fallback to 0.1"  
            tag=0.1
    fi
    assert tag

    PKGVER=$tag+r${revision}~${commit_id}

    echo "Create ${pkgname} upstream source tarball..."
    git archive --format=tar --prefix=${pkgname}-${PKGVER}/ HEAD | \
        xz -z > ${workdir}/${pkgname}_${PKGVER}.orig.tar.xz

    popd
}

prepare_build() {
    rm -rf ${workdir}/${pkgname}-${PKGVER}
    pushd ${workdir}
    tar xf ${pkgname}_${PKGVER}.orig.tar.xz
    popd

    pushd ${workdir}/${pkgname}-${PKGVER}
    if ! pkgIsDebianized ; then
        cp -a ${WORKBASE}/pkg_debian/${pkgname}/debian .
    fi
    popd
}

build_package() {
    pushd ${workdir}/${pkgname}-${PKGVER}

    apply_patches

    if [[ $do_build -eq 0 ]] ; then
        dch -v ${PKGVER} -D unstable $changelog
        debuild ${BOPTS}
    fi
    popd
}

make_orig_tarball
prepare_build
build_package

#!/bin/bash
#
# Copyright (c) 2014, Intel Corporation
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in
#       the documentation and/or other materials provided with the
#       distribution.
#
#     * Neither the name of Intel Corporation nor the names of its
#       contributors may be used to endorse or promote products derived
#       from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#
# build-dpkg.sh - Script for building deb packages
#

SCRIPT_DIR=$(dirname $0)
source $SCRIPT_DIR/pkg-common.sh

if [ "$#" != "4" ]
then
	echo "Usage: $(basename $0) VERSION_TAG SOURCE_DIR WORKING_DIR OUT_DIR"
	exit 1
fi

PACKAGE_VERSION_TAG=$1
SOURCE=$2
WORKING_DIR=$3
OUT_DIR=$4

function convert_changelog() {
	while read line
	do
		if [[ $line =~ $REGEX_DATE_AUTHOR ]]
		then
			DATE="${BASH_REMATCH[1]}"
			AUTHOR="${BASH_REMATCH[2]}"
			echo "  * ${DATE} ${AUTHOR}"
		elif [[ $line =~ $REGEX_MESSAGE_START ]]
		then
			MESSAGE="${BASH_REMATCH[1]}"
			echo "  - ${MESSAGE}"
		elif [[ $line =~ $REGEX_MESSAGE ]]
		then
			MESSAGE="${BASH_REMATCH[1]}"
			echo "    ${MESSAGE}"
		fi
	done < $1
}

check_tool debuild
check_tool dch
check_file $SCRIPT_DIR/pkg-config.sh

source $SCRIPT_DIR/pkg-config.sh

PACKAGE_VERSION=$(get_version $PACKAGE_VERSION_TAG)
PACKAGE_RELEASE=1
PACKAGE_SOURCE=${PACKAGE_NAME}-${PACKAGE_VERSION}
PACKAGE_TARBALL_ORIG=${PACKAGE_NAME}_${PACKAGE_VERSION}.orig.tar.gz

[ -d $WORKING_DIR ] || mkdir $WORKING_DIR
[ -d $OUT_DIR ] || mkdir $OUT_DIR

OLD_DIR=$PWD

cd $WORKING_DIR

check_dir $SOURCE

mv $SOURCE $PACKAGE_SOURCE
tar zcf $PACKAGE_TARBALL_ORIG $PACKAGE_SOURCE

cd $PACKAGE_SOURCE

mkdir debian

# Generate compat file
cat << EOF > debian/compat
9
EOF

# Generate control file
cat << EOF > debian/control
Source: $PACKAGE_NAME
Maintainer: $PACKAGE_MAINTAINER
Section: misc
Priority: optional
Standards-version: 3.9.4
Build-Depends: debhelper (>= 9), uuid-dev

Package: $PACKAGE_NAME
Architecture: any
Depends: \${shlibs:Depends}, \${misc:Depends}
Description: $PACKAGE_SUMMARY
$(echo $PACKAGE_DESCRIPTION | sed 's/^/ /')

Package: $PACKAGE_NAME-dev
Section: libdevel
Architecture: any
Depends: $PACKAGE_NAME (=\${binary:Version}), uuid-dev, \${shlibs:Depends}, \${misc:Depends}
Description: Development files for $PACKAGE_NAME
$(echo $PACKAGE_DESCRIPTION | sed 's/^/ /')

Package: $PACKAGE_NAME-dbg
Section: debug
Priority: extra
Architecture: any
Depends: $PACKAGE_NAME (=\${binary:Version}), $PACKAGE_NAME-dev (=\${binary:Version}), uuid-dev, \${shlibs:Depends}, \${misc:Depends}
Description: Debug symbols for $PACKAGE_NAME
$(echo $PACKAGE_DESCRIPTION | sed 's/^/ /')
EOF

cp LICENSE debian/copyright

cat << EOF > debian/rules
#!/usr/bin/make -f
#export DH_VERBOSE=1
%:
	dh \$@

override_dh_strip:
	dh_strip --dbg-package=$PACKAGE_NAME-dbg

override_dh_auto_test:
	dh_auto_test
	cp src/test/testconfig.sh.example src/test/testconfig.sh
	make check
EOF

chmod +x debian/rules

mkdir debian/source

cat << EOF > debian/source/format
3.0 (quilt)
EOF

cat << EOF > debian/$PACKAGE_NAME.triggers
interest man-db
EOF

cat << EOF > debian/$PACKAGE_NAME.install
usr/lib/libpmem.so.*
usr/lib/libvmem.so.*
EOF

cat << EOF > debian/$PACKAGE_NAME-dev.install
usr/lib/nvml_debug/libpmem.a usr/lib/nvml_dbg/
usr/lib/nvml_debug/libvmem.a usr/lib/nvml_dbg/
usr/lib/nvml_debug/libpmem.so	usr/lib/nvml_dbg/
usr/lib/nvml_debug/libpmem.so.* usr/lib/nvml_dbg/
usr/lib/nvml_debug/libvmem.so	usr/lib/nvml_dbg/
usr/lib/nvml_debug/libvmem.so.* usr/lib/nvml_dbg/
usr/lib/libpmem.so
usr/lib/libvmem.so
usr/include/*
usr/share/man/man3/*
EOF

ITP_BUG_EXCUSE="# This is our first package but we do not want to upload it yet.
# Please refer to Debian Developer's Reference section 5.1 (New packages) for details:
# https://www.debian.org/doc/manuals/developers-reference/pkgs.html#newpackage"

cat << EOF > debian/$PACKAGE_NAME.lintian-overrides
# We want to keep both libraries in the same package
package-name-doesnt-match-sonames *
$ITP_BUG_EXCUSE
new-package-should-close-itp-bug
EOF

cat << EOF > debian/$PACKAGE_NAME-dev.lintian-overrides
$ITP_BUG_EXCUSE
new-package-should-close-itp-bug
# The following warnings are triggered by a bug in debhelper:
# http://bugs.debian.org/204975
postinst-has-useless-call-to-ldconfig
postrm-has-useless-call-to-ldconfig
# We do not want to compile with -O2 for debug version
hardening-no-fortify-functions usr/lib/nvml_dbg/*
EOF

cat << EOF > debian/$PACKAGE_NAME-dbg.lintian-overrides
$ITP_BUG_EXCUSE
new-package-should-close-itp-bug
EOF

# Convert ChangeLog to debian format
CHANGELOG_TMP=changelog.tmp
dch --create --empty --package $PACKAGE_NAME -v $PACKAGE_VERSION-$PACKAGE_RELEASE -M -c $CHANGELOG_TMP
touch debian/changelog
head -n1 $CHANGELOG_TMP >> debian/changelog
echo "" >> debian/changelog
convert_changelog ChangeLog >> debian/changelog
echo "" >> debian/changelog
tail -n1 $CHANGELOG_TMP >> debian/changelog
rm $CHANGELOG_TMP

# This is our first release but we do
debuild -us -uc

cd $OLD_DIR

find $WORKING_DIR -name "*.deb"\
              -or -name "*.dsc"\
	      -or -name "*.changes"\
	      -or -name "*.orig.tar.gz"\
	      -or -name "*.debian.tar.gz" | while read FILE
do
	mv -v $FILE $OUT_DIR/
done

exit 0

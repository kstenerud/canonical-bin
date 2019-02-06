#!/bin/bash

set -eu

print_usage()
{
	echo "Usage: $(basename $0) <ubuntu release> <package>"
	echo "Usage: $(basename $0) <ubuntu release> <package> <bug number>"
}

if [ $# -lt 2 ]; then
	print_usage
	exit 1
fi

LP_USERNAME=$(grep lpuser ~/.gitconfig |sed 's/.*lpuser = \(.*\)/\1/g')

if [ -z "$LP_USERNAME" ]; then
	(>&2 "Please add your launchpad username to your global .gitconfig")
	exit 1
fi

UBUNTU_RELEASE="$1"
DEBIAN_RELEASE=sid
PACKAGE="$2"
UBUNTU_VERSION=$(rmadison $PACKAGE |grep $UBUNTU_RELEASE | sed 's/[^|]*| \([^ ]*\).*/\1/g' | tail -1)
DEBIAN_VERSION=$(rmadison -u debian $PACKAGE |grep unstable | sed 's/[^|]*| \([^ ]*\).*/\1/g' | tail -1)
ORIG_VERSION=$(echo $DEBIAN_VERSION | sed 's/\([^-]*\).*/\1/g')

if [[ ${UBUNTU_VERSION} == ${DEBIAN_VERSION}* ]]; then
	(>&2 echo "It looks like the latest debian is already merged (debian $DEBIAN_VERSION vs ubuntu $UBUNTU_VERSION)")
	exit 1
fi

if [ $# -ne 3 ]; then
	(>&2 echo "Go to https://bugs.launchpad.net/ubuntu/+source/$PACKAGE")
	(>&2 echo "Summary: Please merge $DEBIAN_VERSION into $UBUNTU_RELEASE")
    (>&2 echo "Description: tracking bug")
    (>&2 echo "Then, re-run this command including the bug number")
    exit 1
fi
BUG_NUMBER="$3"


if [ -z "$UBUNTU_VERSION" ]; then
	(>&2 echo "Error: Could not determine ubuntu version of $PACKAGE")
fi

if [ -z "$DEBIAN_VERSION" ]; then
	(>&2 echo "Error: Could not determine debian version of $PACKAGE")
fi

echo "Merge $PACKAGE $DEBIAN_VERSION into $UBUNTU_RELEASE
=========================================================

 * Orig Version: $ORIG_VERSION
 * Debian Version: $DEBIAN_VERSION
 * Ubuntu Version: $UBUNTU_VERSION
 * Bug URL: https://bugs.launchpad.net/ubuntu/+source/$PACKAGE/+bug/$BUG_NUMBER
 * PPA URL: https://launchpad.net/~${LP_USERNAME}/+archive/ubuntu/${UBUNTU_RELEASE}-${PACKAGE}-merge-${BUG_NUMBER}
 * MP URL: TODO
"

echo "
-----------------------------------------------------------
### [ ] Check existing bug entries

https://bugs.launchpad.net/ubuntu/+source/$PACKAGE
"

echo "
-----------------------------------------------------------
### [ ] Clone the package repository

\`\`\`
git ubuntu clone $PACKAGE
\`\`\`
"

echo "
-----------------------------------------------------------
### [ ] Start a Git Ubuntu Merge

\`\`\`
git ubuntu merge start ubuntu/devel --bug $BUG_NUMBER
git checkout -b merge-${DEBIAN_VERSION}-${UBUNTU_RELEASE}
\`\`\`

#### [ ] Failed? Do it manually

\`\`\`
git checkout -b merge-${DEBIAN_VERSION}-${UBUNTU_RELEASE}
\`\`\`

#### [ ] Create tags

\`\`\`
git log | grep 'tag: pkg/import' | grep -v ubuntu | head -1

git tag lp${BUG_NUMBER}/old/ubuntu pkg/ubuntu/${UBUNTU_RELEASE}-devel
git tag lp${BUG_NUMBER}/old/debian the-commit-hash
git tag lp${BUG_NUMBER}/new/debian pkg/debian/$DEBIAN_RELEASE
\`\`\`

#### [ ] Start a rebase

    git rebase -i lp${BUG_NUMBER}/old/debian

#### [ ] Clear any history prior to, and including import of $DEBIAN_VERSION

#### [ ] Create reconstruct tag

\`\`\`
git ubuntu tag --reconstruct --bug $BUG_NUMBER
\`\`\`
"

echo "
-----------------------------------------------------------
### Deconstruct Commits

#### [ ] Check if there are commits to split

\`\`\`
git log --oneline
\`\`\`

Get all commit hashes since old/debian, and look for changelog:

\`\`\`
git show [hash] | diffstat
\`\`\`

#### [ ] Commits to split?

 1. Start a rebase: \`git rebase -i lp${BUG_NUMBER}/old/debian\`
 2. Change the commit(s) you're going to deconstruct from \`pick\` to \`edit\`.
 3. git reset to get your changes back: \`git reset HEAD^\`
 4. Add commits in logical units

#### [ ] Tag Deconstructed

\`\`\`
git ubuntu tag --deconstruct --bug $BUG_NUMBER
\`\`\`
"

echo "
-----------------------------------------------------------
### [ ] Prepare the Logical View

\`\`\`
git rebase -i lp${BUG_NUMBER}/old/debian
\`\`\`

* Delete imports, etc
* Delete changelog, maintainer
* Possibly rearrange commits if it makes logical sense
* Squash multiple changes to same file, reverts, etc

#### [ ] Check the result

Differences only in changelog and control:

\`\`\`
git diff lp${BUG_NUMBER}/deconstruct/${UBUNTU_VERSION} |diffstat
\`\`\`

#### [ ] Create logical tag

\`\`\`
git ubuntu tag --logical --bug $BUG_NUMBER
\`\`\`

### [ ] Failed? Do it manually

Use the version number of the last ubuntu change.

\`\`\`
git tag -a -m \"Logical delta of $UBUNTU_VERSION\" lp${BUG_NUMBER}/logical/$UBUNTU_VERSION
\`\`\`
"

echo "
-----------------------------------------------------------
### [ ] Rebase onto New Debian

\`\`\`
git rebase -i --onto lp${BUG_NUMBER}/new/debian lp${BUG_NUMBER}/old/debian
\`\`\`

Deal with conflicts:

\`\`\`
git add blah/something
git rebase --continue
\`\`\`

### [ ] Check that the patches still apply cleanly:

\`\`\`
quilt push -a --fuzz=0
quilt pop -a
\`\`\`
"

echo "
-----------------------------------------------------------
### [ ] Finish the Merge

    git ubuntu merge finish ubuntu/devel --bug $BUG_NUMBER

#### [ ] Failed? Finish the merge manually

\`\`\`
git show lp${BUG_NUMBER}/new/debian:debian/changelog >/tmp/debnew.txt
git show lp${BUG_NUMBER}/old/ubuntu:debian/changelog >/tmp/ubuntuold.txt
merge-changelog /tmp/debnew.txt /tmp/ubuntuold.txt >debian/changelog 
git commit -m \"Merge changelogs\" debian/changelog
dch -i
git commit -m \"changelog: Merge of $DEBIAN_VERSION\" debian/changelog
update-maintainer
git commit -m \"Update maintainer\" debian/control
\`\`\`
"

echo "
-----------------------------------------------------------
### [ ] Fix the Changelog

#### [ ] Add dropped changes

#### [ ] Commit the changelog fix:

\`\`\`
git commit debian/changelog -m changelog
\`\`\`

#### [ ] Rebase and squash changelog into reconstruct-changelog

\`\`\`
git rebase -i lp${BUG_NUMBER}/new/debian
\`\`\`
"

echo "
-----------------------------------------------------------
### [ ] Get orig tarball

\`\`\`
git ubuntu export-orig
\`\`\`

#### [ ] Failed? Get orig tarball manually

\`\`\`
git checkout -b pkg/importer/debian/pristine-tar
pristine-tar checkout ${PACKAGE}_${ORIG_VERSION}.orig.tar.gz
git checkout merge-${DEBIAN_VERSION}-${UBUNTU_RELEASE}
\`\`\`

#### [ ] Failed?

Where ~/work/packages/ubuntu/ is the directory above your git ubuntu clone:

\`\`\`
git checkout merge-${DEBIAN_VERSION}-${UBUNTU_RELEASE}
cd /tmp
pull-debian-source $PACKAGE
mv ${PACKAGE}_${ORIG_VERSION}.orig.tar.* ~/work/packages/ubuntu/
cd -
\`\`\`
"

echo "
-----------------------------------------------------------
### [ ] Check the source for errors

\`\`\`
git ubuntu lint --target-branch debian/sid --lint-namespace lp${BUG_NUMBER}
\`\`\`

"

echo "
-----------------------------------------------------------
### [ ] Build source package

\`\`\`
dpkg-buildpackage -S -nc -d -sa -v${UBUNTU_VERSION}
\`\`\`

#### [ ] Check the built package for errors

\`\`\`
lintian --pedantic --display-info --verbose --info --profile ubuntu ../${PACKAGE}_${UBUNTU_VERSION}.dsc
\`\`\`
"

echo "
-----------------------------------------------------------
### [ ] Push to your launchpad repository

\`\`\`
git push $LP_USERNAME
\`\`\`

#### [ ] Push your lp tags

\`\`\`
git push $LP_USERNAME \$(git tag |grep $BUG_NUMBER | xargs)
\`\`\`
"

echo "
-----------------------------------------------------------
### [ ] Create a PPA repository

https://launchpad.net/~${LP_USERNAME}/+activate-ppa

Name: ${UBUNTU_RELEASE}-${PACKAGE}-merge-${BUG_NUMBER}

#### [ ] Enable all architectures in PPA

### [ ] Upload files

\`\`\`
dput ppa:${LP_USERNAME}/${UBUNTU_RELEASE}-${PACKAGE}-merge-${BUG_NUMBER} ../${PACKAGE}_${UBUNTU_VERSION}_source.changes
\`\`\`

#### [ ] Wait for packages to be ready

 * https://launchpad.net/~${LP_USERNAME}/+archive/ubuntu/${UBUNTU_RELEASE}-${PACKAGE}-merge-${BUG_NUMBER}
 * https://launchpad.net/~${LP_USERNAME}/+archive/ubuntu/${UBUNTU_RELEASE}-${PACKAGE}-merge-${BUG_NUMBER}/+packages
"

echo "
-----------------------------------------------------------
### [ ] Test the New Build

 * Package tests
 * Install, upgrade
"

echo "
-----------------------------------------------------------
### [ ] Submit Merge Proposal

\`\`\`
git ubuntu submit --reviewer canonical-server-packageset-reviewers --target-branch debian/sid
\`\`\`
"

echo "
-----------------------------------------------------------
### [ ] Update the merge proposal

Example:

    PPA: https://launchpad.net/~$LP_USERNAME/+archive/ubuntu/${UBUNTU_RELEASE}-${PACKAGE}-merge-${BUG_NUMBER}

    Basic test:

    echo \"echo abc >test.txt\" | at now + 1 minute && sleep 1m && cat test.txt && rm test.txt

    Package tests:

    This package contains no tests.

### [ ] Open the review

Change the MP status from \"work in progress\" to \"needs review\"
"

#!/bin/sh
# @COPYRIGHT@

# Create a tarball from the latest wikitest files

if [ -e $ST_CURRENT/nlw/share/workspaces/wikitests/wikitests.1.tar.gz ]; then
    echo DELETING old wikitests.1.tar.gz
    rm $ST_CURRENT/nlw/share/workspaces/wikitests/wikitests.1.tar.gz
fi

echo CREATING new wikitests.1.tar.gz
$ST_CURRENT/nlw/bin/st-admin export-workspace --w wikitests --dir $ST_CURRENT/nlw/share/workspaces/wikitests/
cp $ST_CURRENT/nlw/share/workspaces/wikitests/wikitests.1.tar.gz $ST_CURRENT/nlw/share/workspaces/wikitests/appliance

echo PACKAGING wikitests using dir2deb
dir2deb --dir $ST_CURRENT/nlw/share/workspaces/wikitests/appliance  --p wikitests  --description Package wikitests for appliances -X package.bash -X appliance-wikitests.tar.gz -X ".svn" --strip-outer-dir

echo CREATING new appliance-wikitests.tar.gz
tar zcf appliance-wikitests.tar.gz --exclude=".svn"  --exclude="*.deb" --exclude=appliance-wikitests.tar.gz --exclude="package.bash" *


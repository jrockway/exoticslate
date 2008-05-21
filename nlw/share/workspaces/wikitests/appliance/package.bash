#!/bin/sh
# @COPYRIGHT@

# Create  tarballs from the latest wikitest files


cd  $ST_CURRENT/nlw/share/workspaces/wikitests/appliance

if [ -e ~/.nlw/root/data/wikitests ]; then
    
    if [ -e $ST_CURRENT/nlw/share/workspaces/wikitests/wikitests.1.tar.gz ]; then
        echo DELETING old wikitests.1.tar.gz
        rm $ST_CURRENT/nlw/share/workspaces/wikitests/wikitests.1.tar.gz
    fi
    
    echo CREATING new wikitests.1.tar.gz
    $ST_CURRENT/nlw/bin/st-admin export-workspace --w wikitests --dir $ST_CURRENT/nlw/share/workspaces/wikitests/
    cp $ST_CURRENT/nlw/share/workspaces/wikitests/wikitests.1.tar.gz $ST_CURRENT/nlw/share/workspaces/wikitests/appliance
fi


if [ -e ~/.nlw/root/data/calctests ]; then
    if [ -e $ST_CURRENT/nlw/share/workspaces/calctests/calctests.1.tar.gz ]; then
        echo DELETING old calctests.1.tar.gz
        rm $ST_CURRENT/nlw/share/workspaces/calctests/calctests.1.tar.gz
    fi
    
    echo CREATING new calctests.1.tar.gz
    $ST_CURRENT/nlw/bin/st-admin export-workspace --w calctests --dir $ST_CURRENT/nlw/share/workspaces/calctests/
    cp $ST_CURRENT/nlw/share/workspaces/calctests/calctests.1.tar.gz $ST_CURRENT/nlw/share/workspaces/wikitests/appliance
fi

rm -rf $ST_CURRENT/nlw/share/workspaces/wikitests/appliance/usr

echo COPYING FILES FOR PACKAGING
mkdir -p $ST_CURRENT/nlw/share/workspaces/wikitests/appliance/usr/bin
cp  create-test-data-workspace fetch-test-data-tarball prep-wikitests run-wiki-tests $ST_CURRENT/nlw/share/workspaces/wikitests/appliance/usr/bin/

mkdir -p $ST_CURRENT/nlw/share/workspaces/wikitests/appliance/usr/share/nlw/wikitests
cp  do-wiki-tests  one-wiki-test  README  set-time  setup-selenium  wikitestfiles.zip  wikitests.1.tar.gz calctests.1.tar.gz $ST_CURRENT/nlw/share/workspaces/wikitests/appliance/usr/share/nlw/wikitests/

echo PACKAGING wikitests using dir2deb
rm -f $ST_CURRENT/nlw/share/workspaces/wikitests/appliance/wikitests*.deb
dir2deb --dir $ST_CURRENT/nlw/share/workspaces/wikitests/appliance/usr  --package  wikitests  --description Package wikitests for appliances  --dir-perms 777


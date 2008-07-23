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
else
    echo "There is no /wikitests wiki to export.  Run wikitests-to-wiki."
    echo EXITING
    exit
fi

echo FETCHING test-data.tar.gz
$ST_CURRENT/nlw/dev-bin/fetch-test-data-tarball

rm -rf $ST_CURRENT/nlw/share/workspaces/wikitests/appliance/usr

echo COPYING FILES FOR PACKAGING
mkdir -p $ST_CURRENT/nlw/share/workspaces/wikitests/appliance/usr/bin
RWT=`which run-wiki-tests`
STB=`which st-bootstrap-openldap`
cp $STB $RWT st-ldap  st-socialcalc prep-wikitests  $ST_CURRENT/nlw/share/workspaces/wikitests/appliance/usr/bin/

# fix up st-bootstrap-openldap so it will run as user www-data on an
# appliance.  Put the PID file in /tmp.
sed -i 's/\$ENV{HOME}/\/tmp/' $ST_CURRENT/nlw/share/workspaces/wikitests/appliance/usr/bin/st-bootstrap-openldap

mkdir -p $ST_CURRENT/nlw/share/workspaces/wikitests/appliance/usr/share/nlw/wikitests
cp ldap.yaml.st do-tests do-calc-tests do-wiki-tests  one-wiki-test aliases README  set-time  setup-selenium  test-data.tar.gz wikitestfiles.zip  wikitests.1.tar.gz $ST_CURRENT/nlw/share/workspaces/wikitests/appliance/usr/share/nlw/wikitests/

echo PACKAGING wikitests using dir2deb
rm -f $ST_CURRENT/nlw/share/workspaces/wikitests/appliance/wikitests*.deb
dir2deb --dir $ST_CURRENT/nlw/share/workspaces/wikitests/appliance/usr  --package  wikitests  --description Package wikitests for appliances  --dir-perms 777 --depends 'libtest-http-perl (>=0.11)'


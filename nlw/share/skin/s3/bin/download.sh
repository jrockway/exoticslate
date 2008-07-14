#!/bin/sh

files="
    dashboard.html
    contentPage.html
    listPage.html
    settings.html
    settings2.html
    revisionHistory.html
    weblog.html
    listPage2.html
    listPage3.html
    listPage4.html
"

for i in $files; do
    wget http://clients.araucariadesign.com/Socialtext/wiki/$i --user social --password guest -O html/$i
    sed -i 's/\t/    /g' html/$i
done

wget http://clients.araucariadesign.com/Socialtext/wiki/css/styles.css --user social --password guest -O css/styles.css
wget http://clients.araucariadesign.com/Socialtext/wiki/css/ieStyles.css --user social --password guest -O css/ieStyles.css
bin/fix-ids

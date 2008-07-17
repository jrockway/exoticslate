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

function get () {
    wget http://clients.araucariadesign.com/Socialtext/wiki/$1 --user social --password guest -O $2
}

for i in $files; do
    get $i html/$i
    sed -i 's/\t/    /g' html/$i
done

get css/styles.css css/styles.css
get css/ieStyles.css css/ieStyles.css

bin/fix-ids

for image in `grep '/images/' css/styles.css css/ieStyles.css | sed 's/.*\/images\/\(\w*\.\w*\).*/\1/' | uniq`; do
    get images/$image images/$image
    continue;
done

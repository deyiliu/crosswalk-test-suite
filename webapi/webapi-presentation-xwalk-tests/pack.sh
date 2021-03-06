#!/bin/bash
source $(dirname $0)/$(basename $(pwd)).spec

#parse params
usage="Usage: ./pack.sh [-t <package type: wgt | apk | crx | xpk | cordova>] [-m <apk mode: shared | embedded>] [-p <xpk platform: mobile | ivi>]
[-t wgt] option was set as default.
[-m embedded] option was set as default.
[-p mobile] option was set as default."

if [[ $1 == "-h" || $1 == "--help" ]]; then
    echo "$usage"
    exit 1
fi

type="wgt"
mode="embedded"
platform="mobile"
while getopts t:m:p: o
do
    case "$o" in
    t) type=$OPTARG;;
    m) mode=$OPTARG;;
    p) platform=$OPTARG;;
    *) echo "$usage"
       exit 1;;
    esac
done

if [[ $type == "wgt" || $type == "apk" || $type == "crx" || $type == "xpk" || $type == "cordova" ]];then
    echo "Create package with $type and raw source"
else
    echo "Sorry,$type is not support... >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "$usage"
    exit 1
fi

if [[ -z $name || -z $version || -z $appname ]];then
    echo "Package name or version not specified in setting file"
    exit 1
fi

SRC_ROOT=$PWD
BUILD_ROOT=/tmp/${name}_pack
BUILD_DEST=/tmp/${name}
specDir="presentation"

# check precondition
function check_precondition(){
    which $1 > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: no tool: $1"
        exit 1
    fi
}
check_precondition autoreconf
check_precondition gcc
check_precondition make

# clean
function clean_workspace(){
    echo "cleaning workspace... >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    rm -rf $BUILD_ROOT $BUILD_DEST
}

clean_workspace
mkdir -p $BUILD_ROOT $BUILD_DEST

# copy source code
rm -rf *.rpm *.tar.bz2 *.tar.gz *.zip
cp -arf $SRC_ROOT/* $BUILD_ROOT/

# build
echo "build from workspace... >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
cd  $BUILD_ROOT
./autogen && ./configure --prefix=/ && make && make install DESTDIR=$BUILD_DEST
if [ $? -ne 0 ];then
    echo "build fail,please check Makefile.am and cofigure.ac... >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    clean_workspace
    exit 1
fi
find $BUILD_DEST -name "Makefile*" -delete

## function for create wgt apk xpk ##

function create_wgt(){
    # create wgt
    cd $BUILD_DEST
    cp -a $BUILD_ROOT/manifest.json   $BUILD_DEST/
    cp -a $BUILD_ROOT/icon.png     $BUILD_DEST/

cat > index.html << EOF
<!doctype html>
<head>
    <meta http-equiv="Refresh" content="1; url=opt/$name/testkit/web/index.html?testsuite=/opt/usr/media/tct/opt/$name/tests.xml">
</head>
EOF

    cp -f $BUILD_ROOT/config.xml.wgt $BUILD_DEST/config.xml
    zip -rq $BUILD_DEST/opt/$name/$name.wgt *

    # creat sub_wgt #
    for dir in `ls -l $BUILD_DEST/opt/$name/$specDir/ |awk '{print $NF}'`
    do
      if [ ! -d $BUILD_DEST/opt/$name/$specDir/$dir ];then
        continue
      fi
    cd $BUILD_DEST/opt/$name/$specDir/$dir
    zip -rq $BUILD_DEST/opt/$name/$dir.wgt *

    done

    if [ $? -ne 0 ];then
        echo "Create $name.wgt fail.... >>>>>>>>>>>>>>>>>>>>>>>>>"
        clean_workspace
        exit 1
    fi

    # sign wgt
    if [ $sign -eq 1 ];then
        # copy signing tool
        echo "copy signing tool... >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        cp -arf $SRC_ROOT/../../tools/signing $BUILD_ROOT/signing
        if [ $? -ne 0 ];then
            echo "No signing tool found in $SRC_ROOT/../../tools.... >>>>>>>>>>>>>>>>>>>>>>>>>"
        fi

        for wgt in $(find $BUILD_DEST/opt/$name/ -name *.wgt);do
            $BUILD_ROOT/signing/sign-widget.sh --dist platform $wgt
            if [ $? -ne 0 ];then
                echo "Please check your signature files... >>>>>>>>>>>>>>>>>>>>>>>>>"
            fi
        done
    fi
}

function create_apk(){
    cd $BUILD_DEST

cat > index.html << EOF
<!doctype html>
<head>
    <meta http-equiv="Refresh" content="1; url=opt/$name/testkit/web/index.html?testsuite=../../tests.xml&testprefix=../../../..">
</head>
EOF

    cp -a $BUILD_ROOT/icon.png     $BUILD_DEST/
    cp -r $SRC_ROOT/../../tools/xwalk_app_template $BUILD_ROOT/xwalk_app_template
    cd $BUILD_ROOT/xwalk_app_template
    for dir in `ls -l $SRC_ROOT/$specDir/ |awk '{print $NF}'`
    do
        if [ ! -d $SRC_ROOT/$specDir/$dir ];then
        continue
        fi

        SubApkSrc=$BUILD_ROOT/$specDir/$dir
        SubApkDir=`basename $SubApkSrc`
        SubApkName=`basename $SubApkSrc |sed 's/-/_/g'`
        cp -r $SubApkSrc $BUILD_DEST
        python make_apk.py --package=org.xwalk.$SubApkName --name=$SubApkName --app-root=$BUILD_DEST/$SubApkDir --app-local-path=index.html --icon=$BUILD_DEST/$SubApkDir/icon.png --mode=$mode
    done

    python make_apk.py --package=org.xwalk.$appname --name=$appname --app-root=$BUILD_DEST --app-local-path=index.html --icon=$BUILD_DEST/icon.png --mode=$mode
    if [ $? -ne 0 ];then
        echo "Create $name.apk fail.... >>>>>>>>>>>>>>>>>>>>>>>>>"
        clean_workspace
        exit 1
    fi
}

function create_cordova_apk(){
cd $BUILD_DEST
cat > index.html << EOF
<!doctype html>
<head>
    <meta http-equiv="Refresh" content="1; url=opt/$name/testkit/web/index.html?testsuite=../../tests.xml&testprefix=../../../..">
</head>
EOF
cp -a $BUILD_ROOT/icon.png     $BUILD_DEST/

cp -ar $SRC_ROOT/../../tools/cordova $BUILD_ROOT/
if [ $? -ne 0 ]; then
    echo "No cordova packaging tool found in $SRC_ROOT/../../tools.... >>>>>>>>>>>>>>>>>>>>>>>>>"
    clean_workspace
    exit 1
fi
cd $BUILD_ROOT/cordova/
bin/create $appname com.example.$appname $appname
cd $BUILD_ROOT/cordova/$appname
rm -rf $BUILD_ROOT/cordova/$appname/assets/www/*
cp -ar $BUILD_DEST/* $BUILD_ROOT/cordova/$appname/assets/www/
cd $BUILD_ROOT/cordova/$appname/
./cordova/build
if [ $? -ne 0 ]; then
    echo "Create $appname.apk fail.... >>>>>>>>>>>>>>>>>>>>>>>>>"
    clean_workspace
    exit 1
fi

for dir in `ls -l $SRC_ROOT/$specDir/ |awk '{print $NF}'`
do
    if [ ! -d $SRC_ROOT/$specDir/$dir ];then
    continue
    fi

    SubApkSrc=$BUILD_ROOT/$specDir/$dir
    SubApkDir=`basename $SubApkSrc`
    SubApkName=`basename $SubApkSrc |sed 's/-/_/g'`
    cp -r $SubApkSrc $BUILD_DEST
    
    cd $BUILD_ROOT/cordova/
    bin/create $SubApkName com.example.$SubApkName $SubApkName
    cd $BUILD_ROOT/cordova/$SubApkName
    rm -rf $BUILD_ROOT/cordova/$SubApkName/assets/www/*
    cp -ar $BUILD_DEST/$SubApkSrc/* $BUILD_ROOT/cordova/$SubApkName/assets/www/
    cd $BUILD_ROOT/cordova/$SubApkName/
    ./cordova/build
    if [ $? -ne 0 ]; then
        echo "Create $SubApkName.apk fail.... >>>>>>>>>>>>>>>>>>>>>>>>>"
        clean_workspace
        exit 1
    fi
done
}

function create_xpk(){
    cp -a $BUILD_ROOT/manifest.json   $BUILD_DEST/
    cp -a $BUILD_ROOT/icon.png     $BUILD_DEST/

    cd $BUILD_DEST

cat > index.html << EOF
<!doctype html>
<head>
    <meta http-equiv="Refresh" content="1; url=opt/$name/testkit/web/index.html?testsuite=../../tests.xml&testprefix=../../../..">
</head>
EOF

    cp $SRC_ROOT/../../tools/make_xpk.py $BUILD_ROOT/make_xpk.py
    cd $BUILD_ROOT

    i=1
    for dir in `ls -l $SRC_ROOT/$specDir/ |awk '{print $NF}'`
    do
        if [ ! -d $SRC_ROOT/$specDir/$dir ];then
            continue
        fi

        SubXpkSrc=$BUILD_ROOT/$specDir/$dir
        SubXpkDir=`basename $SubXpkSrc`
        SubXpkName=$SubXpkDir
        cp -r $SubXpkSrc  $BUILD_DEST
        cp -r $BUILD_ROOT/manifest.json $BUILD_DEST/$SubXpkDir
        old=`cat $BUILD_DEST/$SubXpkDir/manifest.json |grep -w name |awk -F '"' '{print $4}'`
        sed -i "s/$old/$SubXpkName/" $BUILD_DEST/$SubXpkDir/manifest.json
        python make_xpk.py $BUILD_DEST/$SubXpkDir key${i}
        i=`expr $i + 1`
    done
    python make_xpk.py /tmp/$name key

    if [ $? -ne 0 ];then
        echo "Create $name.xpk fail.... >>>>>>>>>>>>>>>>>>>>>>>>>"
        clean_workspace
        exit 1
    fi
}

function create_crx(){
    echo "crx is not support yet... >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    clean_workspace
    exit 1
}

## zip function ##
function zip_for_wgt(){
    cd $BUILD_DEST
    # cp inst.sh script #
    cp -af $BUILD_ROOT/inst.sh.wgt $BUILD_DEST/opt/$name/inst.sh

    if [ $src_file -eq 0 ];then
        for file in $(ls opt/$name |grep -v wgt);do
            if [[ "${whitelist[@]}" =~ $file ]];then
                echo "$file in whitelist,keep it..."
            else
                echo "Remove unnessary file:$file..."
                rm -rf opt/$name/$file
            fi
        done
    fi
    zip -Drq $BUILD_DEST/$name-$version.$type.zip opt/
    if [ $? -ne 0 ];then
        echo "Create zip package fail... >>>>>>>>>>>>>>>>>>>>>>>>>"
        clean_workspace
        exit 1
    fi
}

function zip_for_apk(){
    cd $BUILD_DEST
    # cp inst.sh script #
    cp -af $BUILD_ROOT/inst.sh.apk $BUILD_DEST/opt/$name/inst.sh
    mv $BUILD_ROOT/xwalk_app_template/*.apk $BUILD_DEST/opt/$name/

    if [ $src_file -eq 0 ];then
        for file in $(ls opt/$name |grep -v apk);do
            if [[ "${whitelist[@]}" =~ $file ]];then
                echo "$file in whitelist,keep it..."
            else
                echo "Remove unnessary file:$file..."
                rm -rf opt/$name/$file
            fi
        done
    fi
    zip -Drq $BUILD_DEST/$name-$version.$type.zip opt/
    if [ $? -ne 0 ];then
        echo "Create zip package fail... >>>>>>>>>>>>>>>>>>>>>>>>>"
        clean_workspace
        exit 1
    fi
}

function zip_for_cordova(){
cd $BUILD_DEST
# cp inst.sh script #
cp -af $BUILD_ROOT/inst.sh.apk $BUILD_DEST/opt/$name/inst.sh
mv $BUILD_ROOT/cordova/$appname/bin/$appname-debug.apk $BUILD_DEST/opt/$name/$appname.apk
for dir in `ls -l $SRC_ROOT/$specDir/ |awk '{print $NF}'`
do
    SubXpkSrc=$BUILD_ROOT/$specDir/$dir
    SubXpkDir=`basename $SubXpkSrc`
    SubXpkName=$SubXpkDir
    mv $BUILD_ROOT/cordova/$SubXpkName/bin/$SubXpkName-debug.apk $BUILD_DEST/opt/$name/$SubXpkName.apk
done

if [ $src_file -eq 0 ];then
    for file in $(ls opt/$name |grep -v apk);do
        if [[ "${whitelist[@]}" =~ $file ]];then
            echo "$file in whitelist,keep it..."
        else
            echo "Remove unnessary file:$file..."
            rm -rf opt/$name/$file
        fi
    done
fi
zip -Drq $BUILD_DEST/$name-$version.apk.$type.zip opt/
if [ $? -ne 0 ];then
    echo "Create zip package fail... >>>>>>>>>>>>>>>>>>>>>>>>>"
    clean_workspace
    exit 1
fi
}

function zip_for_xpk(){
    cd $BUILD_DEST
    if [ $platform == "ivi" ]; then
        cp -af $BUILD_ROOT/inst.sh.ivi $BUILD_DEST/opt/$name/inst.sh
    else
        cp -af $BUILD_ROOT/inst.sh.xpk $BUILD_DEST/opt/$name/inst.sh
    fi
    mv $BUILD_ROOT/*.xpk $BUILD_DEST/opt/$name/

    if [ $src_file -eq 0 ];then
        for file in $(ls opt/$name |grep -v xpk);do
            if [[ "${whitelist[@]}" =~ $file ]];then
                echo "$file in whitelist,keep it..."
            else
                echo "Remove unnessary file:$file..."
                rm -rf opt/$name/$file
            fi
        done
    fi
    zip -Drq $BUILD_DEST/$name-$version.$type.zip opt/
    if [ $? -ne 0 ];then
        echo "Create zip package fail... >>>>>>>>>>>>>>>>>>>>>>>>>"
        clean_workspace
        exit 1
    fi
}

function zip_for_crx(){
    echo "zip_for_crx not ready yet... >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    clean_workspace
    exit 1
}

## create wgt crx apk xpk and zip package ##
case $type in
    cordova) create_cordova_apk
         zip_for_cordova;;
    wgt) create_wgt
         zip_for_wgt;;
    apk) create_apk
         zip_for_apk;;
    xpk) create_xpk
         zip_for_xpk;;
    crx) create_crx
         zip_for_crx;;
esac


# copy zip file
echo "copy package from workspace... >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
cp -f $BUILD_DEST/$name*.zip $SRC_ROOT/

# clean workspace
clean_workspace

# validate
echo "checking result... >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
if [ -z "`ls $SRC_ROOT | grep "\.zip"`" ];then
    echo "------------------------------ FAILED to build $name packages --------------------------"
    exit 1
fi

echo "------------------------------ Done to build $name packages --------------------------"
cd $SRC_ROOT
ls *.zip 2>/dev/null

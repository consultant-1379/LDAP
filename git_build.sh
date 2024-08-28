#!/bin/bash
#check

if [ "$2" == "" ]; then
	echo usage: $0 \<Module\> \<Branch\> \<Workspace\>
    	exit -1
else
	versionProperties=install/version.properties
	theDate=\#$(date +"%c")
	module=$1
	branch=$2
	workspace=$3
	BUILD_USER_ID=$4
	deliver=$5
	reason=$6
	CT=/usr/atria/bin/cleartool
	pkgReleaseArea=/home/$USER/eniq_events_releases
	
fi

function getReason {
        if [ -n "$reason" ]; then
        	reason=`echo $reason | sed 's/$\ /x/'`
                reason=`echo JIRA:::$reason | sed s/" "/,JIRA:::/g`
        else
                reason="CI-DEV"
        fi
}

function getProductNumber {
        product=`cat $PWD/build.cfg | grep $module | grep $branch | awk -F " " '{print $3}'`
}

function getSprint {
        sprint=`cat $PWD/build.cfg | grep $module | grep $branch | awk -F " " '{print $5}'`
}

function setRstate {

        revision=`cat $PWD/build.cfg | grep $module | grep $branch | awk -F " " '{print $4}'`

        if git tag | grep $product-$revision; then
            build_num=`git tag | grep $revision | wc -l`

            if [ "${build_num}" -lt 10 ]; then
				build_num=0$build_num
			fi
			rstate=`echo $revision$build_num | perl -nle 'sub nxt{$_=shift;$l=length$_;sprintf"%0${l}d",++$_}print $1.nxt($2) if/^(.*?)(\d+$)/';`
		else
            ammendment_level=01
            rstate=$revision$ammendment_level
        fi
        echo "Building R-State:$rstate"

}

function createTar {
    cd $PWD
    mkdir -p $PWD/tmp
    cp -Rp LDAP/ $PWD/tmp
    cd $PWD/tmp
    tar -cvf LDAP_$rstate.tar LDAP
    gzip LDAP_$rstate.tar
    echo "Storing LDAP_${rstate}.tar.gz in ${pkgReleaseArea}"
    cp LDAP_$rstate.tar.gz ${pkgReleaseArea}
}
getSprint
getProductNumber
setRstate
createTar

rsp=$?

if [ $rsp == 0 ]; then
  git clean -df
  git checkout $branch	
  git tag $product-$rstate
  git pull
  git push --tag origin $branch
fi  

if [ "${deliver}" == "Y" ] ; then
	echo "Running delivery..."
	getReason
	echo "$pkgReleaseArea/LDAP_$rstate.tar.gz"
	echo "Sprint: $sprint"
	echo "UserId: $BUILD_USER_ID"
	echo "Product Number: $product"
	echo "Running command: /vobs/dm_eniq/tools/scripts/deliver_eniq -auto events $sprint $reason N $BUILD_USER_ID $product NONE $pkgReleaseArea/LDAP_$rstate.tar"
	$CT setview -exec "/proj/eiffel013_config/fem101/jenkins_home/bin/lxb /vobs/dm_eniq/tools/scripts/deliver_eniq -auto events ${sprint} ${reason} N ${BUILD_USER_ID} ${product} NONE $pkgReleaseArea/LDAP_$rstate.tar.gz" deliver_ui
fi

exit $rsp

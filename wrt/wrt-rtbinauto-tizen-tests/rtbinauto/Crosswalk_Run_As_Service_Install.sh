#!/bin/bash

#Copyright (c) 2013 Intel Corporation.
#
#Redistribution and use in source and binary forms, with or without modification,
#are permitted provided that the following conditions are met:
#
#* Redistributions of works must retain the original copyright notice, this list
# of conditions and the following disclaimer.
#* Redistributions in binary form must reproduce the original copyright notice,
#  this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#* Neither the name of Intel Corporation nor the names of its contributors
#  may be used to endorse or promote products derived from this work without
#  specific prior written permission.
#
#THIS SOFTWARE IS PROVIDED BY INTEL CORPORATION "AS IS"
#AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
#IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
#ARE DISCLAIMED. IN NO EVENT SHALL INTEL CORPORATION BE LIABLE FOR ANY DIRECT,
#INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
#BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
#DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
#OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
#NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
#EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#Authors:
#       IVAN CHEN <yufeix.chen@intel.com>

local_path=$(dirname $0)
source $local_path/Common

func_check_xwalkservice
if [[ $? -eq 1 ]]; then
                 func_xwalkservice
                 if [[ $? -eq 1 ]]; then
                                 echo "set xwalk service failure"
                                 exit 1
                 fi
fi

xwalkctl --install $local_path/../source/manifest_app_mainSource1_tests.xpk > /tmp/install.txt
cat /tmp/install.txt | grep "Application installed" > /dev/null
if [[ $? -eq 0 ]]; then
                 echo "Use run as service install successfully"
else
                 echo "Use run  as service mode install failure"
                 exit 1
fi

app_id_tmp=`cat /tmp/install.txt | cut -d / -f 3`
echo "app_id_tmp" $app_id_tmp
app_id=`echo $app_id_tmp | sed 's/.$//g'` > /dev/null
#uninstall webapp
xwalkctl --uninstall $app_id
if [[ $? -eq 0 ]]; then
                 echo "Use run as service mode uninstall successfully"
                 exit 0
else
                 echo "Use run  as service mode uninstall failure"
                 exit 1
fi
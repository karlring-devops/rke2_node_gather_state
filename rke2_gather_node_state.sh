#!/bin/bash
#: baker:  karl ring 2021
#\******************************************************************/#
#| FORMAT FUNCTIONS
#\******************************************************************/#
function __MSG_HEADLINE__(){
    echo "[INFO]  ===== ${1} "
}
function __MSG_LINE__(){
    echo "-------------------------------------------------"
}
function __MSG_BANNER__(){
    __MSG_LINE__
    __MSG_HEADLINE__ "${1}"
    __MSG_LINE__

}
function __MSG_INFO__(){
     echo "[INFO]  ${1}: ${2}"
}

#\******************************************************************/#
#                                  _             
#   __ _  ___ _ __   ___ _ __ __ _| |            
#  / _` |/ _ \ '_ \ / _ \ '__/ _` | |            
# | (_| |  __/ | | |  __/ | | (_| | |  _   _   _ 
#  \__, |\___|_| |_|\___|_|  \__,_|_| (_) (_) (_)
#  |___/                                         
#
#/------------------------------------------------------------------\#
function makeTempDirs(){
  DTR_TYPE=${1}
  version=${2}
  nodeNumber=${3}
  startTag=${nodeNumber}.${version}-${DTR_TYPE}

  DIRS="${startTag}-files ${startTag}.all_yaml ${startTag}.pod-manifests"

  for d in ${DIRS}
   do
   	[ -d /tmp/$d ] && sudo rm -rf /tmp/$d
    sudo mkdir -p /tmp/$d
  done
  sudo chmod -R 777 /tmp
  sudo apt update && sudo apt install tree -y
  tree /tmp
}

function getpsef(){
  DTR_TYPE=${1}
  version=${2}
  nodeNumber=${3}
  startTag=${nodeNumber}.${version}-${DTR_TYPE}
  tempdir=/tmp/${startTag}-files
  logfile=${tempdir}/${startTag}.getpsef.log
  {
  __MSG_BANNER__ "ps -ef | grep kube"
  ps -ef | grep kube
  __MSG_BANNER__ "ps -ef | grep docker"
  ps -ef | grep docker
  } | tee -a  ${logfile}
  __MSG_INFO__ Created ${logfile}
}

function getYamlFiles(){
  DTR_TYPE=${1}
  version=${2}
  nodeNumber=${3}
  startTag=${nodeNumber}.${version}-${DTR_TYPE}  
  tempdir=/tmp/${startTag}-files

  YAML_FILES=${tempdir}/${startTag}-all-yaml-files.log
  sudo find /var/lib/rancher/rke2 -name "*.yaml" > ${YAML_FILES}

  mkdir -p ${tempdir}/charts
  mkdir -p ${tempdir}/manifests
  mkdir -p ${tempdir}/pod-manifests

  for x in `head -21 ${YAML_FILES}`
    do
        [ `echo $x|grep -c 'charts'` -eq 1 ] && copyDir=${tempdir}/charts
        [ `echo $x|grep -c 'pod-manifests'` -eq 1 ] && copyDir=${tempdir}/pod-manifests
        [ `echo $x|grep -c 'server/manifests'` -eq 1 ] && copyDir=${tempdir}/manifests

        sudo cp $x ${copyDir}/
  done
  ls -altrh ${tempdir}
}

function copyLogsToTemp(){
  DTR_TYPE=${1}
  version=${2}
  nodeNumber=${3}
  startTag=${nodeNumber}.${version}-${DTR_TYPE}  
  tempdir=/tmp/${startTag}-files

    logHeader="$tempdir/${nodeNumber}.${version}-${DTR_TYPE}"
    sudo lsof -i > ${logHeader}-lsof.log
    sudo netstat -tulnp > ${logHeader}-netstat-tulnp.log
    sudo cp /var/lib/rancher/rke2/agent/logs/kubelet.log ${logHeader}-kubelet.log
    sudo cp /var/lib/rancher/rke2/agent/containerd/containerd.log ${logHeader}-containerd.log
    ps -ef  > ${logHeader}-ps-ef.log
}

function copySnapshotsToTemp(){
  DTR_TYPE=${1}
  version=${2}
  nodeNumber=${3}
  startTag=${nodeNumber}.${version}-${DTR_TYPE}  
  tempdir=/tmp/${startTag}-files

    snapShotsDirTemp=$tempdir/io.containerd.snapshotter.v1.overlayfs.snapshots
    mkdir -p ${snapShotsDirTemp}
    snapShotsDir=/var/lib/rancher/rke2/agent/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots

    tarFile=${snapShotsDirTemp}/${nodeNumber}.${version}-${DTR_TYPE}.snapshots.logs.tar.gz
    sudo tar -cf $tarFile $( sudo find ${snapShotsDir} -name *.log )
}

function archiveRke2Root(){

  DTR_TYPE=${1}
  version=${2}
  nodeNumber=${3}
  startTag=${nodeNumber}.${version}-${DTR_TYPE}  
  tempdir=/tmp/${startTag}-files
  RKE2_ROOT=/var/lib/rancher/rke2/data/v2.5.11-4cf00d51c2e5
  tarFile=${tempdir}/${startTag}-rke2-root-dir.tar.gz

  sudo tar -zcf ${tarFile} ${RKE2_ROOT}
  __MSG_INFO__ Created "${tarFile}"
}


function rke2kubeconfig(){
  RKE_KUBECONFIG=/etc/rancher/rke2/rke2.yaml
  mkdir -p ~/.kube
  sudo cp ${RKE_KUBECONFIG} ~/.kube/kubeconfig.yaml
  sudo chown $USER:$USER ~/.kube/kubeconfig.yaml
  export KUBECONFIG=~/.kube/kubeconfig.yaml
  export RKE2_ROOT=/var/lib/rancher/rke2/data/v2.5.11-4cf00d51c2e5
  export PATH=${PATH}:${RKE2_ROOT}/bin
  kubectl get pods -A
}



function archiveRke2PodsYaml(){
  DTR_TYPE=${1}
  version=${2}
  nodeNumber=${3}
  startTag=${nodeNumber}.${version}-${DTR_TYPE}  
  tempdir=/tmp/${startTag}-files/yaml/pods
  fileTag=${tempdir}/${startTag}
  rke2kubeconfig
  [ ! -d ${tempdir} ] && sudo mkdir -p ${tempdir} && sudo chmod -R 777 ${tempdir}

    PODS=`kubectl get pods -A | grep -v NAME|awk '{print $1":"$2}'`
    for p in ${PODS}
     do
        podNamespace=`echo ${p}|cut -d":" -f1`
        podName=`echo ${p}|cut -d":" -f2`
        objectYaml=${fileTag}.pod.${podNamespace}.${podName}.yaml
        kubectl get pod ${podName} -n ${podNamespace} -o yaml | tee -a ${objectYaml}
        __MSG_INFO__ "Creating" "${objectYaml}"
    done
}

function archiveRke2SvcYaml(){
  DTR_TYPE=${1}
  version=${2}
  nodeNumber=${3}
  startTag=${nodeNumber}.${version}-${DTR_TYPE}  
  tempdir=/tmp/${startTag}-files/yaml/services
  fileTag=${tempdir}/${startTag}
  rke2kubeconfig
  [ ! -d ${tempdir} ] && sudo mkdir -p ${tempdir} && sudo chmod -R 777 ${tempdir}

    PODS=`kubectl get svc -A | grep -v NAME|awk '{print $1":"$2}'`
    for p in ${PODS}
     do
        svcNamespace=`echo ${p}|cut -d":" -f1`
        svcName=`echo ${p}|cut -d":" -f2`
        objectYaml=${fileTag}.svc.${svcNamespace}.${svcName}.yaml
        kubectl get svc ${svcName} -n ${svcNamespace} -o yaml | tee -a ${objectYaml}
        __MSG_INFO__ "Creating" "${objectYaml}"
    done
}

function zipTempDir(){
  DTR_TYPE=${1}
  version=${2}
  nodeNumber=${3}
  dateString=${4}
  startTag=${nodeNumber}.${version}-${DTR_TYPE}  
  tempdir=/tmp/${startTag}-files
  tarFile=${tempdir}.${dateString}.tar.gz

  sudo tar -zcf ${tarFile} ${tempdir}
  __MSG_BANNER__ "created:  ${tarFile}"
}

function getNodeData(){
    dtrType=${1}
    rVersion=${2}
    rNode=${3}
    rDate=${4}
    makeTempDirs ${dtrType} ${rVersion} ${rNode}
    getpsef ${dtrType} ${rVersion} ${rNode}
    getYamlFiles ${dtrType} ${rVersion} ${rNode}
    copyLogsToTemp ${dtrType} ${rVersion} ${rNode}
    copySnapshotsToTemp ${dtrType} ${rVersion} ${rNode}
    archiveRke2PodsYaml ${dtrType} ${rVersion} ${rNode}
    archiveRke2SvcYaml ${dtrType} ${rVersion} ${rNode}
    zipTempDir ${dtrType} ${rVersion} ${rNode} ${rDate}
}

function r2nodeinfo(){
    dtrType="${1}"
    rke2Version="${2}"
    rke2NodeNum="${3}"
    . `pwd`/rke2_gather_node_state.sh ${dtrType} ${rke2Version} ${rke2NodeNum}
}


function r2nodeinfoLoad(){
    dtrType="${1}"
    rke2Version="${2}"
    rke2NodeNum="${3}"
    cd ../
    rm -rf rke2_node_gather_state/
    pwd
    git clone https://github.com/karlring-devops/rke2_node_gather_state.git
    cd rke2_node_gather_state/
    . `pwd`/rke2_gather_node_state.sh ${dtrType} ${rke2Version} ${rke2NodeNum}
}

#\******************************************************************/#
#                  _       
#  _ __ ___   __ _(_)_ __  
# | '_ ` _ \ / _` | | '_ \ 
# | | | | | | (_| | | | | |
# |_| |_| |_|\__,_|_|_| |_|
#                                                                      
#\******************************************************************/#

DTR_TYPE=${1}					#--- public|private
INSTALL_RANCHERD_VERSION=${2}	#--- 2.5.11|2.6.3
RKE2_NODE_NUMBER=${3}			#--- 1,2,3 nnnn


rke2_gather_node_state(){
  export RKE2_DTR_STR=`date '+%Y%m%d%H%s'`
  getNodeData ${DTR_TYPE} ${INSTALL_RANCHERD_VERSION} ${RKE2_NODE_NUMBER} ${RKE2_DTR_STR}
}


#/***********************************************************************************************/#








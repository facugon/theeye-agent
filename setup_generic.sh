#!/bin/bash
#Author: Javi.
#Todo: replace node installation with: https://github.com/joyent/node/wiki/installing-node.js-via-package-manager
#This script download,install and add a cronjob for the eye-agent update
PATH="/bin:/sbin:/usr/bin:/usr/sbin"

if [[ -z $1 || -z $2 || -z $3 ]]; then
  echo "Value missing, please run as follows: $0  THEEYE_SUPERVISOR_CLIENT_ID THEEYE_SUPERVISOR_CLIENT_SECRET THEEYE_SUPERVISOR_CLIENT_CUSTOMER Optional Proxy"
fi
export clientID=$1
export clientSecret=$2
export clientCustomer=$3

#Configure.
agentUrl='http://interactar.com/public/install/041fc48819b171530c47c0d598bf75ad08188836'
customerAgent='generic-agent.tar.gz'
#todo volver generic
registerPostUrl='http://interactar.com/installupload/'

#End.

#Environment Envs
systemV=$(sudo stat /proc/1/exe |head -n1|cut -d '>' -f2|egrep -o \(systemd\|upstart\|sbin\)|head -n 1)
#El Proxy de Invap es: http://125.1.39.117:3128/
http_proxy=$http_proxy
#End Environment Envs

if [ \! -z $4 ];then
  http_proxy=$4
#  export curl_proxy=" --proxy '$http_proxy' "
  export http_proxy
  export https_proxy=$http_proxy
  export ftp_proxy=$http_proxy
  export npm_config_proxy=$http_proxy
fi

#Added this usefull function from a Stack Overflow post:
#Link: http://stackoverflow.com/questions/5947742/how-to-change-the-output-color-of-echo-in-linux
function coloredEcho {
  local exp=$1;
  case $- in
    *)    echo $exp
    ;;
    *i*) local color=$2;
    if ! [[ $color =~ '^[0-9]$' ]] ; then
      case $(echo $color | tr '[:upper:]' '[:lower:]') in
        black) color=0 ;;
        red) color=1 ;;
        green) color=2 ;;
        yellow) color=3 ;;
        blue) color=4 ;;
        magenta) color=5 ;;
        cyan) color=6 ;;
        white|*) color=7 ;; # white or invalid color
      esac
    fi
    tput setaf $color;
    echo $exp;
    tput sgr0;
    ;;
  esac
}

function installUbuntuPackages {
    coloredEcho "Installing Ubuntu Packages..." magenta
    # Installing last node and npm version
    #Works for Ubuntu:Lucid  Precise  Saucy  Trusty  Utopic
    # Using Ubuntu
    coloredEcho "Installing curl..." magenta
    apt-get install -y --force-yes curl
    curl -sL https://deb.nodesource.com/setup_0.12 | sudo -E bash -
    sudo apt-get install -y nodejs 2>&1 >> $installLog
    npm_path=$(which npm)
    if [ -z $npm_path ] ; then
      apt-get install -y --force-yes npm    2>&1 >> $installLog
    fi
    coloredEcho "Base Install Done..." magenta
}

function installCentosPackages {
    coloredEcho "Installing Centos Packages..." magenta
    yum install -y nodejs npm curl
    coloredEcho "Base Install Done..." magenta
}

#nodeJs installation
function baseInstall {
  node_path=$(which node)
  npm_path=$(which npm)
  if [ -z $node_path ] || [ -z $npm_path ] ; then
    # Instaling Base:
    coloredEcho "nodeJS is Missing, Instalation begins..." red
    coloredEcho "Installing nodejs..." magenta
    linuxFlavor=$(gawk -F= '/^NAME/{print $2}' /etc/os-release|sed 's/"//g'|cut -d' ' -f1)
    case "$linuxFlavor" in
        "Ubuntu")
          echo "Ubuntu time !!!!!!!!!!!<<<<"
            installUbuntuPackages
        ;;

        "CentOS")
            installCentosPackages
        ;;

        *)
            echo "unkown Linux Flavor $linuxFlavor"
        ;;

    esac


    # All extra stuff for server add here
    coloredEcho "nodeJs Setup Finished, moving forward" green
  fi
  if [ \! -z $proxy ];then
    npm config set proxy "$http_proxy"
    npm config set https-proxy "$http_proxy"
  fi
  npm config set registry http://registry.npmjs.org/
  npm install -g supervisor 2>&1 | $tee
  coloredEcho "base Install Done..." magenta
}

function installCrontabAndLogrotationFile {
  confFile='/etc/theeye/theeye.conf'
  #ojo workaround de proxy.
  #
  #echo adding iptables rule for transparent proxy at this server: /sbin/iptables -t nat -A OUTPUT -p tcp --dport 80 -j DNAT --to-destination $http_proxy
  #/sbin/iptables -t nat -A OUTPUT -p tcp --dport 80 -j DNAT --to-destination $http_proxy
  echo "*/60 * * * * root /usr/bin/curl $curl_proxy -s $agentUrl/setup.sh |bash -s $clientID '$clientSecret' $clientCustomer " > /etc/cron.d/agentupdate
  echo "*/30 * * * * root ps axu|grep -v grep|grep agent.run.sh >/dev/null; if [ $? -eq '1'  ];then sudo service theeye-agent restart;fi " > /etc/cron.d/agentwatchdog
  echo "
  /var/log/backend/*.log {
    daily
    rotate 7
    missingok
    create 666 root root
    compress
    sharedscripts
    postrotate
    /usr/bin/service theeye-agent restart
    endscript
  } " > /etc/logrotate.d/theeye-agent
  mkdir -p /etc/theeye
  echo "
  #!/bin/bash
  set -a
  THEEYE_SUPERVISOR_CLIENT_ID='$clientID'
  THEEYE_SUPERVISOR_CLIENT_SECRET='$clientSecret'
  THEEYE_SUPERVISOR_CLIENT_CUSTOMER='$clientCustomer'
  THEEYE_AGENT_SCRIPT_PATH='/opt/theeye-agent/scripts'
  THEEYE_AGENT_DEBUG='eye:*:error'
  THEEYE_SUPERVISOR_API_URL='https://supervisor.theeye.io'
  NODE_ENV='production'
  http_proxy='$(cat /tmp/http_proxy)'
  https_proxy='$(cat /tmp/http_proxy)'
  THEEYE_AGENT_VERSION='v0.1.0-beta-1-g4a96c46'
  " > $confFile

  coloredEcho "Cronjob and LogRotation installation Done..." magenta

}

function prepareDirectoriesAndGlobalRequires {
  if [ -d /opt/theeye-agent ]
    then
    echo "removing current source directory"
    rm -rf /opt/theeye-agent
  fi
#temporal
  if [ -d /opt/theeye/agent ]
    then
    echo "removing current source directory"
    rm -rf /opt/theeye/agent
  fi

  mkdir -p /opt/theeye
  mkdir /var/log/backend
  coloredEcho "prepare Directories And Global Requires done..." magenta
}

function installSystemVInitScript {
  case "$systemV" in

    "systemd")
    echo "doing systemd installation"
    cp $destinationPath/theeye-agent/misc/etc/systemd/system/* /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable theeye-agent
    ;;

    "upstart")
    echo "doing upstart installation"
    cp $destinationPath/theeye-agent/misc/etc/upstart/init/* /etc/init/
    ;;

    "sbin")
    echo "starring sbin file"
    systemV=$(sudo stat /sbin/init |head -n1|cut -d '>' -f2|egrep -o \(systemd\|upstart\|sbin\)|head -n 1)
    echo "ok new systemV reached $systemV"
    if [ $systemV == "sbin" ];then  #Instead of sbin recieved I guess upstart would work anyway I've to stop recursion so...
      echo  "I guess upstart would works, If it doesn't please contact theeye.io team"
      systemV='upstart'
    fi
      installSystemVInitScript
    ;;

    *)
    echo "unkown systemV initialization"
    ;;

  esac
}
#Fixes for particular issues that we found on some platforms.
function fixCustomSOissues {
#Fuse error redhat like S.O, not the best solution but this soft is intended for servers 
#not gnome sessions on X.
overrideGVFS=$(sudo su - theeye-a -c 'df;echo $?'|tail -n1)
if [ $overrideGVFS == "1" ];then 
  echo "#We really want to run df without any exception" >> /etc/fuse.conf
  echo "user_allow_other" >> /etc/fuse.conf
  service display-manager stop
  service display-manager start
fi
}
function downloadAndSetupAgent {
  sudoerFile='/etc/sudoers.d/theeye-agent'
  service theeye-agent stop
  rm -rf $destinationPath/generic-agent*
  rm -rf $destinationPath/theeye
  destinationPath='/opt'
  cd $destinationPath
  coloredEcho "Downloading agent and installing it at $destinationPath ..." cyan
  curl -O $agentUrl/$customerAgent
  coloredEcho "Uncompressing Agent ..." cyan
  tar -xvzf $customerAgent
  coloredEcho "Configuring SystemV for theeye-agent service ..." cyan
  installSystemVInitScript
  coloredEcho "Adding user theeye-a and giving sudoer permission ..." cyan
  useradd theeye-a || useradd theeye-a -g theeye-a
  echo "theeye-a ALL=(ALL) NOPASSWD: ALL" > $sudoerFile
  chmod 440 $sudoerFile
  coloredEcho "Changing ownerships for destinationPath ..." cyan
  chown -R theeye-a $destinationPath/theeye
  cd $destinationPath/theeye-agent/
  coloredEcho "Agent Setup done..." magenta
}
function bannerPrint {
  tput setaf 2;
echo "
                :                              :
              :                                 :
            :                                   :
            :  RRVIttIti+==iiii++iii++=;:,       :
            : IBMMMMWWWWMMMMMBXXVVYYIi=;:,        :
            : tBBMMMWWWMMMMMMBXXXVYIti;;;:,,      :
            t YXIXBMMWMMBMBBRXVIi+==;::;::::       ,
           ;t IVYt+=+iIIVMBYi=:,,,=i+=;:::::,      ;;
           YX=YVIt+=,,:=VWBt;::::=,,:::;;;:;:     ;;;
           VMiXRttItIVRBBWRi:.tXXVVYItiIi==;:   ;;;;
           =XIBWMMMBBBMRMBXi;,tXXRRXXXVYYt+;;: ;;;;;
            =iBWWMMBBMBBWBY;;;,YXRRRRXXVIi;;;:;,;;;=
             iXMMMMMWWBMWMY+;=+IXRRXXVYIi;:;;:,,;;=
             iBRBBMMMMYYXV+:,:;+XRXXVIt+;;:;++::;;;
             =MRRRBMMBBYtt;::::;+VXVIi=;;;:;=+;;;;=
              XBRBBBBBMMBRRVItttYYYYt=;;;;;;==:;=
               VRRRRRBRRRRXRVYYIttiti=::;:::=;=
                YRRRRXXVIIYIiitt+++ii=:;:::;==   Hey Bud,
                +XRRXIIIIYVVI;i+=;=tt=;::::;:;   We're Done!
                 tRRXXVYti++==;;;=iYt;:::::,;;
                  IXRRXVVVVYYItiitIIi=:::;,::;
                   tVXRRRBBRXVYYYIti;::::,::::
                    YVYVYYYYYItti+=:,,,,,:::::;
                    YRVI+==;;;;;:,,,,,,,:::::::         "
  tput sgr0;
}
installLog="/tmp/$clientCustomer.$(hostname -s).theEyeInstallation.log"

echo "starting at $(date)"> $installLog
echo "running with url $agentUrl and $customerAgent">> $installLog
echo "with running processes $(ps axu)">> $installLog
rm $installLog.gz

tee="tee -a $installLog"
echo infoPlus:$(hostname && ifconfig ) 2>&1 | $tee

coloredEcho "setting http_proxy. $http_proxy" red 2>&1 | $tee
echo $http_proxy > /tmp/http_proxy

coloredEcho "Step 1 of 5- Check if nodeJS exists and If it doesn't, install it." green 2>&1 | $tee
baseInstall 2>&1 | $tee

coloredEcho "Step 2 of 5- Installing Cron File for agent update" green 2>&1 | $tee
installCrontabAndLogrotationFile 2>&1 | $tee

coloredEcho "Step 3 of 5- Prepare Directories and Global requires such as supervisor" green 2>&1 | $tee
prepareDirectoriesAndGlobalRequires 2>&1 | $tee

coloredEcho "Step 4 of 5- download the agent, Install/Upgrade it , untar it and create/update system users " green 2>&1 | $tee
downloadAndSetupAgent 2>&1 | $tee

coloredEcho "Step 5 of 5- Restart the agent and tell remote server that updation has finished. " greenn 2>&1 | $tee
fixCustomSOissues
service theeye-agent stop
service theeye-agent start
echo "## List Process Running:"  >> $installLog
ps -ef |grep theeye  >> $installLog
echo "## dump run.sh:"  >> $installLog
cat /opt/theeye-agent/run.sh 2>&1 >> $installLog
echo "## theeye-agent:"  >> $installLog
cat /etc/init/theeye-agent.conf >> $installLog
echo "## agent config (/etc/theeye/theeye.conf):"  >> $installLog
cat /etc/theeye/theeye.conf >> $installLog
echo "## last agent lines" >> $installLog
tail -n 100 /var/log/backend/theeye-a.log >> $installLog
echo doing post: curl $curl_proxy $http_proxy $registerPostUrl -F "installlog=@$installLog">> $installLog
gzip $installLog
curl -0 $registerPostUrl -F "installlog=@$installLog.gz"

bannerPrint

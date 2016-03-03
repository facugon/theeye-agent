#!/usr/bin/env bash
#Todo: use misc/theeye.conf for development env.

# root path
path=`dirname $0`
cd $path
echo "root on $path && $(pwd)"


# colored output
echo -e "\e[32m"

if [ ! -d $path/node_modules ]
then
  echo -e "\e[31m"
  echo "Error agent require installation"
  echo "run 'npm install' before continue"
  echo -e "\e[39m"
  exit
fi

# reading environment config
config="/etc/theeye/theeye.conf"
if [ -f $config ]
then
  echo "reading configuration from $config"
  source $config
else
       export THEEYE_SUPERVISOR_CLIENT_ID=sauron
       export THEEYE_SUPERVISOR_CLIENT_SECRET=sauron
       export THEEYE_SUPERVISOR_CLIENT_CUSTOMER=demo
       export THEEYE_AGENT_SCRIPT_PATH=/src/theeye-agent/scripts
       export THEEYE_AGENT_DEBUG=eye:*:error
       export THEEYE_SUPERVISOR_API_URL=http://supervisor-demo.theeye.io:60080
       export NODE_ENV=production
fi

# NODE_ENV validation
if [ -z $NODE_ENV ]
then
  echo -e "\e[31m"
  echo "Error env not set"
  echo "please set 'NODE_ENV' with desired value (production/development)" 
  echo -e "\e[39m"
  exit
else
  if [ ! "$NODE_ENV" == "development" ] && [ ! "$NODE_ENV" == "production" ]
  then
    echo -e "\e[31m"
    echo "Error invalid 'NODE_ENV' value '$NODE_ENV'"
    echo "use production or development"
    echo -e "\e[39m"
    exit
  fi
fi


echo "using NODE_ENV=$NODE_ENV"

setDebug ()
{
  if [ -z ${DEBUG+x} ]; then
    # debug/log level
    if [ -z ${THEEYE_AGENT_DEBUG+x} ]
    then
      DEBUG='eye:*:error'
      echo "default DEBUG level set"
    else
      DEBUG=$THEEYE_AGENT_DEBUG
      echo 'DEBUG level set with $THEEYE_AGENT_DEBUG'
    fi
  fi

  echo "log level set to '$DEBUG'"
}


# end colored output
echo -e "\e[39m"

NODE_CONFIG_STRICT_MODE=true

setDebug

if [ $NODE_ENV == 'production' ]
then
  require=$(which node)
  #ride out of supervisor dependency for agents
  if [ -z $require ] || [ ! -f $require ]
  then
    echo "Error 'node' is not present on this system"
    exit
  fi
  $require -i $path/core/main.js
else
  $path/node_modules/.bin/nodemon `pwd`/core/main.js
fi

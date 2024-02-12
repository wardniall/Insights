#!/bin/bash

USERNAME=''
PASSWORD=''
INSIGHTS_URL=''
API_URL=''
DOWNLOAD_URL=''

showHelp () {
        cat << EOF
        Usage: ./setupVM.sh [-h|--help -u|--user=<USERNAME> -p|--password=<PASSWORD> -i|--insights=<INSIGHTS_URL>]

Helper script to deploy prereqs on a VM that will employ the API to drive events into an Insights setup

-h, --help                                      Display help
-u, --user                                      username to log into Insights
-p, --password                                  password for logging into Insights
-i, --insights                                  URL of Insights

EOF
}

options=$(getopt -l "help,username:,password:,insights:" -o "h,u:,p:,i:" -a -- "$@")
eval set -- "${options}"
while true; do
        case ${1} in
        -h|--help)
                showHelp
                exit 0
                ;;
        -u|--username)
                shift
                USERNAME="${1}"
                ;;
        -p|--password)
                shift
                PASSWORD="${1}"
                ;;
        -i|--insights)
                shift
                INSIGHTS_URL="${1}"
                ;;
        --)
                shift
                break
                ;;
        esac
shift
done

# determine the API URL, the download URL from the INSIGHTS_URL

DOMAIN=$(echo ${INSIGHTS_URL} | awk -F 'apps' '{print $2;}')
API_URL="https://api"${DOMAIN}
DOWNLOAD_URL="https://downloads-openshift-console.apps"${DOMAIN}


#install java 17

sudo yum install java-17-openjdk.x86_64 -y

# need to configure java 17 as the system java
# first get the list of java alternatives, then grep out the jre_17 entries. We onlt want the first one, so we use head -1. Then we extract the path

java17=$(update-alternatives --list | grep 'jre_17' | head -1 |  awk '{print $3}')
java17+="/bin/java"
update-alternatives --set java  ${java17}

# download the oc tar from the insights server

mkdir ~/holdit
cd ~/holdit

# if the oc.tar file preexists in ~/holdit,delete it
if [ -f ~/holdit/oc.tar ]; then
  rm ~/holdit/oc.tar
fi

wget --user=${USERNAME} --password=${PASSWORD} --no-check-certificate ${DOWNLOAD_URL}/amd64/linux/oc.tar

# untar the oc file
tar -xvf oc.tar

# copy the oc binary to /usr/sbin
cp oc /usr/sbin

# test the oc login

oc login ${API_URL}:6443 -u ${USERNAME} -p ${PASSWORD}  --insecure-skip-tls-verify=true

# SETUP INSTANA AGENT

mkdir ~/holdit/instana-agent
cd ~/holdit/instana-agent
curl -L -o setup-agent.tar.gz https://github.com/IBM/aiops-insights-tools/releases/latest/download/setup-agent.tar.gz
curl -L -o setup-agent.sig https://github.com/IBM/aiops-insights-tools/releases/latest/download/agent.sig


# verify jars
# first we need to download the various certs etc. They are embedded into a page at https://www.ibm.com/docs/en/aiops-insights?topic=insights-verifying-integration-script-packages
# first download this page using wget, then use sed , tail and head to extract the bits of the downloaded file into certificate and chain files

wget https://www.ibm.com/docs/en/aiops-insights?topic=insights-verifying-integration-script-packages -O certFile

# now extract the various snippets from the downloaded file into various files using sed , tail and head

if [ -f aiops-insights.pem.cer ]; then
  rm aiops-insights.pem.cer
fi

echo '-----BEGIN CERTIFICATE-----' > aiops-insights.pem.cer
(sed -n '/<code>aiops-insights.pem.cer<\/code>/,/-----END CERTIFICATE-----/p' certFile | tail -n +3 ) >> aiops-insights.pem.cer

if [ -f aiops-insights.pem.chain ]; then
  rm aiops-insights.pem.chain
fi

echo '-----BEGIN CERTIFICATE-----' > aiops-insights.pem.chain
(sed -n '/<code>aiops-insights.pem.chain<\/code>/,/<\/code>/p' certFile | tail -n +3 | head -n -1) >> aiops-insights.pem.chain

if [ -f aiops-insights.pem.pub.key ]; then
  rm aiops-insights.pem.pub.key
fi

echo '-----BEGIN PUBLIC KEY-----' > aiops-insights.pem.pub.key
(sed -n '/<code>aiops-insights.pem.pub.key<\/code>/,/-----END PUBLIC KEY-----/p' certFile | tail -n +3 ) >> aiops-insights.pem.pub.key

# now that we have all the certs etc we can verify the download

openssl dgst -verify ./aiops-insights.pem.pub.key -keyform PEM -sha256 -signature agent.sig -binary setup-agent.tar.gz

if [ $? -ne 0 ]; then
  echo "Downloaded agent tar signature not verified, exiting...."
  exit -1
fi

# just output the cert info for now
openssl x509 -in ./aiops-insights.pem.cer -noout -subject -issuer -startdate -enddate

# check the cert validity

openssl ocsp -no_nonce -issuer ./aiops-insights.pem.chain -cert ./aiops-insights.pem.cer -VAfile ./aiops-insights.pem.chain -text -url http://ocsp.digicert.com -respout ocsptest | grep 'Response verify OK'
if [ $? -ne 0 ]; then
  echo "Certificate validity check has failed, exiting....."
  exit -1
fi


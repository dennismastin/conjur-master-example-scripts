#Variables
HOSTIP=xx.193.xx.89
DAP_CONTAINER=captainfluffytoes/dap:11.4.0
DAPFQDN=dapmaster.conjur.dev
DAP_ALTNAMES=ec2-xx-193-xx-89.us-west-1.compute.amazonaws.com
DAPIP=$HOSTIP
DAPPORT=443
DAPADMINUSERNAME=admin
DAPADMINPASSWORD={{ admin-password-to-init }}
ACCOUNT=cyberark
POLICY_ROOT=./policy

main(){
  echo "Starting DAP container"
  startdap
}

startdap(){
  echo "Starting DAP Configuration"
  echo "-----"
  echo "Creating Docker network"
  echo "-----"
  docker network create dap
  echo "Starting DAP Master container"
  echo "-----"
  docker container run -d --name $DAPFQDN --restart=always  -e CONJUR_AUTHENTICATORS=authn-azure/dev,authn-iam/prod,authn-jenkins/prod,authn-k8s/k8s-follower,authn-k8s/okd-follower --network dap --security-opt seccomp:unconfined -p 443:443 -p 5432:5432 -p 1999:1999 -p 636:636 -p 80:80 $DAP_CONTAINER
  echo "Starting DAP CLI"
  echo "-----"
  docker container run -d --name dapcli --mount type=bind,source="/opt/dap/policy/",target=/policy --restart=always --network dap --entrypoint "" cyberark/conjur-cli:5-latest sleep infinity
  echo "Configuring Master Instance"
  echo "-----"
  docker exec $DAPFQDN evoke configure master --accept-eula -h $DAPFQDN -p $DAPADMINPASSWORD $ACCOUNT
  #echo "addin ALTNAME(s) to cert"
  #echo "------"
  #docker exec $DAPFQDN evoke ca regenerate --restart $DAP_ALTNAMES
  echo "Configuring DAP CLI"
  echo "-----"
  docker exec -i dapcli conjur init --account cyberark --url https://$DAPFQDN <<< yes
  docker exec dapcli conjur authn login -u $DAPADMINUSERNAME -p $DAPADMINPASSWORD
}

main

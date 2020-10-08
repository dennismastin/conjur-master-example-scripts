#Variables
HOSTIP=xx.193.xx.89
TOOLSIP=xx.18.xx.62
DAPFQDN=dapmaster.conjur.dev
DAP_ALTNAMES=ec2-xx-193-xx-89.us-west-1.compute.amazonaws.com
#DAPFQDN=dapmaster.conjur.dev
DAPIP=$HOSTIP
DAPPORT=443
DAPADMINUSERNAME=admin
DAPADMINPASSWORD={{ admin-password-to-init }}
JENKINSFQDN=jenkins.conjur.dev
JENKINSIP=$TOOLSIP
JENKINSPORT=8080
GITLABFQDN=git.conjur.dev
GITLABIP=$TOOLSIP
GITLABPORT=80
ARTIFACTORYFQDN=jfrog.conjur.dev
ARTIFACTORYPORT=8081
ARTIFACTORYIP=$TOOLSIP
ACCOUNT=cyberark
TOOLSFQDN=tools.conjur.dev
POLICY_ROOT=./policy

main(){
  echo "Starting DAP container"
  startdap
#  echo "Loading DAP Policies"
#  echo "-----"
#  devops-loadpolicy
#  lambda-ec2-loadpolicy
#  azure-loadpolicy
#  echo "Setting secret Values"
#  echo "-----"
#  lambda-ec2-secrets
#  devops-secrets
#  azure-secrets
}

startdap(){
  echo "Starting DAP Configuration"
  echo "-----"
  echo "Creating Docker network"
  echo "-----"
  docker network create dap
  echo "Starting DAP Master container"
  echo "-----"
  docker container run -d --name $DAPFQDN --restart=always --add-host=$JENKINSFQDN:$JENKINSIP -e CONJUR_AUTHENTICATORS=authn-azure/dev,authn-iam/prod,authn-jenkins/prod,authn-k8s/k8s-follower,authn-k8s/okd-follower --network dap --security-opt seccomp:unconfined -p 443:443 -p 5432:5432 -p 1999:1999 -p 636:636 -p 80:80 --add-host=$TOOLSFQDN:$TOOLSIP captainfluffytoes/dap:11.4.0
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

authenticate(){
  local LOGIN=$(curl -s -k --user $DAPADMINUSERNAME:$DAPADMINPASSWORD https://$DAPIP/authn/$ACCOUNT/login)
  local AUTH=$(curl -s -k -H "Content-Type: text/plain" -X POST -d "$LOGIN" https://$DAPIP/authn/$ACCOUNT/$DAPADMINUSERNAME/authenticate)
  local AUTH_TOKEN=$(echo -n $AUTH | base64 | tr -d '\r\n')
  echo "$AUTH_TOKEN"
}

lambda-ec2-secrets(){
  #local SECRETS=(secrets/backend/postgres_address secrets/backend/postgres_pwd secrets/backend/postgres_user secrets/frontend/nginx_address secrets/frontend/nginx_pwd secrets/frontend/nginx_user)
  local SECRETS=(database/username database/password)
  #local SECRETS=(myapp/database/username myapp/database/password)
  local AUTH_TOKEN=$(authenticate)
  for secret in "${SECRETS[@]}"
  do
    newValue=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c32)
    echo "Setting value of $secret to $newValue"
    curl -s -k -X POST -H "Authorization: Token token=\"$AUTH_TOKEN\"" -d "$newValue" https://$DAPIP/secrets/$ACCOUNT/variable/$secret
  done
}

azure-secrets(){
  local SECRETS=(test-variable)
  
  local AUTH_TOKEN=$(authenticate)
  for secret in "${SECRETS[@]}"
  do
    newValue=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c32)
    echo "Setting value of $secret to $newValue"
    curl -k -X POST -H "Authorization: Token token=\"$AUTH_TOKEN\"" -d "$newValue" "https://$DAPIP/$ACCOUNT/variable/$secret"
  done
}
devops-secrets(){
  local SECRETS=(secrets/backend/postgres_address secrets/backend/postgres_pwd secrets/backend/postgres_user secrets/frontend/nginx_address secrets/frontend/nginx_pwd secrets/frontend/nginx_user)
  local AUTH_TOKEN=$(authenticate)
  for secret in "${SECRETS[@]}"
  do
    newValue=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c32)
    echo "Setting value of $secret to $newValue"
    curl -s -k -X POST -H "Authorization: Token token=\"$AUTH_TOKEN\"" -d "$newValue" https://$DAPIP/secrets/$ACCOUNT/variable/$secret
  done
}

devops-loadpolicy(){
  local POLICIES=(root conjur cicd secrets)
echo $POLICIES
  local AUTH_TOKEN=$(authenticate)
echo $AUTH_TOKEN
  for policy in "${POLICIES[@]}"
  do
    echo -e "\nLoading Policy $policy\n"
    curl -s -k -X PUT -H "Authorization: Token token=\"$AUTH_TOKEN\"" --data-binary "@$POLICY_ROOT/devops/"$policy".yml" https://$DAPIP/policies/$ACCOUNT/policy/$policy
    echo -e "\n"
  done
}

lambda-ec2-loadpolicy(){
  local POLICIES=(root)
echo $POLICIES
  local AUTH_TOKEN=$(authenticate)
echo $AUTH_TOKEN
  for policy in "${POLICIES[@]}"
  do
    echo -e "\nLoading Policy $policy\n"
    curl -s -k -X PUT -H "Authorization: Token token=\"$AUTH_TOKEN\"" --data-binary "@$POLICY_ROOT/lambda-ec2/"$policy".yml" https://$DAPIP/policies/$ACCOUNT/policy/$policy
    echo -e "\n"
  done
}

azure-loadpolicy(){
  local POLICIES=(authm-azure-dev-hosts)
echo $POLICIES
  local AUTH_TOKEN=$(authenticate)
echo $AUTH_TOKEN
  for policy in "${POLICIES[@]}"
  do
    echo -e "\nLoading Policy $policy\n"
    curl -s -k -X PUT -H "Authorization: Token token=\"$AUTH_TOKEN\"" --data-binary "@$POLICY_ROOT/azure/"$policy".yml" https://$DAPIP/policies/$ACCOUNT/policy/$policy
    echo -e "\n"
  done
}


main

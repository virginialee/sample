#!/usr/bin/env bash

set -e

aws s3 cp "s3://myob-sample/sample-secret" /tmp
cd /opt/chef-repo

knife data bag show ssh_keys sample -z --secret-file /tmp/sample-secret -F json | jq -r '.private' > /home/ubuntu/.ssh/id_rsa
chmod go-rw /home/ubuntu/.ssh/id_rsa

knife data bag show ssh_keys sample -z --secret-file /tmp/sample-secret -F json | jq -r '.public' > /home/ubuntu/.ssh/id_rsa.pub
chmod go-rw /home/ubuntu/.ssh/id_rsa.pub

# not required ???
mkdir -p ~/.github
githubApiKey=~/.github/api_key
echo -n 'export GITHUB_TOKEN=' >> $githubApiKey
knife data bag show github auth_token -z --secret-file /tmp/sample-secret -F json | jq -r '.token' >> $githubApiKey
chmod go-rw $githubApiKey

echo '@myob:registry=https://npm.addevcloudservices.com.au/' > ~/.npmrc &&
echo -n '//npm.addevcloudservices.com.au/:_authToken="' >> ~/.npmrc
knife data bag show npm credentials -z --secret-file /tmp/sample-secret -F json | jq -r '.authToken' | xargs echo -n >> ~/.npmrc
echo -n '"' >> ~/.npmrc

# build my-ops-secret
if service --status-all | grep -Fq 'docker'; then
  CONTAINER_ID=$(docker create alpine:3.3 /bin/sh)
  docker cp ~/.ssh $CONTAINER_ID:/root/.ssh
  docker cp ~/.github $CONTAINER_ID:/root
  docker commit $CONTAINER_ID my-ops-secret
  docker rm -f -v $CONTAINER_ID
  unset CONTAINER_ID
fi

# remove src
cd ~ && rm -rf sample

# remove secret
rm -f /tmp/sample-secret

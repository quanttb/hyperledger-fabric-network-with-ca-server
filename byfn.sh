#!/bin/bash

# Exit on first error
set -euo pipefail

# Variables
export SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE}[0]")" >/dev/null 2>&1 && pwd)

export DOCKER_DEFAULT_PLATFORM=linux/amd64
export DOCKER_NETWORK_NAME=mynetwork
export COMPOSE_PROJECT_NAME=fabric

export FABRIC_CA_VERSION=1.5.15
export FABRIC_PEER_VERSION=3.1.1
export FABRIC_ORDERER_VERSION=3.1.1
export FABRIC_TOOLS_VERSION=3.0.0-beta
export FABRIC_NODEENV_VERSION=2.5.8
export COUCHDB_VERSION=3.1.2
export EXPLORER_DB_VERSION=2.0.0
export EXPLORER_VERSION=2.0.0

SLEEP_DURATION=2
CHANNEL_NAME="mychannel"
CHAINCODE_NAME="mychaincode"
CHAINCODE_VERSION=1
CHAINCODE_SEQUENCE=1

# Helper functions
function run_ca() {
  docker run \
    --platform ${DOCKER_DEFAULT_PLATFORM} \
    -v /tmp/hyperledger:/tmp/hyperledger \
    --network=${DOCKER_NETWORK_NAME} \
    --rm "hyperledger/fabric-ca:${FABRIC_CA_VERSION}" \
    sh -c "$*"
}

function run_tools() {
  docker run \
    --platform ${DOCKER_DEFAULT_PLATFORM} \
    -v /tmp/hyperledger:/tmp/hyperledger \
    -v "${SCRIPT_DIR}/config:/tmp/hyperledger/config" \
    --network=${DOCKER_NETWORK_NAME} \
    --rm hyperledger/fabric-tools:${FABRIC_TOOLS_VERSION} \
    sh -c "$*"
}

# Cleanup
docker-compose -f docker-compose.yaml down -v
IMAGES=$(docker images | grep dev-peer | awk '{print $3}' || true)
if [[ -n "${IMAGES}" ]]; then
  docker rmi -f ${IMAGES}
fi
rm -rf /tmp/hyperledger

mkdir -p /tmp/hyperledger/fabric-ca && mkdir -p /tmp/hyperledger/explorer/wallet
docker pull hyperledger/fabric-nodeenv:${FABRIC_NODEENV_VERSION}

# Setup CAs
## TODO: Setup TLS CA

## Org0
docker-compose -f docker-compose.yaml up -d rca-org0
sleep ${SLEEP_DURATION}

run_ca "
  export FABRIC_CA_CLIENT_TLS_CERTFILES=/tmp/hyperledger/fabric-ca/org0/ca-cert.pem && \
  export FABRIC_CA_CLIENT_HOME=/tmp/hyperledger/org0 && \
  fabric-ca-client enroll -u https://rca-org0-admin:rca-org0-admin-pw@rca-org0:7054 --caname rca-org0"

cp ${SCRIPT_DIR}/config/config.yaml /tmp/hyperledger/org0/msp/config.yaml
mv /tmp/hyperledger/org0/msp/cacerts/* /tmp/hyperledger/org0/msp/cacerts/ca-cert.pem

mkdir -p /tmp/hyperledger/org0/msp/tlscacerts
cp /tmp/hyperledger/fabric-ca/org0/ca-cert.pem /tmp/hyperledger/org0/msp/tlscacerts/tlsca-cert.pem

mkdir -p /tmp/hyperledger/org0/tlsca
cp /tmp/hyperledger/fabric-ca/org0/ca-cert.pem /tmp/hyperledger/org0/tlsca/tlsca-cert.pem

for ORDERER in orderer1 orderer2 orderer3 orderer4; do
  run_ca "
    export FABRIC_CA_CLIENT_TLS_CERTFILES=/tmp/hyperledger/fabric-ca/org0/ca-cert.pem && \
    export FABRIC_CA_CLIENT_HOME=/tmp/hyperledger/org0/orderers/${ORDERER} && \
    fabric-ca-client enroll -u https://rca-org0-admin:rca-org0-admin-pw@rca-org0:7054 --caname rca-org0 && \
    fabric-ca-client register --caname rca-org0 --id.name ${ORDERER}-org0 --id.secret ${ORDERER}-org0-pw --id.type orderer"

  run_ca "
    export FABRIC_CA_CLIENT_TLS_CERTFILES=/tmp/hyperledger/fabric-ca/org0/ca-cert.pem && \
    export FABRIC_CA_CLIENT_HOME=/tmp/hyperledger/org0/orderers/${ORDERER} && \
    export FABRIC_CA_CLIENT_MSPDIR=msp && \
    fabric-ca-client enroll -u https://${ORDERER}-org0:${ORDERER}-org0-pw@rca-org0:7054 --caname rca-org0"

  cp ${SCRIPT_DIR}/config/config.yaml /tmp/hyperledger/org0/orderers/${ORDERER}/msp/config.yaml
  mv /tmp/hyperledger/org0/orderers/${ORDERER}/msp/cacerts/* /tmp/hyperledger/org0/orderers/${ORDERER}/msp/cacerts/ca-cert.pem

  mv /tmp/hyperledger/org0/orderers/${ORDERER}/msp/signcerts/cert.pem /tmp/hyperledger/org0/orderers/${ORDERER}/msp/signcerts/${ORDERER}-org0-cert.pem

  run_ca "
    export FABRIC_CA_CLIENT_TLS_CERTFILES=/tmp/hyperledger/fabric-ca/org0/ca-cert.pem && \
    export FABRIC_CA_CLIENT_HOME=/tmp/hyperledger/org0/orderers/${ORDERER} && \
    export FABRIC_CA_CLIENT_MSPDIR=tls && \
    fabric-ca-client enroll -u https://${ORDERER}-org0:${ORDERER}-org0-pw@rca-org0:7054 --caname rca-org0 \
      --enrollment.profile tls --csr.hosts ${ORDERER}-org0"

  cp /tmp/hyperledger/org0/orderers/${ORDERER}/tls/tlscacerts/* /tmp/hyperledger/org0/orderers/${ORDERER}/tls/ca.crt
  cp /tmp/hyperledger/org0/orderers/${ORDERER}/tls/signcerts/* /tmp/hyperledger/org0/orderers/${ORDERER}/tls/server.crt
  cp /tmp/hyperledger/org0/orderers/${ORDERER}/tls/keystore/* /tmp/hyperledger/org0/orderers/${ORDERER}/tls/server.key

  mkdir -p /tmp/hyperledger/org0/orderers/${ORDERER}/msp/tlscacerts
  cp /tmp/hyperledger/org0/orderers/${ORDERER}/tls/tlscacerts/* /tmp/hyperledger/org0/orderers/${ORDERER}/msp/tlscacerts/tlsca-cert.pem
done

run_ca "
  export FABRIC_CA_CLIENT_TLS_CERTFILES=/tmp/hyperledger/fabric-ca/org0/ca-cert.pem && \
  export FABRIC_CA_CLIENT_HOME=/tmp/hyperledger/org0 && \
  fabric-ca-client enroll -u https://rca-org0-admin:rca-org0-admin-pw@rca-org0:7054 --caname rca-org0 && \
  fabric-ca-client register --caname rca-org0 --id.name org0-admin --id.secret org0-admin-pw --id.type admin"

run_ca "
  export FABRIC_CA_CLIENT_TLS_CERTFILES=/tmp/hyperledger/fabric-ca/org0/ca-cert.pem && \
  export FABRIC_CA_CLIENT_HOME=/tmp/hyperledger/org0 && \
  export FABRIC_CA_CLIENT_MSPDIR=users/admin/msp && \
  fabric-ca-client enroll -u https://org0-admin:org0-admin-pw@rca-org0:7054 --caname rca-org0"

cp ${SCRIPT_DIR}/config/config.yaml /tmp/hyperledger/org0/users/admin/msp/config.yaml
mv /tmp/hyperledger/org0/users/admin/msp/cacerts/* /tmp/hyperledger/org0/users/admin/msp/cacerts/ca-cert.pem

## Orgs
for ORG in org1 org2; do
  docker-compose -f docker-compose.yaml up -d rca-${ORG}
  sleep ${SLEEP_DURATION}

  run_ca "
    export FABRIC_CA_CLIENT_TLS_CERTFILES=/tmp/hyperledger/fabric-ca/${ORG}/ca-cert.pem && \
    export FABRIC_CA_CLIENT_HOME=/tmp/hyperledger/${ORG} && \
    fabric-ca-client enroll -u https://rca-${ORG}-admin:rca-${ORG}-admin-pw@rca-${ORG}:7054 --caname rca-${ORG}"

  cp ${SCRIPT_DIR}/config/config.yaml /tmp/hyperledger/${ORG}/msp/config.yaml
  mv /tmp/hyperledger/${ORG}/msp/cacerts/* /tmp/hyperledger/${ORG}/msp/cacerts/ca-cert.pem

  mkdir -p /tmp/hyperledger/${ORG}/msp/tlscacerts
  cp /tmp/hyperledger/fabric-ca/${ORG}/ca-cert.pem /tmp/hyperledger/${ORG}/msp/tlscacerts/ca.crt

  mkdir -p /tmp/hyperledger/${ORG}/tlsca
  cp /tmp/hyperledger/fabric-ca/${ORG}/ca-cert.pem /tmp/hyperledger/${ORG}/tlsca/tlsca-cert.pem

  mkdir -p /tmp/hyperledger/${ORG}/ca
  cp /tmp/hyperledger/fabric-ca/${ORG}/ca-cert.pem /tmp/hyperledger/${ORG}/ca/ca-cert.pem

  run_ca "
    export FABRIC_CA_CLIENT_TLS_CERTFILES=/tmp/hyperledger/fabric-ca/${ORG}/ca-cert.pem && \
    export FABRIC_CA_CLIENT_HOME=/tmp/hyperledger/${ORG} && \
    fabric-ca-client enroll -u https://rca-${ORG}-admin:rca-${ORG}-admin-pw@rca-${ORG}:7054 --caname rca-${ORG} && \
    fabric-ca-client register --caname rca-${ORG} --id.name ${ORG}-user --id.secret ${ORG}-user-pw --id.type client && \
    fabric-ca-client register --caname rca-${ORG} --id.name ${ORG}-admin --id.secret ${ORG}-admin-pw --id.type admin"

  for PEER in peer1 peer2; do
    run_ca "
      export FABRIC_CA_CLIENT_TLS_CERTFILES=/tmp/hyperledger/fabric-ca/${ORG}/ca-cert.pem && \
      export FABRIC_CA_CLIENT_HOME=/tmp/hyperledger/${ORG} && \
      fabric-ca-client enroll -u https://rca-${ORG}-admin:rca-${ORG}-admin-pw@rca-${ORG}:7054 --caname rca-${ORG} && \
      fabric-ca-client register --caname rca-${ORG} --id.name ${PEER}-${ORG} --id.secret ${PEER}-${ORG}-pw --id.type peer"

    run_ca "
      export FABRIC_CA_CLIENT_TLS_CERTFILES=/tmp/hyperledger/fabric-ca/${ORG}/ca-cert.pem && \
      export FABRIC_CA_CLIENT_HOME=/tmp/hyperledger/${ORG}/peers/${PEER} && \
      export FABRIC_CA_CLIENT_MSPDIR=msp && \
      fabric-ca-client enroll -u https://${PEER}-${ORG}:${PEER}-${ORG}-pw@rca-${ORG}:7054 --caname rca-${ORG}"

    cp ${SCRIPT_DIR}/config/config.yaml /tmp/hyperledger/${ORG}/peers/${PEER}/msp/config.yaml
    mv /tmp/hyperledger/${ORG}/peers/${PEER}/msp/cacerts/* /tmp/hyperledger/${ORG}/peers/${PEER}/msp/cacerts/ca-cert.pem

    run_ca "
      export FABRIC_CA_CLIENT_TLS_CERTFILES=/tmp/hyperledger/fabric-ca/${ORG}/ca-cert.pem && \
      export FABRIC_CA_CLIENT_HOME=/tmp/hyperledger/${ORG}/peers/${PEER} && \
      export FABRIC_CA_CLIENT_MSPDIR=tls && \
      fabric-ca-client enroll -u https://${PEER}-${ORG}:${PEER}-${ORG}-pw@rca-${ORG}:7054 --caname rca-${ORG} \
        --enrollment.profile tls --csr.hosts ${PEER}-${ORG}"

    cp /tmp/hyperledger/${ORG}/peers/${PEER}/tls/tlscacerts/* /tmp/hyperledger/${ORG}/peers/${PEER}/tls/ca.crt
    cp /tmp/hyperledger/${ORG}/peers/${PEER}/tls/signcerts/* /tmp/hyperledger/${ORG}/peers/${PEER}/tls/server.crt
    cp /tmp/hyperledger/${ORG}/peers/${PEER}/tls/keystore/* /tmp/hyperledger/${ORG}/peers/${PEER}/tls/server.key
  done

  run_ca "
    export FABRIC_CA_CLIENT_TLS_CERTFILES=/tmp/hyperledger/fabric-ca/${ORG}/ca-cert.pem && \
    export FABRIC_CA_CLIENT_HOME=/tmp/hyperledger/${ORG} && \
    export FABRIC_CA_CLIENT_MSPDIR=users/user/msp && \
    fabric-ca-client enroll -u https://${ORG}-user:${ORG}-user-pw@rca-${ORG}:7054 --caname rca-${ORG}"

  cp ${SCRIPT_DIR}/config/config.yaml /tmp/hyperledger/${ORG}/users/user/msp/config.yaml
  mv /tmp/hyperledger/${ORG}/users/user/msp/cacerts/* /tmp/hyperledger/${ORG}/users/user/msp/cacerts/ca-cert.pem

  run_ca "
    export FABRIC_CA_CLIENT_TLS_CERTFILES=/tmp/hyperledger/fabric-ca/${ORG}/ca-cert.pem && \
    export FABRIC_CA_CLIENT_HOME=/tmp/hyperledger/${ORG} && \
    export FABRIC_CA_CLIENT_MSPDIR=users/admin/msp && \
    fabric-ca-client enroll -u https://${ORG}-admin:${ORG}-admin-pw@rca-${ORG}:7054 --caname rca-${ORG}"

  cp ${SCRIPT_DIR}/config/config.yaml /tmp/hyperledger/${ORG}/users/admin/msp/config.yaml
  mv /tmp/hyperledger/${ORG}/users/admin/msp/cacerts/* /tmp/hyperledger/${ORG}/users/admin/msp/cacerts/ca-cert.pem
  mv /tmp/hyperledger/${ORG}/users/admin/msp/keystore/* /tmp/hyperledger/${ORG}/users/admin/msp/keystore/priv_sk
done

# Create channel
run_tools "
  export FABRIC_CFG_PATH=/tmp/hyperledger/config && \
  configtxgen -profile ChannelUsingBFT -outputBlock /tmp/hyperledger/config/${CHANNEL_NAME}.block -channelID ${CHANNEL_NAME}"

docker-compose -f docker-compose.yaml up -d orderer1-org0 orderer2-org0 orderer3-org0 orderer4-org0
docker-compose -f docker-compose.yaml up -d peer1-org1 peer2-org1 peer1-org2 peer2-org2

docker-compose -f docker-compose.yaml up -d cli-org0 cli-org1 cli-org2
sleep ${SLEEP_DURATION}

# Join channel
for ORDERER in orderer1 orderer2 orderer3 orderer4; do
  docker exec \
    cli-org0 \
    osnadmin channel join --channelID ${CHANNEL_NAME} -o ${ORDERER}-org0:9443 \
      --config-block /tmp/hyperledger/config/${CHANNEL_NAME}.block \
      --ca-file /tmp/hyperledger/org0/tlsca/tlsca-cert.pem \
      --client-cert /tmp/hyperledger/org0/orderers/${ORDERER}/tls/server.crt \
      --client-key /tmp/hyperledger/org0/orderers/${ORDERER}/tls/server.key
done

for ORG in org1 org2; do
  for PEER in peer1 peer2; do
    docker exec \
      -e CORE_PEER_ADDRESS=${PEER}-${ORG}:7051 \
      cli-${ORG} \
      peer channel join -b /tmp/hyperledger/config/${CHANNEL_NAME}.block
  done
done

# # Set anchor peers
# for ORG in org1 org2; do
#   docker exec \
#     cli-${ORG} \
#     peer channel fetch config /tmp/hyperledger/config/config_block.pb \
#       -o orderer1-org0:7050 --ordererTLSHostnameOverride orderer1-org0 \
#       --channelID ${CHANNEL_NAME} --tls \
#       --cafile /tmp/hyperledger/org0/tlsca/tlsca-cert.pem

#   MSPID="$(echo "${ORG}" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')MSP"
#   run_tools "
#     configtxlator proto_decode --input /tmp/hyperledger/config/config_block.pb --type common.Block --output /tmp/hyperledger/config/config_block.json && \
#     jq .data.data[0].payload.data.config /tmp/hyperledger/config/config_block.json > /tmp/hyperledger/config/${MSPID}config.json && \
#     jq '.channel_group.groups.Application.groups.${MSPID}.values += {\"AnchorPeers\":{\"mod_policy\": \"Admins\",\"value\":{\"anchor_peers\": [{\"host\": \"peer1-${ORG}\",\"port\": 7051}]},\"version\": \"0\"}}' /tmp/hyperledger/config/${MSPID}config.json > /tmp/hyperledger/config/${MSPID}modified_config.json && \
#     configtxlator proto_encode --input /tmp/hyperledger/config/${MSPID}config.json --type common.Config --output /tmp/hyperledger/config/original_config.pb && \
#     configtxlator proto_encode --input /tmp/hyperledger/config/${MSPID}modified_config.json --type common.Config --output /tmp/hyperledger/config/modified_config.pb && \
#     configtxlator compute_update --channel_id "${CHANNEL_NAME}" --original /tmp/hyperledger/config/original_config.pb --updated /tmp/hyperledger/config/modified_config.pb --output /tmp/hyperledger/config/config_update.pb && \
#     configtxlator proto_decode --input /tmp/hyperledger/config/config_update.pb --type common.ConfigUpdate --output /tmp/hyperledger/config/config_update.json && \
#     echo \"{\\\"payload\\\":{\\\"header\\\":{\\\"channel_header\\\":{\\\"channel_id\\\":\\\"${CHANNEL_NAME}\\\", \\\"type\\\":2}},\\\"data\\\":{\\\"config_update\\\":\$(cat /tmp/hyperledger/config/config_update.json)}}}\" | jq . > /tmp/hyperledger/config/config_update_in_envelope.json && \
#     configtxlator proto_encode --input /tmp/hyperledger/config/config_update_in_envelope.json --type common.Envelope --output /tmp/hyperledger/config/${MSPID}anchors.tx"

#   docker exec \
#     cli-${ORG} \
#     peer channel update -o orderer1-org0:7050 \
#       --ordererTLSHostnameOverride orderer1-org0 \
#       --channelID ${CHANNEL_NAME} --tls \
#       -f /tmp/hyperledger/config/${MSPID}anchors.tx \
#       --cafile /tmp/hyperledger/org0/tlsca/tlsca-cert.pem
# done

# Package chaincode
for ORG in org1 org2; do
  docker exec \
    cli-${ORG} \
    peer lifecycle chaincode package ${CHAINCODE_NAME}.tar.gz \
      --path /opt/gopath/src/github.com/chaincode/${CHAINCODE_NAME} \
      --lang node --label ${CHAINCODE_NAME}_${CHAINCODE_VERSION}
done

# Install chaincode
for ORG in org1 org2; do
  docker exec \
    cli-${ORG} \
    peer lifecycle chaincode install ${CHAINCODE_NAME}.tar.gz
done

docker exec \
  cli-org1 \
  peer lifecycle chaincode queryinstalled >&log.txt

PACKAGE_ID=$(sed -n '/Package/{s/^Package ID: //; s/, Label:.*$//; p;}' log.txt)
echo PackageID is ${PACKAGE_ID}

# Approve chaincode
for ORG in org1 org2; do
  docker exec \
    cli-${ORG} \
    peer lifecycle chaincode approveformyorg -o orderer1-org0:7050 \
      --ordererTLSHostnameOverride orderer1-org0 --tls \
      --cafile /tmp/hyperledger/org0/tlsca/tlsca-cert.pem \
      --channelID ${CHANNEL_NAME} --name ${CHAINCODE_NAME} \
      --version ${CHAINCODE_VERSION} --package-id ${PACKAGE_ID} \
      --sequence ${CHAINCODE_SEQUENCE} --init-required

  docker exec \
    cli-${ORG} \
    peer lifecycle chaincode checkcommitreadiness --channelID ${CHANNEL_NAME} \
      --name ${CHAINCODE_NAME} --version ${CHAINCODE_VERSION} \
      --sequence ${CHAINCODE_SEQUENCE} --init-required \
      --output json > log.txt

  CAPITALIZED_ORG=$(echo "${ORG}" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')
  if ! $(jq ".approvals.${CAPITALIZED_ORG}MSP" log.txt); then
    exit 1
  fi
done

# Commit chaincode
sleep ${SLEEP_DURATION}
docker exec \
  cli-org1 \
  peer lifecycle chaincode commit -o orderer1-org0:7050 \
    --ordererTLSHostnameOverride orderer1-org0 --tls \
    --cafile /tmp/hyperledger/org0/tlsca/tlsca-cert.pem \
    --channelID ${CHANNEL_NAME} --name ${CHAINCODE_NAME} \
    --peerAddresses peer1-org1:7051 --tlsRootCertFiles /tmp/hyperledger/org1/tlsca/tlsca-cert.pem \
    --peerAddresses peer1-org2:7051 --tlsRootCertFiles /tmp/hyperledger/org2/tlsca/tlsca-cert.pem \
    --version ${CHAINCODE_VERSION} --sequence ${CHAINCODE_SEQUENCE} --init-required

for ORG in org1 org2; do
  docker exec \
    cli-${ORG} \
    peer lifecycle chaincode querycommitted --channelID ${CHANNEL_NAME} --name ${CHAINCODE_NAME}
done

# Init chaincode
sleep ${SLEEP_DURATION}
docker exec \
  cli-org1 \
  peer chaincode invoke -o orderer1-org0:7050 \
    --ordererTLSHostnameOverride orderer1-org0 --tls \
    --cafile /tmp/hyperledger/org0/tlsca/tlsca-cert.pem \
    --channelID ${CHANNEL_NAME} --name ${CHAINCODE_NAME} \
    --peerAddresses peer1-org1:7051 --tlsRootCertFiles /tmp/hyperledger/org1/tlsca/tlsca-cert.pem \
    --peerAddresses peer1-org2:7051 --tlsRootCertFiles /tmp/hyperledger/org2/tlsca/tlsca-cert.pem \
    --isInit -c '{"Args":[]}'

# Query chaincode
sleep ${SLEEP_DURATION}
docker exec \
  cli-org1 \
  peer chaincode query --channelID ${CHANNEL_NAME} --name ${CHAINCODE_NAME} \
    -c '{"Args":["testGet"]}'

# Invoke chaincode
sleep ${SLEEP_DURATION}
docker exec \
  cli-org1 \
  peer chaincode invoke -o orderer1-org0:7050 --tls \
    --cafile /tmp/hyperledger/org0/tlsca/tlsca-cert.pem \
    --channelID ${CHANNEL_NAME} --name ${CHAINCODE_NAME} \
    --peerAddresses peer1-org1:7051 --tlsRootCertFiles /tmp/hyperledger/org1/tlsca/tlsca-cert.pem \
    --peerAddresses peer1-org2:7051 --tlsRootCertFiles /tmp/hyperledger/org2/tlsca/tlsca-cert.pem \
    -c '{"Args":["addMarks","Alice","68","84","89"]}'

# Query chaincode
sleep ${SLEEP_DURATION}
docker exec \
  cli-org1 \
  peer chaincode query --channelID ${CHANNEL_NAME} --name ${CHAINCODE_NAME} \
    -c '{"Args":["queryMarks","Alice"]}'

# Start explorer
docker-compose -f docker-compose.yaml up -d explorer
sleep ${SLEEP_DURATION}
open http://localhost:8080/

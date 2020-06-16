#!/bin/bash

# Exit on first error
set -euo pipefail

# Variables
SYS_CHANNEL_NAME="syschannel"
CHANNEL_NAME="mychannel"
CHAINCODE_NAME="mychaincode"
CHAINCODE_VERSION=1
CHAINCODE_SEQUENCE=1
CHAINCODE_SOURCE_PATH="/opt/gopath/src/github.com/chaincode/${CHAINCODE_NAME}"
PEER0_ORG1_CA=/tmp/hyperledger/org1/peer1/tls-msp/tlscacerts/tls-ca-tls-7052.pem
PEER0_ORG2_CA=/tmp/hyperledger/org2/peer1/tls-msp/tlscacerts/tls-ca-tls-7052.pem
ORDERER=orderer1-org0:7050
SLEEP_DURATION=2

export SCRIPT_DIR=$(PWD)
export COMPOSE_PROJECT_NAME=byfn
export COUCHDB_VERSION=2.3.1
export CA_VERSION=1.4.7
export TOOLS_VERSION=2.1.1
export PEER_VERSION=2.1.1
export ORDERER_VERSION=2.1.1

# Common functions
function run_ca() {
  docker run -v /tmp/hyperledger:/tmp/hyperledger -u $(id -u) --network="${COMPOSE_PROJECT_NAME}_net" --rm hyperledger/fabric-ca:${CA_VERSION} sh -c "$*"
}

function run_tools() {
  docker run -v /tmp/hyperledger:/tmp/hyperledger -u $(id -u) --network="${COMPOSE_PROJECT_NAME}_net" \
    -v "${SCRIPT_DIR}/configtx.yaml:/tmp/hyperledger/config/configtx.yaml" --rm hyperledger/fabric-tools:${TOOLS_VERSION} sh -c "$*"
}

# Clear artifacts
docker-compose -f docker-compose.yaml down
rm -rf /tmp/hyperledger/*

# # Stop and remove all docker containers
# docker stop $(docker ps -aq) || true
# docker rm $(docker ps -aq) || true

# Ref: https://hyperledger-fabric-ca.readthedocs.io/en/latest/operations_guide.html

# Setup CAs
## Setup TLS CA
docker-compose -f docker-compose.yaml up -d ca-tls

## Enroll TLS CA’s Admin
sleep ${SLEEP_DURATION}
run_ca "export FABRIC_CA_CLIENT_TLS_CERTFILES=/tmp/hyperledger/tls/ca/crypto/ca-cert.pem && \
  export FABRIC_CA_CLIENT_HOME=/tmp/hyperledger/tls/ca/admin && \
  fabric-ca-client enroll -d -u https://tls-ca-admin:tls-ca-AdminPW@ca-tls:7052 && \
  fabric-ca-client register -d --id.name peer1-org1 --id.secret peer1PW --id.type peer -u https://ca-tls:7052 && \
  fabric-ca-client register -d --id.name peer2-org1 --id.secret peer2PW --id.type peer -u https://ca-tls:7052 && \
  fabric-ca-client register -d --id.name peer1-org2 --id.secret peer1PW --id.type peer -u https://ca-tls:7052 && \
  fabric-ca-client register -d --id.name peer2-org2 --id.secret peer2PW --id.type peer -u https://ca-tls:7052 && \
  fabric-ca-client register -d --id.name orderer1-org0 --id.secret orderer1PW --id.type orderer -u https://ca-tls:7052 && \
  fabric-ca-client register -d --id.name orderer2-org0 --id.secret orderer2PW --id.type orderer -u https://ca-tls:7052 && \
  fabric-ca-client register -d --id.name orderer3-org0 --id.secret orderer3PW --id.type orderer -u https://ca-tls:7052"

## Setup Orderer Org CA
docker-compose -f docker-compose.yaml up -d rca-org0

## Enroll Orderer Org’s CA Admin
sleep ${SLEEP_DURATION}
run_ca "export FABRIC_CA_CLIENT_TLS_CERTFILES=/tmp/hyperledger/org0/ca/crypto/ca-cert.pem && \
  export FABRIC_CA_CLIENT_HOME=/tmp/hyperledger/org0/ca/admin && \
  fabric-ca-client enroll -d -u https://rca-org0-admin:rca-org0-AdminPW@rca-org0:7053 && \
  fabric-ca-client register -d --id.name orderer1-org0 --id.secret orderer1PW --id.type orderer -u https://rca-org0:7053 && \
  fabric-ca-client register -d --id.name orderer2-org0 --id.secret orderer2PW --id.type orderer -u https://rca-org0:7053 && \
  fabric-ca-client register -d --id.name orderer3-org0 --id.secret orderer3PW --id.type orderer -u https://rca-org0:7053 && \
  fabric-ca-client register -d --id.name admin-org0 --id.secret org0AdminPW --id.type admin \
    --id.attrs \"hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert\" \
    -u https://rca-org0:7053 && \
  fabric-ca-client register -d --id.name user-org0 --id.secret org0UserPW --id.type user -u https://rca-org0:7053"

## Setup Org1’s CA
docker-compose -f docker-compose.yaml up -d rca-org1

## Enroll Org1’s CA Admin
sleep ${SLEEP_DURATION}
run_ca "export FABRIC_CA_CLIENT_TLS_CERTFILES=/tmp/hyperledger/org1/ca/crypto/ca-cert.pem && \
  export FABRIC_CA_CLIENT_HOME=/tmp/hyperledger/org1/ca/admin && \
  fabric-ca-client enroll -d -u https://rca-org1-admin:rca-org1-AdminPW@rca-org1:7054 && \
  fabric-ca-client register -d --id.name peer1-org1 --id.secret peer1PW --id.type peer -u https://rca-org1:7054 && \
  fabric-ca-client register -d --id.name peer2-org1 --id.secret peer2PW --id.type peer -u https://rca-org1:7054 && \
  fabric-ca-client register -d --id.name admin-org1 --id.secret org1AdminPW --id.type admin -u https://rca-org1:7054 && \
  fabric-ca-client register -d --id.name user-org1 --id.secret org1UserPW --id.type user -u https://rca-org1:7054"

## Setup Org2’s CA
docker-compose -f docker-compose.yaml up -d rca-org2

## Enroll Org2’s CA Admin
sleep ${SLEEP_DURATION}
run_ca "export FABRIC_CA_CLIENT_TLS_CERTFILES=/tmp/hyperledger/org2/ca/crypto/ca-cert.pem && \
  export FABRIC_CA_CLIENT_HOME=/tmp/hyperledger/org2/ca/admin && \
  fabric-ca-client enroll -d -u https://rca-org2-admin:rca-org2-AdminPW@rca-org2:7055 && \
  fabric-ca-client register -d --id.name peer1-org2 --id.secret peer1PW --id.type peer -u https://rca-org2:7055 && \
  fabric-ca-client register -d --id.name peer2-org2 --id.secret peer2PW --id.type peer -u https://rca-org2:7055 && \
  fabric-ca-client register -d --id.name admin-org2 --id.secret org2AdminPW --id.type admin -u https://rca-org2:7055 && \
  fabric-ca-client register -d --id.name user-org2 --id.secret org2UserPW --id.type user -u https://rca-org2:7055"

# Setup Peers
## Setup Org1’s Peers
### Enroll Peer1
sleep ${SLEEP_DURATION}
ASSETS_DIR=/tmp/hyperledger/org1/peer1/assets/ca
mkdir -p ${ASSETS_DIR}
cp /tmp/hyperledger/org1/ca/crypto/ca-cert.pem ${ASSETS_DIR}/org1-ca-cert.pem

run_ca "export FABRIC_CA_CLIENT_HOME=/tmp/hyperledger/org1/peer1 && \
  export FABRIC_CA_CLIENT_TLS_CERTFILES=/tmp/hyperledger/org1/peer1/assets/ca/org1-ca-cert.pem && \
  export FABRIC_CA_CLIENT_MSPDIR=msp && \
  fabric-ca-client enroll -d -u https://peer1-org1:peer1PW@rca-org1:7054 --csr.hosts peer1-org1"

ASSETS_DIR=/tmp/hyperledger/org1/peer1/assets/tls-ca
mkdir -p ${ASSETS_DIR}
cp /tmp/hyperledger/tls/ca/crypto/ca-cert.pem ${ASSETS_DIR}/tls-ca-cert.pem

run_ca "export FABRIC_CA_CLIENT_HOME=/tmp/hyperledger/org1/peer1 && \
  export FABRIC_CA_CLIENT_TLS_CERTFILES=/tmp/hyperledger/org1/peer1/assets/tls-ca/tls-ca-cert.pem && \
  export FABRIC_CA_CLIENT_MSPDIR=tls-msp && \
  fabric-ca-client enroll -d -u https://peer1-org1:peer1PW@ca-tls:7052 --enrollment.profile tls --csr.hosts peer1-org1"

KEY_FILE=$(ls /tmp/hyperledger/org1/peer1/tls-msp/keystore/*_sk)
mv ${KEY_FILE} /tmp/hyperledger/org1/peer1/tls-msp/keystore/key.pem

### Enroll Peer2
sleep ${SLEEP_DURATION}
ASSETS_DIR=/tmp/hyperledger/org1/peer2/assets/ca
mkdir -p ${ASSETS_DIR}
cp /tmp/hyperledger/org1/ca/crypto/ca-cert.pem ${ASSETS_DIR}/org1-ca-cert.pem

run_ca "export FABRIC_CA_CLIENT_HOME=/tmp/hyperledger/org1/peer2 && \
  export FABRIC_CA_CLIENT_TLS_CERTFILES=/tmp/hyperledger/org1/peer2/assets/ca/org1-ca-cert.pem && \
  export FABRIC_CA_CLIENT_MSPDIR=msp && \
  fabric-ca-client enroll -d -u https://peer2-org1:peer2PW@rca-org1:7054 --csr.hosts peer2-org1"

ASSETS_DIR=/tmp/hyperledger/org1/peer2/assets/tls-ca
mkdir -p ${ASSETS_DIR}
cp /tmp/hyperledger/tls/ca/crypto/ca-cert.pem ${ASSETS_DIR}/tls-ca-cert.pem

run_ca "export FABRIC_CA_CLIENT_HOME=/tmp/hyperledger/org1/peer2 && \
  export FABRIC_CA_CLIENT_TLS_CERTFILES=/tmp/hyperledger/org1/peer2/assets/tls-ca/tls-ca-cert.pem && \
  export FABRIC_CA_CLIENT_MSPDIR=tls-msp && \
  fabric-ca-client enroll -d -u https://peer2-org1:peer2PW@ca-tls:7052 --enrollment.profile tls --csr.hosts peer2-org1"

KEY_FILE=$(ls /tmp/hyperledger/org1/peer2/tls-msp/keystore/*_sk)
mv ${KEY_FILE} /tmp/hyperledger/org1/peer2/tls-msp/keystore/key.pem

### Enroll Org1’s Admin
run_ca "export FABRIC_CA_CLIENT_HOME=/tmp/hyperledger/org1/admin && \
  export FABRIC_CA_CLIENT_TLS_CERTFILES=/tmp/hyperledger/org1/peer1/assets/ca/org1-ca-cert.pem && \
  export FABRIC_CA_CLIENT_MSPDIR=msp && \
  fabric-ca-client enroll -d -u https://admin-org1:org1AdminPW@rca-org1:7054"

ADMINCERTS_DIR=/tmp/hyperledger/org1/peer1/msp/admincerts
mkdir -p ${ADMINCERTS_DIR}
cp /tmp/hyperledger/org1/admin/msp/signcerts/cert.pem ${ADMINCERTS_DIR}/org1-admin-cert.pem

ADMINCERTS_DIR=/tmp/hyperledger/org1/peer2/msp/admincerts
mkdir -p ${ADMINCERTS_DIR}
cp /tmp/hyperledger/org1/admin/msp/signcerts/cert.pem ${ADMINCERTS_DIR}/org1-admin-cert.pem

### Launch Org1’s Peers
docker-compose -f docker-compose.yaml up -d peer1-org1 peer2-org1

## Setup Org2’s Peers
### Enroll Peer1
sleep ${SLEEP_DURATION}
ASSETS_DIR=/tmp/hyperledger/org2/peer1/assets/ca
mkdir -p ${ASSETS_DIR}
cp /tmp/hyperledger/org2/ca/crypto/ca-cert.pem ${ASSETS_DIR}/org2-ca-cert.pem

run_ca "export FABRIC_CA_CLIENT_HOME=/tmp/hyperledger/org2/peer1 && \
  export FABRIC_CA_CLIENT_TLS_CERTFILES=/tmp/hyperledger/org2/peer1/assets/ca/org2-ca-cert.pem && \
  export FABRIC_CA_CLIENT_MSPDIR=msp && \
  fabric-ca-client enroll -d -u https://peer1-org2:peer1PW@rca-org2:7055 --csr.hosts peer1-org2"

ASSETS_DIR=/tmp/hyperledger/org2/peer1/assets/tls-ca
mkdir -p ${ASSETS_DIR}
cp /tmp/hyperledger/tls/ca/crypto/ca-cert.pem ${ASSETS_DIR}/tls-ca-cert.pem

run_ca "export FABRIC_CA_CLIENT_HOME=/tmp/hyperledger/org2/peer1 && \
  export FABRIC_CA_CLIENT_TLS_CERTFILES=/tmp/hyperledger/org2/peer1/assets/tls-ca/tls-ca-cert.pem && \
  export FABRIC_CA_CLIENT_MSPDIR=tls-msp && \
  fabric-ca-client enroll -d -u https://peer1-org2:peer1PW@ca-tls:7052 --enrollment.profile tls --csr.hosts peer1-org2"

KEY_FILE=$(ls /tmp/hyperledger/org2/peer1/tls-msp/keystore/*_sk)
mv ${KEY_FILE} /tmp/hyperledger/org2/peer1/tls-msp/keystore/key.pem

### Enroll Peer2
sleep ${SLEEP_DURATION}
ASSETS_DIR=/tmp/hyperledger/org2/peer2/assets/ca
mkdir -p ${ASSETS_DIR}
cp /tmp/hyperledger/org2/ca/crypto/ca-cert.pem ${ASSETS_DIR}/org2-ca-cert.pem

run_ca "export FABRIC_CA_CLIENT_HOME=/tmp/hyperledger/org2/peer2 && \
  export FABRIC_CA_CLIENT_TLS_CERTFILES=/tmp/hyperledger/org2/peer2/assets/ca/org2-ca-cert.pem && \
  export FABRIC_CA_CLIENT_MSPDIR=msp && \
  fabric-ca-client enroll -d -u https://peer2-org2:peer2PW@rca-org2:7055 --csr.hosts peer2-org2"

ASSETS_DIR=/tmp/hyperledger/org2/peer2/assets/tls-ca
mkdir -p ${ASSETS_DIR}
cp /tmp/hyperledger/tls/ca/crypto/ca-cert.pem ${ASSETS_DIR}/tls-ca-cert.pem

run_ca "export FABRIC_CA_CLIENT_HOME=/tmp/hyperledger/org2/peer2 && \
  export FABRIC_CA_CLIENT_TLS_CERTFILES=/tmp/hyperledger/org2/peer2/assets/tls-ca/tls-ca-cert.pem && \
  export FABRIC_CA_CLIENT_MSPDIR=tls-msp && \
  fabric-ca-client enroll -d -u https://peer2-org2:peer2PW@ca-tls:7052 --enrollment.profile tls --csr.hosts peer2-org2"

KEY_FILE=$(ls /tmp/hyperledger/org2/peer2/tls-msp/keystore/*_sk)
mv ${KEY_FILE} /tmp/hyperledger/org2/peer2/tls-msp/keystore/key.pem

### Enroll Org2’s Admin
run_ca "export FABRIC_CA_CLIENT_HOME=/tmp/hyperledger/org2/admin && \
  export FABRIC_CA_CLIENT_TLS_CERTFILES=/tmp/hyperledger/org2/peer1/assets/ca/org2-ca-cert.pem && \
  export FABRIC_CA_CLIENT_MSPDIR=msp && \
  fabric-ca-client enroll -d -u https://admin-org2:org2AdminPW@rca-org2:7055"

ADMINCERTS_DIR=/tmp/hyperledger/org2/peer1/msp/admincerts
mkdir -p ${ADMINCERTS_DIR}
cp /tmp/hyperledger/org2/admin/msp/signcerts/cert.pem ${ADMINCERTS_DIR}/org2-admin-cert.pem

ADMINCERTS_DIR=/tmp/hyperledger/org2/peer2/msp/admincerts
mkdir -p ${ADMINCERTS_DIR}
cp /tmp/hyperledger/org2/admin/msp/signcerts/cert.pem ${ADMINCERTS_DIR}/org2-admin-cert.pem

### Launch Org2’s Peers
docker-compose -f docker-compose.yaml up -d peer1-org2 peer2-org2

# Setup Orderers
## Enroll Orderer1
sleep ${SLEEP_DURATION}
ASSETS_DIR=/tmp/hyperledger/org0/orderer1/assets/ca
mkdir -p ${ASSETS_DIR}
cp /tmp/hyperledger/org0/ca/crypto/ca-cert.pem ${ASSETS_DIR}/org0-ca-cert.pem

run_ca "export FABRIC_CA_CLIENT_HOME=/tmp/hyperledger/org0/orderer1 && \
  export FABRIC_CA_CLIENT_TLS_CERTFILES=/tmp/hyperledger/org0/orderer1/assets/ca/org0-ca-cert.pem && \
  export FABRIC_CA_CLIENT_MSPDIR=msp && \
  fabric-ca-client enroll -d -u https://orderer1-org0:orderer1PW@rca-org0:7053 --csr.hosts orderer1-org0"

ASSETS_DIR=/tmp/hyperledger/org0/orderer1/assets/tls-ca
mkdir -p ${ASSETS_DIR}
cp /tmp/hyperledger/tls/ca/crypto/ca-cert.pem ${ASSETS_DIR}/tls-ca-cert.pem

run_ca "export FABRIC_CA_CLIENT_HOME=/tmp/hyperledger/org0/orderer1 && \
  export FABRIC_CA_CLIENT_TLS_CERTFILES=/tmp/hyperledger/org0/orderer1/assets/tls-ca/tls-ca-cert.pem && \
  export FABRIC_CA_CLIENT_MSPDIR=tls-msp && \
  fabric-ca-client enroll -d -u https://orderer1-org0:orderer1PW@ca-tls:7052 --enrollment.profile tls --csr.hosts orderer1-org0"

KEY_FILE=$(ls /tmp/hyperledger/org0/orderer1/tls-msp/keystore/*_sk)
mv ${KEY_FILE} /tmp/hyperledger/org0/orderer1/tls-msp/keystore/key.pem

## Enroll Orderer2
sleep ${SLEEP_DURATION}
ASSETS_DIR=/tmp/hyperledger/org0/orderer2/assets/ca
mkdir -p ${ASSETS_DIR}
cp /tmp/hyperledger/org0/ca/crypto/ca-cert.pem ${ASSETS_DIR}/org0-ca-cert.pem

run_ca "export FABRIC_CA_CLIENT_HOME=/tmp/hyperledger/org0/orderer2 && \
  export FABRIC_CA_CLIENT_TLS_CERTFILES=/tmp/hyperledger/org0/orderer2/assets/ca/org0-ca-cert.pem && \
  export FABRIC_CA_CLIENT_MSPDIR=msp && \
  fabric-ca-client enroll -d -u https://orderer2-org0:orderer2PW@rca-org0:7053 --csr.hosts orderer2-org0"

ASSETS_DIR=/tmp/hyperledger/org0/orderer2/assets/tls-ca
mkdir -p ${ASSETS_DIR}
cp /tmp/hyperledger/tls/ca/crypto/ca-cert.pem ${ASSETS_DIR}/tls-ca-cert.pem

run_ca "export FABRIC_CA_CLIENT_HOME=/tmp/hyperledger/org0/orderer2 && \
  export FABRIC_CA_CLIENT_TLS_CERTFILES=/tmp/hyperledger/org0/orderer2/assets/tls-ca/tls-ca-cert.pem && \
  export FABRIC_CA_CLIENT_MSPDIR=tls-msp && \
  fabric-ca-client enroll -d -u https://orderer2-org0:orderer2PW@ca-tls:7052 --enrollment.profile tls --csr.hosts orderer2-org0"

KEY_FILE=$(ls /tmp/hyperledger/org0/orderer2/tls-msp/keystore/*_sk)
mv ${KEY_FILE} /tmp/hyperledger/org0/orderer2/tls-msp/keystore/key.pem

## Enroll Orderer3
sleep ${SLEEP_DURATION}
ASSETS_DIR=/tmp/hyperledger/org0/orderer3/assets/ca
mkdir -p ${ASSETS_DIR}
cp /tmp/hyperledger/org0/ca/crypto/ca-cert.pem ${ASSETS_DIR}/org0-ca-cert.pem

run_ca "export FABRIC_CA_CLIENT_HOME=/tmp/hyperledger/org0/orderer3 && \
  export FABRIC_CA_CLIENT_TLS_CERTFILES=/tmp/hyperledger/org0/orderer3/assets/ca/org0-ca-cert.pem && \
  export FABRIC_CA_CLIENT_MSPDIR=msp && \
  fabric-ca-client enroll -d -u https://orderer3-org0:orderer3PW@rca-org0:7053 --csr.hosts orderer3-org0"

ASSETS_DIR=/tmp/hyperledger/org0/orderer3/assets/tls-ca
mkdir -p ${ASSETS_DIR}
cp /tmp/hyperledger/tls/ca/crypto/ca-cert.pem ${ASSETS_DIR}/tls-ca-cert.pem

run_ca "export FABRIC_CA_CLIENT_HOME=/tmp/hyperledger/org0/orderer3 && \
  export FABRIC_CA_CLIENT_TLS_CERTFILES=/tmp/hyperledger/org0/orderer3/assets/tls-ca/tls-ca-cert.pem && \
  export FABRIC_CA_CLIENT_MSPDIR=tls-msp && \
  fabric-ca-client enroll -d -u https://orderer3-org0:orderer3PW@ca-tls:7052 --enrollment.profile tls --csr.hosts orderer3-org0"

KEY_FILE=$(ls /tmp/hyperledger/org0/orderer3/tls-msp/keystore/*_sk)
mv ${KEY_FILE} /tmp/hyperledger/org0/orderer3/tls-msp/keystore/key.pem

# ## Enroll Org0’s Admin
run_ca "export FABRIC_CA_CLIENT_HOME=/tmp/hyperledger/org0/admin && \
  export FABRIC_CA_CLIENT_TLS_CERTFILES=/tmp/hyperledger/org0/orderer1/assets/ca/org0-ca-cert.pem && \
  export FABRIC_CA_CLIENT_MSPDIR=msp && \
  fabric-ca-client enroll -d -u https://admin-org0:org0AdminPW@rca-org0:7053"

ADMINCERTS_DIR=/tmp/hyperledger/org0/orderer1/msp/admincerts
mkdir -p ${ADMINCERTS_DIR}
cp /tmp/hyperledger/org0/admin/msp/signcerts/cert.pem ${ADMINCERTS_DIR}/org0-admin-cert.pem

ADMINCERTS_DIR=/tmp/hyperledger/org0/orderer2/msp/admincerts
mkdir -p ${ADMINCERTS_DIR}
cp /tmp/hyperledger/org0/admin/msp/signcerts/cert.pem ${ADMINCERTS_DIR}/org0-admin-cert.pem

ADMINCERTS_DIR=/tmp/hyperledger/org0/orderer3/msp/admincerts
mkdir -p ${ADMINCERTS_DIR}
cp /tmp/hyperledger/org0/admin/msp/signcerts/cert.pem ${ADMINCERTS_DIR}/org0-admin-cert.pem

## Create Genesis Block and Channel Transaction
sleep ${SLEEP_DURATION}
mkdir -p /tmp/hyperledger/org0/msp/admincerts && mkdir -p /tmp/hyperledger/org0/msp/cacerts &&
  mkdir -p /tmp/hyperledger/org0/msp/tlscacerts && mkdir -p /tmp/hyperledger/org0/msp/users
cp /tmp/hyperledger/org0/admin/msp/signcerts/cert.pem /tmp/hyperledger/org0/msp/admincerts/admin-org0-cert.pem
cp /tmp/hyperledger/org0/ca/crypto/ca-cert.pem /tmp/hyperledger/org0/msp/cacerts/ca-cert.pem
cp /tmp/hyperledger/tls/ca/crypto/ca-cert.pem /tmp/hyperledger/org0/msp/tlscacerts/tls-ca-cert.pem

mkdir -p /tmp/hyperledger/org1/msp/admincerts && mkdir -p /tmp/hyperledger/org1/msp/cacerts &&
  mkdir -p /tmp/hyperledger/org1/msp/tlscacerts && mkdir -p /tmp/hyperledger/org1/msp/users
cp /tmp/hyperledger/org1/admin/msp/signcerts/cert.pem /tmp/hyperledger/org1/msp/admincerts/admin-org1-cert.pem
cp /tmp/hyperledger/org1/ca/crypto/ca-cert.pem /tmp/hyperledger/org1/msp/cacerts/ca-cert.pem
cp /tmp/hyperledger/tls/ca/crypto/ca-cert.pem /tmp/hyperledger/org1/msp/tlscacerts/tls-ca-cert.pem

mkdir -p /tmp/hyperledger/org2/msp/admincerts && mkdir -p /tmp/hyperledger/org2/msp/cacerts &&
  mkdir -p /tmp/hyperledger/org2/msp/tlscacerts && mkdir -p /tmp/hyperledger/org2/msp/users
cp /tmp/hyperledger/org2/admin/msp/signcerts/cert.pem /tmp/hyperledger/org2/msp/admincerts/admin-org2-cert.pem
cp /tmp/hyperledger/org2/ca/crypto/ca-cert.pem /tmp/hyperledger/org2/msp/cacerts/ca-cert.pem
cp /tmp/hyperledger/tls/ca/crypto/ca-cert.pem /tmp/hyperledger/org2/msp/tlscacerts/tls-ca-cert.pem

mv /tmp/hyperledger/org0/admin/msp/cacerts/rca-org0-7053.pem /tmp/hyperledger/org0/admin/msp/cacerts/ca-cert.pem
mv /tmp/hyperledger/org1/admin/msp/cacerts/rca-org1-7054.pem /tmp/hyperledger/org1/admin/msp/cacerts/ca-cert.pem
mv /tmp/hyperledger/org2/admin/msp/cacerts/rca-org2-7055.pem /tmp/hyperledger/org2/admin/msp/cacerts/ca-cert.pem
cp config.yaml /tmp/hyperledger/org0/admin/msp/config.yaml
cp config.yaml /tmp/hyperledger/org1/admin/msp/config.yaml
cp config.yaml /tmp/hyperledger/org2/admin/msp/config.yaml

run_tools "export FABRIC_CFG_PATH=/tmp/hyperledger/config && \
  configtxgen -profile SampleMultiNodeEtcdRaft -outputBlock /tmp/hyperledger/org0/orderer1/genesis.block -channelID ${SYS_CHANNEL_NAME} && \
  configtxgen -profile TwoOrgsChannel -outputCreateChannelTx /tmp/hyperledger/org0/orderer1/channel.tx -channelID ${CHANNEL_NAME} && \
  configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate /tmp/hyperledger/org0/orderer1/org1Anchors.tx -channelID ${CHANNEL_NAME} -asOrg Org1 && \
  configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate /tmp/hyperledger/org0/orderer1/org2Anchors.tx -channelID ${CHANNEL_NAME} -asOrg Org2"

cp /tmp/hyperledger/org0/orderer1/genesis.block /tmp/hyperledger/org0/orderer2/genesis.block
cp /tmp/hyperledger/org0/orderer1/genesis.block /tmp/hyperledger/org0/orderer3/genesis.block

## Launch Orderers
docker-compose -f docker-compose.yaml up -d orderer1-org0 orderer2-org0 orderer3-org0

# Create CLI Containers
## Launch Org1’s CLI
## Launch Org2’s CLI
sleep ${SLEEP_DURATION}
docker-compose -f docker-compose.yaml up -d cli-org1 cli-org2

# Create and Join Channel
## Org1
cp /tmp/hyperledger/org0/orderer1/channel.tx /tmp/hyperledger/org1/peer1/assets/channel.tx
cp /tmp/hyperledger/org0/orderer1/org1Anchors.tx /tmp/hyperledger/org1/peer1/assets/org1Anchors.tx

docker exec \
  -e "CORE_PEER_MSPCONFIGPATH=/tmp/hyperledger/org1/admin/msp" \
  cli-org1 \
  peer channel create -c ${CHANNEL_NAME} -f /tmp/hyperledger/org1/peer1/assets/channel.tx -o ${ORDERER} \
  --outputBlock /tmp/hyperledger/org1/peer1/assets/${CHANNEL_NAME}.block --cafile ${PEER0_ORG1_CA} --tls

sleep ${SLEEP_DURATION}
docker exec \
  -e "CORE_PEER_MSPCONFIGPATH=/tmp/hyperledger/org1/admin/msp" \
  -e "CORE_PEER_ADDRESS=peer1-org1:7051" \
  cli-org1 \
  peer channel join -b /tmp/hyperledger/org1/peer1/assets/${CHANNEL_NAME}.block --tls

docker exec \
  -e "CORE_PEER_MSPCONFIGPATH=/tmp/hyperledger/org1/admin/msp" \
  -e "CORE_PEER_ADDRESS=peer2-org1:7051" \
  cli-org1 \
  peer channel join -b /tmp/hyperledger/org1/peer1/assets/${CHANNEL_NAME}.block --tls

docker exec \
  -e "CORE_PEER_MSPCONFIGPATH=/tmp/hyperledger/org1/admin/msp" \
  -e "CORE_PEER_ADDRESS=peer1-org1:7051" \
  cli-org1 \
  peer channel update -c ${CHANNEL_NAME} -f /tmp/hyperledger/org1/peer1/assets/org1Anchors.tx -o ${ORDERER} \
  --cafile ${PEER0_ORG1_CA} --tls

## Org2
cp /tmp/hyperledger/org1/peer1/assets/${CHANNEL_NAME}.block /tmp/hyperledger/org2/peer1/assets/${CHANNEL_NAME}.block
cp /tmp/hyperledger/org0/orderer1/org2Anchors.tx /tmp/hyperledger/org2/peer1/assets/org2Anchors.tx

docker exec \
  -e "CORE_PEER_MSPCONFIGPATH=/tmp/hyperledger/org2/admin/msp" \
  -e "CORE_PEER_ADDRESS=peer1-org2:7051" \
  cli-org2 \
  peer channel join -b /tmp/hyperledger/org2/peer1/assets/${CHANNEL_NAME}.block --tls

docker exec \
  -e "CORE_PEER_MSPCONFIGPATH=/tmp/hyperledger/org2/admin/msp" \
  -e "CORE_PEER_ADDRESS=peer2-org2:7051" \
  cli-org2 \
  peer channel join -b /tmp/hyperledger/org2/peer1/assets/${CHANNEL_NAME}.block --tls

docker exec \
  -e "CORE_PEER_MSPCONFIGPATH=/tmp/hyperledger/org2/admin/msp" \
  -e "CORE_PEER_ADDRESS=peer1-org2:7051" \
  cli-org2 \
  peer channel update -c ${CHANNEL_NAME} -f /tmp/hyperledger/org2/peer1/assets/org2Anchors.tx -o ${ORDERER} \
  --cafile ${PEER0_ORG2_CA} --tls

# Install and Instantiate Chaincode
## Package chaincode
docker exec \
  -e "CORE_PEER_MSPCONFIGPATH=/tmp/hyperledger/org1/admin/msp" \
  -e "CORE_PEER_ADDRESS=peer1-org1:7051" \
  cli-org1 \
  peer lifecycle chaincode package ${CHAINCODE_NAME}.tar.gz --path /opt/gopath/src/github.com/chaincode/${CHAINCODE_NAME} --lang node \
  --label ${CHAINCODE_NAME}_${CHAINCODE_VERSION} --tls

docker exec \
  -e "CORE_PEER_MSPCONFIGPATH=/tmp/hyperledger/org2/admin/msp" \
  -e "CORE_PEER_ADDRESS=peer1-org2:7051" \
  cli-org2 \
  peer lifecycle chaincode package ${CHAINCODE_NAME}.tar.gz --path /opt/gopath/src/github.com/chaincode/${CHAINCODE_NAME} --lang node \
  --label ${CHAINCODE_NAME}_${CHAINCODE_VERSION} --tls

## Install chaincode
docker exec \
  -e "CORE_PEER_MSPCONFIGPATH=/tmp/hyperledger/org1/admin/msp" \
  -e "CORE_PEER_ADDRESS=peer1-org1:7051" \
  cli-org1 \
  peer lifecycle chaincode install ${CHAINCODE_NAME}.tar.gz --tls

docker exec \
  -e "CORE_PEER_MSPCONFIGPATH=/tmp/hyperledger/org1/admin/msp" \
  -e "CORE_PEER_ADDRESS=peer2-org1:7051" \
  cli-org1 \
  peer lifecycle chaincode install ${CHAINCODE_NAME}.tar.gz --tls

docker exec \
  -e "CORE_PEER_MSPCONFIGPATH=/tmp/hyperledger/org2/admin/msp" \
  -e "CORE_PEER_ADDRESS=peer1-org2:7051" \
  cli-org2 \
  peer lifecycle chaincode install ${CHAINCODE_NAME}.tar.gz --tls

docker exec \
  -e "CORE_PEER_MSPCONFIGPATH=/tmp/hyperledger/org2/admin/msp" \
  -e "CORE_PEER_ADDRESS=peer2-org2:7051" \
  cli-org2 \
  peer lifecycle chaincode install ${CHAINCODE_NAME}.tar.gz --tls

## Query installed chaincode
sleep ${SLEEP_DURATION}
docker exec \
  -e "CORE_PEER_MSPCONFIGPATH=/tmp/hyperledger/org1/admin/msp" \
  -e "CORE_PEER_ADDRESS=peer1-org1:7051" \
  cli-org1 \
  peer lifecycle chaincode queryinstalled --tls >&log.txt
PACKAGE_ID=$(sed -n '/Package/{s/^Package ID: //; s/, Label:.*$//; p;}' log.txt)
echo PackageID is ${PACKAGE_ID}

## Approve for Org1
docker exec \
  -e "CORE_PEER_MSPCONFIGPATH=/tmp/hyperledger/org1/admin/msp" \
  -e "CORE_PEER_ADDRESS=peer1-org1:7051" \
  cli-org1 \
  peer lifecycle chaincode approveformyorg --cafile ${PEER0_ORG1_CA} --channelID ${CHANNEL_NAME} --name ${CHAINCODE_NAME} \
  --version ${CHAINCODE_VERSION} --init-required --package-id ${PACKAGE_ID} --sequence ${CHAINCODE_SEQUENCE} --waitForEvent --tls

## Check commit readiness
docker exec \
  -e "CORE_PEER_MSPCONFIGPATH=/tmp/hyperledger/org1/admin/msp" \
  -e "CORE_PEER_ADDRESS=peer1-org1:7051" \
  cli-org1 \
  peer lifecycle chaincode checkcommitreadiness --channelID ${CHANNEL_NAME} --name ${CHAINCODE_NAME} \
  --version ${CHAINCODE_VERSION} --sequence ${CHAINCODE_SEQUENCE} --output json --init-required --tls >&commitreadiness.json

if ! $(jq '.approvals.Org1MSP' commitreadiness.json); then
  exit 1
fi

## Approve for Org2
docker exec \
  -e "CORE_PEER_MSPCONFIGPATH=/tmp/hyperledger/org2/admin/msp" \
  -e "CORE_PEER_ADDRESS=peer1-org2:7051" \
  cli-org2 \
  peer lifecycle chaincode approveformyorg --cafile ${PEER0_ORG2_CA} --channelID ${CHANNEL_NAME} --name ${CHAINCODE_NAME} \
  --version ${CHAINCODE_VERSION} --init-required --package-id ${PACKAGE_ID} --sequence ${CHAINCODE_SEQUENCE} --waitForEvent --tls

## Check commit readiness
docker exec \
  -e "CORE_PEER_MSPCONFIGPATH=/tmp/hyperledger/org2/admin/msp" \
  -e "CORE_PEER_ADDRESS=peer1-org2:7051" \
  cli-org2 \
  peer lifecycle chaincode checkcommitreadiness --channelID ${CHANNEL_NAME} --name ${CHAINCODE_NAME} \
  --version ${CHAINCODE_VERSION} --sequence ${CHAINCODE_SEQUENCE} --output json --init-required --tls >&commitreadiness.json

if ! $(jq '.approvals.Org2MSP' commitreadiness.json); then
  exit 1
fi

## Commit chaincode definition
sleep ${SLEEP_DURATION}
docker exec \
  -e "CORE_PEER_MSPCONFIGPATH=/tmp/hyperledger/org1/admin/msp" \
  -e "CORE_PEER_ADDRESS=peer1-org1:7051" \
  cli-org1 \
  peer lifecycle chaincode commit -o ${ORDERER} --cafile ${PEER0_ORG1_CA} --channelID ${CHANNEL_NAME} --name ${CHAINCODE_NAME} \
  --peerAddresses peer1-org1:7051 --tlsRootCertFiles ${PEER0_ORG1_CA} --peerAddresses peer1-org2:7051 --tlsRootCertFiles ${PEER0_ORG2_CA} \
  --version ${CHAINCODE_VERSION} --sequence ${CHAINCODE_SEQUENCE} --init-required --tls

## Query committed
docker exec \
  -e "CORE_PEER_MSPCONFIGPATH=/tmp/hyperledger/org2/admin/msp" \
  -e "CORE_PEER_ADDRESS=peer1-org2:7051" \
  cli-org2 \
  peer lifecycle chaincode querycommitted --channelID ${CHANNEL_NAME} --name ${CHAINCODE_NAME} --tls

# Invoke and Query Chaincode
## Init chaincode
sleep ${SLEEP_DURATION}
docker exec \
  -e "CORE_PEER_MSPCONFIGPATH=/tmp/hyperledger/org1/admin/msp" \
  -e "CORE_PEER_ADDRESS=peer1-org1:7051" \
  cli-org1 \
  peer chaincode invoke -o ${ORDERER} --cafile ${PEER0_ORG1_CA} --channelID ${CHANNEL_NAME} --name ${CHAINCODE_NAME} \
  --peerAddresses peer1-org1:7051 --tlsRootCertFiles ${PEER0_ORG1_CA} --peerAddresses peer1-org2:7051 --tlsRootCertFiles ${PEER0_ORG2_CA} \
  --isInit -c '{"Args":[]}' --tls

## Query testGet
sleep ${SLEEP_DURATION}
docker exec \
  -e "CORE_PEER_MSPCONFIGPATH=/tmp/hyperledger/org1/admin/msp" \
  -e "CORE_PEER_ADDRESS=peer1-org1:7051" \
  cli-org1 \
  peer chaincode query --channelID ${CHANNEL_NAME} --name ${CHAINCODE_NAME} -c '{"Args":["testGet"]}' --tls

## Invoke chaincode
docker exec \
  -e "CORE_PEER_MSPCONFIGPATH=/tmp/hyperledger/org1/admin/msp" \
  -e "CORE_PEER_ADDRESS=peer1-org1:7051" \
  cli-org1 \
  peer chaincode invoke invoke -o ${ORDERER} --cafile ${PEER0_ORG1_CA} --channelID ${CHANNEL_NAME} --name ${CHAINCODE_NAME} \
  --peerAddresses peer1-org1:7051 --tlsRootCertFiles ${PEER0_ORG1_CA} --peerAddresses peer1-org2:7051 --tlsRootCertFiles ${PEER0_ORG2_CA} \
  -c '{"Args":["addMarks","Alice","68","84","89"]}' --tls

## Query
sleep ${SLEEP_DURATION}
docker exec \
  -e "CORE_PEER_MSPCONFIGPATH=/tmp/hyperledger/org2/admin/msp" \
  -e "CORE_PEER_ADDRESS=peer1-org2:7051" \
  cli-org2 \
  peer chaincode query --channelID ${CHANNEL_NAME} --name ${CHAINCODE_NAME} -c '{"Args":["queryMarks","Alice"]}' --tls

# Hyperledger Fabric 3.0 Network with CA Server

## Overview

- Based on [Fabric CA Operations Guide](https://hyperledger-fabric-ca.readthedocs.io/en/latest/operations_guide.html)
- Using Hyperledger Fabric v3.1.1 and CA v1.5.15
- There are 3 organizations in the network:
  - Org0 (Orderer Org): 4 orderers running SmartBFT
  - Org1: 2 peers using CouchDB
  - Org2: 2 peers using CouchDB
- There are 3 Root CAs (RCAs) for 3 organizations and one TLS CA
- Include Explorer on port 8080
- Tested on MacOS 15.6.1
- UI version and more features at [BlockNest](https://github.com/quanttb/block-nest)

## Prerequisites

The following prerequisites are required to be installed on your system before you can run all-in-one script:

- docker
- docker-compose
- jq

## Execution

```bash
$ ./byfn.sh
```

## Contribution

This is my personal project, but your contributions are welcome and greatly appreciated. Please submit your fixes and new features via a pull request. All pull requests and proposed changes will go through a code review, and once approved, will be merged into the project.

If you like my work, please consider leaving a ⭐ on the repository. Thank you! 🙏

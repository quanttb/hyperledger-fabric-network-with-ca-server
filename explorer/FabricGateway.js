"use strict";
/*
 *SPDX-License-Identifier: Apache-2.0
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.FabricGateway = void 0;
const fabric_network_1 = require("fabric-network");
const fabprotos = __importStar(require("fabric-protos"));
const fabric_common_1 = require("fabric-common");
const concat_1 = __importDefault(require("lodash/concat"));
const path = __importStar(require("path"));
const helper_1 = require("../../../common/helper");
const ExplorerMessage_1 = require("../../../common/ExplorerMessage");
const ExplorerError_1 = require("../../../common/ExplorerError");
/* eslint-disable @typescript-eslint/no-var-requires */
const { BlockDecoder, Client } = require('fabric-common');
const FabricCAServices = require('fabric-ca-client');
/* eslint-enable @typescript-eslint/no-var-requires */
const logger = helper_1.helper.getLogger('FabricGateway');
class FabricGateway {
    /**
     * Creates an instance of FabricGateway.
     * @param {FabricConfig} config
     * @memberof FabricGateway
     */
    constructor(fabricConfig) {
        this.fabricConfig = fabricConfig;
        this.config = this.fabricConfig.getConfig();
        this.gateway = null;
        this.wallet = null;
        this.tlsEnable = false;
        this.defaultChannelName = null;
        this.gateway = new fabric_network_1.Gateway();
        this.fabricCaEnabled = false;
        this.client = null;
        this.clientTlsIdentity = null;
        this.FSWALLET = null;
        this.enableAuthentication = false;
        this.asLocalhost = false;
        this.ds = null;
        this.dsTargets = [];
    }
    initialize() {
        return __awaiter(this, void 0, void 0, function* () {
            this.fabricCaEnabled = this.fabricConfig.isFabricCaEnabled();
            this.tlsEnable = this.fabricConfig.getTls();
            this.enableAuthentication = this.fabricConfig.getEnableAuthentication();
            this.FSWALLET = 'wallet/' + this.fabricConfig.getNetworkId();
            const explorerAdminId = this.fabricConfig.getAdminUser();
            if (!explorerAdminId) {
                logger.error('Failed to get admin ID from configuration file');
                throw new ExplorerError_1.ExplorerError(ExplorerMessage_1.explorerError.ERROR_1010);
            }
            const info = `Loading configuration  ${this.config}`;
            logger.debug(info.toUpperCase());
            this.defaultChannelName = this.fabricConfig.getDefaultChannel();
            try {
                // Create a new file system based wallet for managing identities.
                const walletPath = path.join(process.cwd(), this.FSWALLET);
                this.wallet = yield fabric_network_1.Wallets.newFileSystemWallet(walletPath);
                // Check to see if we've already enrolled the admin user.
                const identity = yield this.wallet.get(explorerAdminId);
                if (identity) {
                    logger.debug(`An identity for the admin user: ${explorerAdminId} already exists in the wallet`);
                }
                else if (this.fabricCaEnabled) {
                    logger.info('CA enabled');
                    yield this.enrollCaIdentity(explorerAdminId, this.fabricConfig.getAdminPassword());
                }
                else {
                    /*
                     * Identity credentials to be stored in the wallet
                     * Look for signedCert in first-network-connection.json
                     */
                    const signedCertPem = this.fabricConfig.getOrgSignedCertPem();
                    const adminPrivateKeyPem = this.fabricConfig.getOrgAdminPrivateKeyPem();
                    yield this.enrollUserIdentity(explorerAdminId, signedCertPem, adminPrivateKeyPem);
                    logger.info('1');
                }
                if (!this.tlsEnable) {
                    Client.setConfigSetting('discovery-protocol', 'grpc');
                }
                else {
                    Client.setConfigSetting('discovery-protocol', 'grpcs');
                }
                logger.info('2');
                // Set connection options; identity and wallet
                this.asLocalhost =
                    String(Client.getConfigSetting('discovery-as-localhost', 'true')) ===
                        'true';
                logger.info('3');
                const connectionOptions = {
                    identity: explorerAdminId,
                    wallet: this.wallet,
                    discovery: {
                        enabled: true,
                        asLocalhost: this.asLocalhost
                    },
                    clientTlsIdentity: ''
                };
                logger.info('4', connectionOptions);
                const mTlsIdLabel = this.fabricConfig.getClientTlsIdentity();
                if (mTlsIdLabel) {
                    logger.info('client TLS enabled');
                    this.clientTlsIdentity = yield this.wallet.get(mTlsIdLabel);
                    if (this.clientTlsIdentity !== undefined) {
                        connectionOptions.clientTlsIdentity = mTlsIdLabel;
                    }
                    else {
                        throw new ExplorerError_1.ExplorerError(`Not found Identity ${mTlsIdLabel} in your wallet`);
                    }
                }
                logger.info('5', this.config);
                // Connect to gateway
                yield this.gateway.connect(this.config, connectionOptions);
            }
            catch (error) {
                logger.error(`${ExplorerMessage_1.explorerError.ERROR_1010}: ${JSON.stringify(error, null, 2)}`);
                throw new ExplorerError_1.ExplorerError(ExplorerMessage_1.explorerError.ERROR_1010);
            }
        });
    }
    getEnableAuthentication() {
        return this.enableAuthentication;
    }
    getDiscoveryProtocol() {
        return Client.getConfigSetting('discovery-protocol');
    }
    getDefaultMspId() {
        return this.fabricConfig.getMspId();
    }
    getTls() {
        return this.tlsEnable;
    }
    getConfig() {
        return this.config;
    }
    /**
     * @private method
     *
     */
    enrollUserIdentity(userName, signedCertPem, adminPrivateKeyPem) {
        return __awaiter(this, void 0, void 0, function* () {
            const identity = {
                credentials: {
                    certificate: signedCertPem,
                    privateKey: adminPrivateKeyPem
                },
                mspId: this.fabricConfig.getMspId(),
                type: 'X.509'
            };
            logger.info('enrollUserIdentity: userName :', userName);
            yield this.wallet.put(userName, identity);
            return identity;
        });
    }
    /**
     * @private method
     *
     */
    enrollCaIdentity(id, secret) {
        return __awaiter(this, void 0, void 0, function* () {
            if (!this.fabricCaEnabled) {
                logger.error('CA server is not configured');
                return null;
            }
            try {
                const caName = this.config.organizations[this.fabricConfig.getOrganization()]
                    .certificateAuthorities[0];
                const ca = new FabricCAServices(this.config.certificateAuthorities[caName].url, {
                    trustedRoots: this.fabricConfig.getTlsCACertsPem(caName),
                    verify: false
                });
                const enrollment = yield ca.enroll({
                    enrollmentID: this.fabricConfig.getCaAdminUser(),
                    enrollmentSecret: this.fabricConfig.getCaAdminPassword()
                });
                logger.info('>>>>>>>>>>>>>>>>>>>>>>>>> enrollment : ca admin');
                const identity = {
                    credentials: {
                        certificate: enrollment.certificate,
                        privateKey: enrollment.key.toBytes()
                    },
                    mspId: this.fabricConfig.getMspId(),
                    type: 'X.509'
                };
                // Import identity wallet
                yield this.wallet.put(this.fabricConfig.getCaAdminUser(), identity);
                const adminUser = yield this.getUserContext(this.fabricConfig.getCaAdminUser());
                yield ca.register({
                    affiliation: this.fabricConfig.getAdminAffiliation(),
                    enrollmentID: id,
                    enrollmentSecret: secret,
                    role: 'admin'
                }, adminUser);
                const enrollmentBEAdmin = yield ca.enroll({
                    enrollmentID: id,
                    enrollmentSecret: secret
                });
                logger.info('>>>>>>>>>>>>>>>>>>>>>>>>> registration & enrollment : BE admin');
                const identityBEAdmin = {
                    credentials: {
                        certificate: enrollmentBEAdmin.certificate,
                        privateKey: enrollmentBEAdmin.key.toBytes()
                    },
                    mspId: this.fabricConfig.getMspId(),
                    type: 'X.509'
                };
                yield this.wallet.put(id, identityBEAdmin);
                logger.debug('Successfully get user enrolled and imported to wallet, ', id);
                return identityBEAdmin;
            }
            catch (error) {
                // TODO decide how to proceed if error
                logger.error('Error instantiating FabricCAServices ', error);
                return null;
            }
        });
    }
    getUserContext(user) {
        return __awaiter(this, void 0, void 0, function* () {
            const identity = yield this.wallet.get(user);
            if (!identity) {
                logger.error('Not exist user :', user);
                return null;
            }
            const provider = this.wallet.getProviderRegistry().getProvider(identity.type);
            const userContext = yield provider.getUserContext(identity, user);
            return userContext;
        });
    }
    getIdentityInfo(label) {
        return __awaiter(this, void 0, void 0, function* () {
            let identityInfo;
            logger.info('Searching for an identity with label: ', label);
            try {
                const list = yield this.wallet.list();
                identityInfo = list.filter(id => {
                    return id.label === label;
                });
            }
            catch (error) {
                logger.error(error);
            }
            return identityInfo;
        });
    }
    queryChannels() {
        return __awaiter(this, void 0, void 0, function* () {
            const network = yield this.gateway.getNetwork(this.defaultChannelName);
            // Get the contract from the network.
            const contract = network.getContract('cscc');
            const result = yield contract.evaluateTransaction('GetChannels');
            const resultJson = fabprotos.protos.ChannelQueryResponse.decode(result);
            logger.debug('queryChannels', resultJson);
            return resultJson;
        });
    }
    queryBlock(channelName, blockNum) {
        return __awaiter(this, void 0, void 0, function* () {
            try {
                const network = yield this.gateway.getNetwork(this.defaultChannelName);
                // Get the contract from the network.
                const contract = network.getContract('qscc');
                const resultByte = yield contract.evaluateTransaction('GetBlockByNumber', channelName, String(blockNum));
                const resultJson = BlockDecoder.decode(resultByte);
                logger.debug('queryBlock', resultJson);
                return resultJson;
            }
            catch (error) {
                logger.error(`Failed to get block ${blockNum} from channel ${channelName} : `, error);
                return null;
            }
        });
    }
    queryInstantiatedChaincodes(channelName) {
        return __awaiter(this, void 0, void 0, function* () {
            logger.info('queryInstantiatedChaincodes', channelName);
            const network = yield this.gateway.getNetwork(channelName);
            let resultJson = { chaincodes: [], toJSON: null };
            let contract = network.getContract('_lifecycle');
            let result = yield contract.evaluateTransaction('QueryChaincodeDefinitions', '');
            const decodedReult = fabprotos.lifecycle.QueryChaincodeDefinitionsResult.decode(result);
            for (const cc of decodedReult.chaincode_definitions) {
                resultJson.chaincodes = (0, concat_1.default)(resultJson.chaincodes, {
                    name: cc.name,
                    version: cc.version
                });
            }
            logger.debug('queryInstantiatedChaincodes', resultJson);
            return resultJson;
        });
    }
    queryChainInfo(channelName) {
        return __awaiter(this, void 0, void 0, function* () {
            try {
                const network = yield this.gateway.getNetwork(this.defaultChannelName);
                // Get the contract from the network.
                const contract = network.getContract('qscc');
                const resultByte = yield contract.evaluateTransaction('GetChainInfo', channelName);
                const resultJson = fabprotos.common.BlockchainInfo.decode(resultByte);
                logger.debug('queryChainInfo', resultJson);
                return resultJson;
            }
            catch (error) {
                logger.error(`Failed to get chain info from channel ${channelName} : `, error);
                return null;
            }
        });
    }
    setupDiscoveryRequest(channelName) {
        return __awaiter(this, void 0, void 0, function* () {
            try {
                const network = yield this.gateway.getNetwork(channelName);
                const channel = network.getChannel();
                this.ds = new fabric_common_1.DiscoveryService('be discovery service', channel);
                const idx = this.gateway.identityContext;
                // do the three steps
                this.ds.build(idx);
                this.ds.sign(idx);
            }
            catch (error) {
                logger.error('Failed to set up discovery service for channel', error);
                this.ds = null;
            }
        });
    }
    getDiscoveryServiceTarget() {
        return __awaiter(this, void 0, void 0, function* () {
            const client = new Client('discovery client');
            if (this.clientTlsIdentity) {
                logger.info('client TLS enabled');
                client.setTlsClientCertAndKey(this.clientTlsIdentity.credentials.certificate, this.clientTlsIdentity.credentials.privateKey);
            }
            else {
                client.setTlsClientCertAndKey();
            }
            const targets = [];
            const mspID = this.config.client.organization;
            for (const peer of this.config.organizations[mspID].peers) {
                const discoverer = new fabric_common_1.Discoverer(`be discoverer ${peer}`, client, mspID);
                const url = this.config.peers[peer].url;
                const pem = this.fabricConfig.getPeerTlsCACertsPem(peer);
                let grpcOpt = {};
                if ('grpcOptions' in this.config.peers[peer]) {
                    grpcOpt = this.config.peers[peer].grpcOptions;
                }
                const peer_endpoint = client.newEndpoint(Object.assign(grpcOpt, {
                    url: url,
                    pem: pem
                }));
                yield discoverer.connect(peer_endpoint);
                targets.push(discoverer);
            }
            return targets;
        });
    }
    sendDiscoveryRequest() {
        return __awaiter(this, void 0, void 0, function* () {
            let result;
            try {
                logger.info('Sending discovery request...');
                yield this.ds
                    .send({
                    asLocalhost: this.asLocalhost,
                    requestTimeout: 5000,
                    refreshAge: 15000,
                    targets: this.dsTargets
                })
                    .then(() => {
                    logger.info('Succeeded to send discovery request');
                })
                    .catch(error => {
                    if (error) {
                        logger.warn('Failed to send discovery request for channel', error);
                        this.ds.close();
                    }
                });
                result = yield this.ds.getDiscoveryResults(true);
            }
            catch (error) {
                logger.warn('Failed to send discovery request for channel', error);
                if (this.ds) {
                    this.ds.close();
                    this.ds = null;
                }
                result = null;
            }
            return result;
        });
    }
    getDiscoveryResult(channelName) {
        return __awaiter(this, void 0, void 0, function* () {
            yield this.setupDiscoveryRequest(channelName);
            if (!this.dsTargets.length) {
                this.dsTargets = yield this.getDiscoveryServiceTarget();
            }
            if (this.ds && this.dsTargets.length) {
                const result = yield this.sendDiscoveryRequest();
                return result;
            }
            return null;
        });
    }
    getActiveOrderersList(channel_name) {
        return __awaiter(this, void 0, void 0, function* () {
            const network = yield this.gateway.getNetwork(channel_name);
            let orderers = [];
            try {
                for (let [orderer, ordererMetadata] of network.discoveryService.channel.committers) {
                    let ordererAtrributes = {
                        name: orderer,
                        connected: ordererMetadata.connected
                    };
                    orderers.push(ordererAtrributes);
                }
                return orderers;
            }
            catch (error) {
                logger.error(`Failed to get orderers list : `, error);
                return orderers;
            }
        });
    }
    queryTransaction(channelName, txnId) {
        return __awaiter(this, void 0, void 0, function* () {
            try {
                const network = yield this.gateway.getNetwork(this.defaultChannelName);
                // Get the contract from the network.
                const contract = network.getContract('qscc');
                const resultByte = yield contract.evaluateTransaction('GetTransactionByID', channelName, txnId);
                const resultJson = BlockDecoder.decodeTransaction(resultByte);
                logger.debug('queryTransaction', resultJson);
                return resultJson;
            }
            catch (error) {
                logger.error(`Failed to get transaction ${txnId} from channel ${channelName} : `, error);
                return null;
            }
        });
    }
    queryContractMetadata(channel_name, contract_name) {
        return __awaiter(this, void 0, void 0, function* () {
            const network = yield this.gateway.getNetwork(channel_name);
            // Get the contract from the network.        
            const contract = network.getContract(contract_name);
            // Get the contract metadata from the network.
            const result = yield contract.evaluateTransaction('org.hyperledger.fabric:GetMetadata');
            const metadata = JSON.parse(result.toString('utf8'));
            logger.debug('queryContractMetadata', metadata);
            return metadata;
        });
    }
}
exports.FabricGateway = FabricGateway;
//# sourceMappingURL=FabricGateway.js.map
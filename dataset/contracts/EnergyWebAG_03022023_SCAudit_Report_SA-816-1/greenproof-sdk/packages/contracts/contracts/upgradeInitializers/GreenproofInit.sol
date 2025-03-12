// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IVoting} from "../interfaces/IVoting.sol";
import {IReward} from "../interfaces/IReward.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {IMetaToken} from "../interfaces/IMetaToken.sol";
import {IProofIssuer} from "../interfaces/IProofIssuer.sol";
import {IProofManager} from "../interfaces/IProofManager.sol";
import {IClaimManager} from "../interfaces/IClaimManager.sol";
import {ERC165BaseStorage} from "@solidstate/contracts/introspection/ERC165/base/ERC165BaseStorage.sol";
import {LibReward} from "../libraries/LibReward.sol";
import {LibIssuer} from "../libraries/LibIssuer.sol";
import {LibVoting} from "../libraries/LibVoting.sol";
import {LibClaimManager} from "../libraries/LibClaimManager.sol";
import {MetaToken} from "../dependencies/MetaToken.sol";
import {LibMetaToken} from "../libraries/LibMetaToken.sol";

/**
 * @title GreenproofInit - Initialization contract
 * @author EnergyWeb Foundation
 * @notice This contract is the initialization contract for the Greenproof smart contract.
 * @dev The contract sets the supported interfaces for the Greenproof contract and allows for the initialization of state variables.
 * @dev It is expected that this contract is customized if you want to deploy your greenProof diamond with data from a deployment script.
 * @dev Use the init function to initialize state variables of your proxy.
 * @dev Add parameters to the init funciton if you need to.
 */
contract GreenproofInit {
    /**
     * @dev Using the ERC165Storage library for the ERC165Storage.Layout struct
     */
    using ERC165BaseStorage for ERC165BaseStorage.Layout;

    /**
     * @notice Initialization function for setting the supported interfaces and initializing state variables.
     * @dev This function is called during contract deployment or upgrades to accordingly setinterfaces
     * @dev You can add parameters to this function in order to pass in data to set your own state variables.
     * @param proxyConfig Diamond configuration parameters
     */
    function init(LibDiamond.DiamondConfig memory proxyConfig) external {
        // verify that the configuration parameters are valid
        LibDiamond.checkConfig(proxyConfig);

        /**
         * @dev Setting the supported interfaces for the Greenproof contract.
         */
        ERC165BaseStorage.Layout storage erc165 = ERC165BaseStorage.layout();
        erc165.supportedInterfaces[type(IVoting).interfaceId] = true;
        erc165.supportedInterfaces[type(IReward).interfaceId] = true;
        erc165.supportedInterfaces[type(IMetaToken).interfaceId] = true;
        erc165.supportedInterfaces[type(IProofIssuer).interfaceId] = true;
        erc165.supportedInterfaces[type(IProofManager).interfaceId] = true;
        erc165.supportedInterfaces[type(IClaimManager).interfaceId] = true;

        // add your own state variables
        LibClaimManager.init(proxyConfig.rolesConfig);
        LibIssuer.getStorage().name = proxyConfig.certificateName;
        LibIssuer.getStorage().symbol = proxyConfig.certificateSymbol;
        LibIssuer.init(proxyConfig.votingConfig.revocablePeriod, proxyConfig.batchConfig);
        LibVoting.init(proxyConfig.votingConfig.votingTimeLimit, proxyConfig.votingConfig.majorityPercentage);
        LibReward.initRewards(proxyConfig.votingConfig.rewardAmount, proxyConfig.votingConfig.rewardsEnabled);

        if (proxyConfig.isMetaCertificateEnabled) {
            // Deployment of an autonomous contract - the meta token
            // In order to allow meta-certificate issuance only from the GreenProof system, the main proxy contract is set as the admin of the meta token
            MetaToken metaToken = new MetaToken(address(this), proxyConfig.metaCertificateName, proxyConfig.metaCertificateSymbol);
            LibMetaToken.getStorage().metaTokenAddress = address(metaToken);
            LibMetaToken.getStorage().isMetaCertificateEnabled = true;
        }

        // EIP-2535 specifies that the `diamondCut` function takes two optional
        // arguments: address _init and bytes calldata _calldata
        // These arguments are used to execute an arbitrary function using delegatecall
        // in order to set state variables in the diamond during deployment or an upgrade
        // More info here: https://eips.ethereum.org/EIPS/eip-2535#diamond-interface
    }
}

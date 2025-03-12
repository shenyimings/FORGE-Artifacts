// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {LibReward} from "../libraries/LibReward.sol";
import {LibIssuer} from "../libraries/LibIssuer.sol";
import {LibVoting} from "../libraries/LibVoting.sol";
import {LibClaimManager} from "../libraries/LibClaimManager.sol";
import {AddressUtils} from "@solidstate/contracts/utils/AddressUtils.sol";
import {OwnableStorage} from "@solidstate/contracts/access/ownable/OwnableStorage.sol";

library LibDiamond {
    using AddressUtils for address;

    // Define a struct called DiamondConfig which stores some configuration parameters for a diamond contract
    struct DiamondConfig {
        bool isMetaCertificateEnabled; // A boolean flag indicating whether the MetaCertificate feature is enabled or not
        string certificateName; // Name of the certificate
        string certificateSymbol; // Symbol of the certificate
        string metaCertificateName; // Name of the metaCertificate
        string metaCertificateSymbol; // Symbol of the metaCertificate
        LibVoting.VotingConfig votingConfig; // Voting configuration
        LibIssuer.BatchConfig batchConfig; // Batching configuration
        LibClaimManager.RolesConfig rolesConfig; // DID-based roles configuration
    }

    /**
     * @dev Error: Thrown when an error occurs at proxy level
     */
    error ProxyError(string errorMsg);

    /**
     * @notice redirectFacet - redirects the call to the facet specified by the implementation address
     * @param implementation address of the facet to be called
     * @dev reverts if the implementation address is not a contract address
     * @dev reverts if the call to the facet fails
     */
    function redirectToFacet(address implementation) internal {
        // Check if the implementation address is a contract address
        checkIsContract(implementation);

        // The below assembly code executes external function from facet using delegatecall and return any value.
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // copy the data payload of the transaction, i.e the function selector and any arguments
            calldatacopy(0, 0, calldatasize())
            // delegateCall the copied data payload to execute the function and arguments on the implementation facet
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
            // get any return value from the delegateCall and return it to the caller
            returndatacopy(0, 0, returndatasize())
            // return any return value or error back to the caller
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @notice checkIsContract - checks if the implementation address is a contract address
     * @param implementation address of the implementation contract
     * @dev reverts if the implementation address is not a contract address
     */
    function checkIsContract(address implementation) internal view {
        // If the implementation is a contract, it will have code at its address
        if (!implementation.isContract()) {
            revert ProxyError("implementation must be contract");
        }
    }

    /**
     * @notice checkConfig - checks the validity of the diamond configuration
     * @param proxyConfig DiamondConfig struct containing the configuration parameters
     * @dev reverts if the reward amount is 0
     * @dev reverts if the claimManager address is the zero address
     * @dev reverts if the claimsRevocationRegistry address is the zero address
     * @dev reverts if the revocable period is 0
     * @dev reverts if the majority percentage is greater than 100
     */
    function checkConfig(DiamondConfig memory proxyConfig) internal pure {
        if (proxyConfig.votingConfig.rewardAmount == 0) {
            revert ProxyError("init: Null reward amount");
        }

        if (proxyConfig.rolesConfig.claimManagerAddress == address(0)) {
            revert ProxyError("init: Invalid claimManager");
        }

        if (proxyConfig.rolesConfig.claimsRevocationRegistry == address(0)) {
            revert ProxyError("init: Invalid claimsRevocationRegistry");
        }

        if (proxyConfig.votingConfig.revocablePeriod == 0) {
            revert ProxyError("init: Invalid revocable period");
        }

        if (proxyConfig.votingConfig.majorityPercentage > 100) {
            revert ProxyError("init: Majority percentage must be between 0 and 100");
        }
    }
}

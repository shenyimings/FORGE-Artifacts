// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

// This contract is test-only and will not be deployed
import "src/OrigamiGovernanceToken.sol";

/// @custom:security-contact contract-security@joinorigami.com
contract OrigamiGovernanceTokenTestVersion is OrigamiGovernanceToken {
    function isFromUpgrade() public pure returns (bool) {
        return true;
    }
}

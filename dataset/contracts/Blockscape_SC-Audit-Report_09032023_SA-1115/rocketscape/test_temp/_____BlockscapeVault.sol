// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import "./BlockscapeAccess.sol";
import "./BlockscapeShared.sol";

/// @dev for a token the vault can be set only once otherwise revert

// TODO: add all natspec
abstract contract BlockscapeVault is BlockscapeAccess, BlockscapeShared {
    /**
        @notice state of the Validator Vault
        @dev is `false` when validator is currently onboarding, will be reopened, as soon as 
        the backend controller withdraws the ETH batch & stakes it
    */
    
    

   
}

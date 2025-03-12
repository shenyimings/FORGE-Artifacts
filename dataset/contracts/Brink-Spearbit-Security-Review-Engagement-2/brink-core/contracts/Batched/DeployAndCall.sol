// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.10;
pragma abicoder v1;

import "../Account/AccountFactory.sol";

/// @title DeployAndCall
/// @notice This contract contains a function to batch account deploy and call into one transaction
contract DeployAndCall {
  /// @dev The AccountFactory to use for account deployments
  AccountFactory constant ACCOUNT_FACTORY = AccountFactory(0x0B71C16a71eB1aF834e78678529A6e7003f73C5c);

  /// @dev Deploys an account for the given owner and executes callData on the account
  /// @param owner Address of the account owner
  /// @param callData The call to execute on the account after deployment
  function deployAndCall(address owner, bytes memory callData) external payable {
    address account = ACCOUNT_FACTORY.deployAccount(owner);

    if (callData.length > 0) {
      assembly {
        let result := call(gas(), account, callvalue(), add(callData, 0x20), mload(callData), 0, 0)
        returndatacopy(0, 0, returndatasize())
        switch result
        case 0 {
          revert(0, returndatasize())
        }
        default {
          return(0, returndatasize())
        }
      }
    }
  }
}

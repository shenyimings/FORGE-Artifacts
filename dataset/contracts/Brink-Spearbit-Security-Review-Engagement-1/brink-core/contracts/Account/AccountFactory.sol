// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.10;
pragma abicoder v1;

/// @title Brink account factory
/// @notice This is a factory contract used for deployment of Brink proxy accounts
contract AccountFactory {
  /// @dev Salt used for salted deployment of Proxy accounts
  bytes32 constant SALT = 0x841eb53dae7d7c32f92a7e2a07956fb3b9b1532166bc47aa8f091f49bcaa9ff5;

  /// @dev Deploys a Proxy account for the given owner
  /// @param owner Owner of the Proxy account
  /// @return account Address of the deployed Proxy account
  function deployAccount(address owner) external returns (address account) {
    // replace OWNER constant slot in Proxy.sol bytecode with `owner` to generate the initCode for the proxy
    bytes memory initCode = abi.encodePacked(
      hex'6080604052348015600f57600080fd5b5060678061001e6000396000f3fe60806040523660235773',
      owner,
      hex'60405152005b3660008037600080366000732da2f7444ba1d9aa3a66ea47c1a51f5019b753ea5af43d6000803e8080156055573d6000f35b3d6000fdfea164736f6c634300080a000a'
    );
    assembly {
      account := create2(0, add(initCode, 0x20), mload(initCode), SALT)
    }
  }
}

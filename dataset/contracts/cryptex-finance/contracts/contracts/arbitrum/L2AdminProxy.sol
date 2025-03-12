// SPDX-License-Identifier: MIT
pragma solidity 0.7.5;

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/ProxyAdmin.sol";
import {AddressAliasHelper} from "./AddressAliasHelper.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract L2AdminProxy is ProxyAdmin {
  address private _owner;

  /**
   * @dev Initializes the contract setting the deployer as the initial owner.
   */
  constructor(address owner) {
    _owner = owner;
    emit OwnershipTransferred(address(0), owner);
  }

  /// @dev override admin so so that it returns the address offset by arbitrum's sequencer
  /// @inheritdoc Ownable
  function owner() public view override returns (address) {
    return AddressAliasHelper.applyL1ToL2Alias(_owner);
  }

  /// @notice renounceOwnership has been disabled so that the contract is never left without a onwer
  /// @inheritdoc Ownable
  function renounceOwnership() public override onlyOwner {
    revert("function disabled");
  }

  /// @inheritdoc Ownable
  function transferOwnership(address newOwner) public override onlyOwner {
    require(newOwner != address(0), "Ownable: new owner is the zero address");
    emit OwnershipTransferred(_owner, newOwner);
    _owner = newOwner;
  }
}

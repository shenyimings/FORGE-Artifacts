// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import "../dependencies/interfaces/IStore.sol";

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

abstract contract StoreBase is IStore, PausableUpgradeable, OwnableUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  mapping(bytes32 => int256) public intStorage;
  mapping(bytes32 => uint256) public uintStorage;
  mapping(bytes32 => uint256[]) public uintsStorage;
  mapping(bytes32 => address) public addressStorage;
  mapping(bytes32 => mapping(address => bool)) public addressBooleanStorage;
  mapping(bytes32 => string) public stringStorage;
  mapping(bytes32 => bytes) public bytesStorage;
  mapping(bytes32 => bytes32) public bytes32Storage;
  mapping(bytes32 => bool) public boolStorage;
  mapping(bytes32 => address[]) public addressArrayStorage;
  mapping(bytes32 => mapping(address => uint256)) public addressArrayPositionMap;
  mapping(bytes32 => bytes32[]) public bytes32ArrayStorage;
  mapping(bytes32 => mapping(bytes32 => uint256)) public bytes32ArrayPositionMap;

  mapping(address => bool) public pausers;

  bytes32 public constant _NS_MEMBERS = "ns:store:members";

  /**
   *
   * @dev Accepts a list of accounts and their respective statuses for addition or removal as pausers.
   *
   * @custom:suppress-reentrancy Risk tolerable. Can only be called by the owner.
   * @custom:suppress-address-trust-issue Risk tolerable.
   */
  function setPausers(address[] calldata accounts, bool[] calldata statuses) external override onlyOwner whenNotPaused {
    require(accounts.length > 0, "No pauser specified");
    require(accounts.length == statuses.length, "Invalid args");

    for (uint256 i = 0; i < accounts.length; i++) {
      pausers[accounts[i]] = statuses[i];
    }

    emit PausersSet(msg.sender, accounts, statuses);
  }

  /**
   * @dev Recover all Ether held by the contract.
   * @custom:suppress-reentrancy Risk tolerable. Can only be called by the owner.
   * @custom:suppress-pausable Risk tolerable. Can only be called by the owner.
   */
  function recoverEther(address sendTo) external onlyOwner {
    // slither-disable-next-line low-level-calls
    (bool success,) = payable(sendTo).call{value: address(this).balance}(""); // solhint-disable-line avoid-low-level-calls
    require(success, "Recipient may have reverted");
  }

  /**
   * @dev Recover all IERC-20 compatible tokens sent to this address.
   *
   * @custom:suppress-reentrancy Risk tolerable. Can only be called by the owner.
   * @custom:suppress-pausable Risk tolerable. Can only be called by the owner.
   * @custom:suppress-malicious-erc Risk tolerable. Although the token can't be trusted, the owner has to check the token code manually.
   * @custom:suppress-address-trust-issue Risk tolerable. Although the token can't be trusted, the owner has to check the token code manually.
   *
   * @param token IERC-20 The address of the token contract
   */
  function recoverToken(address token, address sendTo) external onlyOwner {
    IERC20Upgradeable erc20 = IERC20Upgradeable(token);

    uint256 balance = erc20.balanceOf(address(this));

    if (balance > 0) {
      // slither-disable-next-line unchecked-transfer
      erc20.safeTransfer(sendTo, balance);
    }
  }

  /**
   * @dev Pauses the store
   *
   * @custom:suppress-reentrancy Risk tolerable. Can only be called by a pauser.
   *
   */
  function pause() external {
    require(pausers[msg.sender], "Forbidden");
    _pause();
  }

  /**
   * @dev Unpauses the store
   *
   * @custom:suppress-reentrancy Risk tolerable. Can only be called by the owner.
   *
   */
  function unpause() external onlyOwner {
    _unpause();
  }

  function isMember(address member) public view returns (bool) {
    return boolStorage[keccak256(abi.encodePacked(_NS_MEMBERS, member))];
  }

  function _throwIfPaused() internal view {
    require(paused() == false, "Pausable: paused");
  }

  function _throwIfSenderNotMember() internal view {
    require(isMember(msg.sender), "Forbidden");
  }
}

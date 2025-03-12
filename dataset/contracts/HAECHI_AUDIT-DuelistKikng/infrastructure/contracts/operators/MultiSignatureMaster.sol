// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4 <0.9.0;
pragma abicoder v2;

import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/proxy/Clones.sol';
import '../libraries/Verifier.sol';
import '../libraries/Bytes.sol';
import '../libraries/Permissioned.sol';
import '../interfaces/IMultiSignature.sol';

/**
 * Orochi Multi Signature Master
 * Name: N/A
 * Domain: N/A
 */
contract MultiSignatureMaster is Permissioned {
  // Allow master to clone other multi signature contract
  using Clones for address;

  // Permissionw
  uint256 internal constant PERMISSION_TRANSFER = 1;
  uint256 internal constant PERMISSION_OPERATOR = 2;

  // Wallet implementation
  address private _implementation;

  // Price in native token
  uint256 private _walletFee;

  // Create new wallet
  event CreateNewWallet(address indexed creator, uint256 indexed salt, int256 indexed threshold, int256 thresholdDrag);

  // Upgrade implementation
  event UpgradeImplementation(address indexed oldImplementation, address indexed upgradeImplementation);

  // Request small fee to create new wallet, we prevent people spaming wallet
  modifier requireFee() {
    require(msg.value >= _walletFee, 'M: It need native token to trigger this method');
    _;
  }

  // This contract able to receive fund
  receive() external payable {}

  // Pass parameters to parent contract
  constructor(
    address[] memory users_,
    uint256[] memory roles_,
    address implementation_,
    uint256 fee_
  ) {
    _implementation = implementation_;
    _walletFee = fee_;
    _init(users_, roles_);
    emit UpgradeImplementation(address(0), implementation_);
  }

  /*******************************************************
   * User section
   ********************************************************/
  // Transfer existing role to a new user
  function transferRole(address newUser) external onlyUser {
    // New user will be activated after 1 days 1 hours
    _transferRole(newUser, 1 days + 1 hours);
  }

  /*******************************************************
   * Transfer section
   ********************************************************/
  // Withdraw all of the balance to the fee collector
  function withdraw(address payable receiver) external onlyAllow(PERMISSION_TRANSFER) {
    receiver.transfer(address(this).balance);
  }

  /*******************************************************
   * Operator section
   ********************************************************/
  // Upgrade new implementation
  function upgradeImplementation(address newImplementation) external onlyAllow(PERMISSION_OPERATOR) {
    emit UpgradeImplementation(_implementation, newImplementation);
    _implementation = newImplementation;
  }

  /*******************************************************
   * Public section
   ********************************************************/
  // Create new multisig wallet
  function createWallet(
    uint96 salt,
    address[] memory users_,
    uint256[] memory roles_,
    int256 threshold_,
    int256 thresholdDrag_
  ) external payable requireFee returns (address) {
    address newWallet = _implementation.cloneDeterministic(_getUniqueSalt(msg.sender, salt));
    emit CreateNewWallet(msg.sender, salt, threshold_, thresholdDrag_);
    require(
      IMultiSignature(newWallet).init(users_, roles_, threshold_, thresholdDrag_),
      'M: Can not init multi-sig wallet'
    );
    return newWallet;
  }

  /*******************************************************
   * Private section
   ********************************************************/
  function _getUniqueSalt(address creatorAddress, uint96 salt) private pure returns (bytes32) {
    bytes32 packedSalt;
    assembly {
      packedSalt := xor(shl(96, salt), creatorAddress)
    }
    return packedSalt;
  }

  /*******************************************************
   * View section
   ********************************************************/

  // Get fee to generate a new wallet
  function getFee() external view returns (uint256) {
    return _walletFee;
  }

  // Get implementation address
  function getImplementation() external view returns (address) {
    return _implementation;
  }

  // Calculate deterministic address
  function predictWalletAddress(address creatorAddress, uint96 salt) external view returns (address) {
    return _implementation.predictDeterministicAddress(_getUniqueSalt(creatorAddress, salt));
  }
}

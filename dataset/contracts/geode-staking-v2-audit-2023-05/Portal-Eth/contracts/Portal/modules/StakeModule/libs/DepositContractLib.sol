// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

// interfaces
import {IDepositContract} from "../../../interfaces/helpers/IDepositContract.sol";
// libraries
import {BytesLib} from "../../../helpers/BytesLib.sol";

/**
 * @title DCL: Deposit Contract Library
 *
 * @notice Includes constants & functions that helps to the deposit process.
 *
 * @dev DEPOSIT_CONTRACT is chain specific and should be changed before deployments.
 *
 * @dev This is an internal library, requires NO deployment.
 *
 * @author Ice Bear & Crash Bandicoot
 */

library DepositContractLib {
  /**
   * @custom:section                           ** CONSTANTS **
   */

  IDepositContract internal constant DEPOSIT_CONTRACT =
    IDepositContract(0xff50ed3d0ec03aC01D4C79aAd74928BFF48a7b2b);
  uint256 internal constant PUBKEY_LENGTH = 48;
  uint256 internal constant SIGNATURE_LENGTH = 96;
  uint256 internal constant WITHDRAWAL_CREDENTIALS_LENGTH = 32;
  uint256 internal constant DEPOSIT_AMOUNT = 32 ether;
  uint256 internal constant DEPOSIT_AMOUNT_PRESTAKE = 1 ether;
  uint256 internal constant MAX_DEPOSITS_PER_CALL = 50;

  /**
   * @custom:section                           ** FUNCTIONS **
   */

  /**
   * @dev Padding memory array with zeroes up to 64 bytes on the right
   * @param _b Memory array of size 32 .. 64
   */
  function _pad64(bytes memory _b) internal pure returns (bytes memory) {
    assert(_b.length >= 32 && _b.length <= 64);
    if (64 == _b.length) return _b;

    bytes memory zero32 = new bytes(32);
    assembly {
      mstore(add(zero32, 0x20), 0)
    }

    if (32 == _b.length) return BytesLib.concat(_b, zero32);
    else return BytesLib.concat(_b, BytesLib.slice(zero32, 0, uint256(64 - _b.length)));
  }

  /**
   * @dev Converting value to little endian bytes and padding up to 32 bytes on the right
   * @param _value Number less than `2**64` for compatibility reasons
   */
  function _toLittleEndian64(uint256 _value) internal pure returns (uint256 result) {
    result = 0;
    uint256 temp_value = _value;
    for (uint256 i = 0; i < 8; ++i) {
      result = (result << 8) | (temp_value & 0xFF);
      temp_value >>= 8;
    }

    assert(0 == temp_value); // fully converted
    result <<= (24 * 8);
  }

  function _getDepositDataRoot(
    bytes memory _pubkey,
    bytes memory _withdrawalCredentials,
    bytes memory _signature,
    uint256 _stakeAmount
  ) internal pure returns (bytes32) {
    require(_stakeAmount >= 1 ether, "DepositContract: deposit value too low");
    require(_stakeAmount % 1 gwei == 0, "DepositContract: deposit value not multiple of gwei");

    uint256 deposit_amount = _stakeAmount / 1 gwei;
    bytes32 pubkeyRoot = sha256(_pad64(_pubkey));
    bytes32 signatureRoot = sha256(
      abi.encodePacked(
        sha256(BytesLib.slice(_signature, 0, 64)),
        sha256(_pad64(BytesLib.slice(_signature, 64, SIGNATURE_LENGTH - 64)))
      )
    );

    bytes32 depositDataRoot = sha256(
      abi.encodePacked(
        sha256(abi.encodePacked(pubkeyRoot, _withdrawalCredentials)),
        sha256(abi.encodePacked(_toLittleEndian64(deposit_amount), signatureRoot))
      )
    );

    return depositDataRoot;
  }

  /**
   * @notice converts an address to withdrawal credential, used on validator creation
   */
  function addressToWC(address wcAddress) internal pure returns (bytes memory) {
    uint256 w = 1 << 248;

    return abi.encodePacked(bytes32(w) | bytes32(uint256(uint160(address(wcAddress)))));
  }

  /**
   * @notice deposit to DEPOSIT_CONTRACT and initiate a validator.
   */
  function depositValidator(
    bytes calldata pubkey,
    bytes memory withdrawalCredential,
    bytes memory signature,
    uint256 amount
  ) internal {
    DEPOSIT_CONTRACT.deposit{value: amount}(
      pubkey,
      withdrawalCredential,
      signature,
      _getDepositDataRoot(pubkey, withdrawalCredential, signature, amount)
    );
  }
}

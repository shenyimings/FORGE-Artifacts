// SPDX-License-Identifier: MIT

pragma solidity 0.5.16;

import "@openzeppelin/contracts/math/SafeMath.sol";

contract TokenStorage {

  using SafeMath for uint256;

  /**
   * @notice EIP-20 token name for this token
   */
  string public name;

  /**
   * @notice EIP-20 token symbol for this token
   */
  string public symbol;

  /**
   * @notice EIP-20 token decimals for this token
   */
  uint8 public decimals;

  /**
   * @notice Governor for this contract
   */
  address public gov;

  /**
   * @notice Pending governance for this contract
   */
  address public pendingGov;

  /**
   * @notice Approved rebaser for this contract
   */
  address public rebaser;

  /**
   * @notice Total supply of AUSCMs
   */
  uint256 public totalSupply;

  /**
   * @notice Internal decimals used to handle scaling factor
   */
  uint256 public constant internalDecimals = 10 ** 24;

  /**
   * @notice Used for percentage maths
   */
  uint256 public constant BASE = 10 ** 18;

  /**
   * @notice Scaling factor that adjusts everyone's balances
   */
  uint256 public auscsScalingFactor;

  mapping(address => uint256) internal _auscBalances;

  mapping(address => mapping(address => uint256)) internal _allowedFragments;

  uint256 public initSupply;
}

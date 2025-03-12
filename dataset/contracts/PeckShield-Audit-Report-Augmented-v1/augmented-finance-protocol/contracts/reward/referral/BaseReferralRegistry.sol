// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {SafeMath} from '../../dependencies/openzeppelin/contracts/SafeMath.sol';
import {Errors} from '../../tools/Errors.sol';

import 'hardhat/console.sol';

abstract contract BaseReferralRegistry {
  using SafeMath for uint256;

  mapping(uint256 => address) _delegations;
  mapping(uint256 => uint32) _timestamps;

  uint32 private constant RESERVED_CODE = type(uint32).max;

  function registerCustomCode(uint32 refCode, address to) public {
    require(refCode > RESERVED_CODE, 'REF_CODE_RESERVED');
    internalRegisterCode(refCode, to);
  }

  function internalRegisterCode(uint256 refCode, address to) internal {
    if (refCode < RESERVED_CODE) {
      require(refCode != 0, 'ZERO_REF_CODE_RESERVED');
    } else {
      require(refCode & RESERVED_CODE != RESERVED_CODE, 'DEFAULT_REF_CODE_RESERVED');
    }

    require(to != address(0), 'OWNER_REQUIRED');
    require(_delegations[refCode] == address(0), 'REF_CODE_REGISTERED');

    _delegations[refCode] = to;
  }

  function defaultCode(address addr) public pure returns (uint256) {
    if (addr == address(0)) {
      return 0;
    }
    return (uint256(keccak256(abi.encodePacked(addr))) << 32) | RESERVED_CODE;
  }

  function delegateCodeTo(uint256 refCode, address to) public {
    require(refCode != 0, 'REF_CODE_REQUIRED');
    require(to != address(0), 'OWNER_REQUIRED');

    if (_delegations[refCode] == address(0)) {
      require(refCode == defaultCode(msg.sender), 'REF_CODE_NOT_OWNED');
    } else {
      require(_delegations[refCode] == msg.sender, 'REF_CODE_WRONG_OWNER');
    }
    _delegations[refCode] = to;
  }

  function delegateDefaultCodeTo(address to) public returns (uint256 refCode) {
    require(to != address(0), 'OWNER_REQUIRED');
    refCode = defaultCode(msg.sender);
    require(refCode != 0, 'IMPOSSIBLE');

    require(
      _delegations[refCode] == address(0) || _delegations[refCode] == msg.sender,
      'REF_CODE_WRONG_OWNER'
    );
    _delegations[refCode] = to;
  }

  function timestampsOf(address owner, uint256[] calldata codes)
    external
    view
    returns (uint32[] memory timestamps)
  {
    require(owner != address(0), 'OWNER_REQUIRED');

    timestamps = new uint32[](codes.length);
    for (uint256 i = 0; i < codes.length; i++) {
      if (_delegations[codes[i]] != owner) {
        timestamps[i] = type(uint32).max;
        continue;
      }

      timestamps[i] = _timestamps[codes[i]];
    }

    return timestamps;
  }

  function internalUpdateTimestamps(
    address owner,
    uint256[] calldata codes,
    uint32 current
  ) internal returns (uint32[] memory timestamps) {
    require(owner != address(0), 'OWNER_REQUIRED');

    timestamps = new uint32[](codes.length);
    for (uint256 i = 0; i < codes.length; i++) {
      if (_delegations[codes[i]] != owner) {
        timestamps[i] = type(uint32).max;
        continue;
      }

      timestamps[i] = _timestamps[codes[i]];

      if (_timestamps[codes[i]] < current) {
        _timestamps[codes[i]] = current;
      }
    }

    return timestamps;
  }

  function internalUpdateStrict(
    address owner,
    uint256[] calldata codes,
    uint32 current
  ) internal {
    require(owner != address(0), 'OWNER_REQUIRED');

    for (uint256 i = 0; i < codes.length; i++) {
      require(_delegations[codes[i]] == owner, 'INVALID_REF_CODE_OWNER');
      require(_timestamps[codes[i]] < current, 'INVALID_REF_CODE_TIMESTAMP');

      _timestamps[codes[i]] = current;
    }
  }
}

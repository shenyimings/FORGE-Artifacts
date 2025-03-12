// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {SlashableStakeTokenBase} from './SlashableStakeTokenBase.sol';
import {StakeTokenConfig} from './interfaces/StakeTokenConfig.sol';
import {VersionedInitializable} from '../../tools/upgradeability/VersionedInitializable.sol';

/**
 * @title StakeToken
 * @notice Contract to stake a token for a system reserve.
 **/
contract StakeToken is SlashableStakeTokenBase, VersionedInitializable {
  uint256 private constant TOKEN_REVISION = 1;

  constructor() public SlashableStakeTokenBase(zeroConfig(), 'STAKE_STUB', 'STAKE_STUB', 0) {}

  function zeroConfig() private pure returns (StakeTokenConfig memory) {}

  function initialize(
    StakeTokenConfig calldata params,
    string calldata name,
    string calldata symbol,
    uint8 decimals
  ) external virtual override initializer(TOKEN_REVISION) {
    super._initializeERC20(name, symbol, decimals);
    super._initializeToken(params);
    super._initializeDomainSeparator();
    emit Initialized(params, name, symbol, decimals);
  }

  /**
   * @dev returns the revision of the implementation contract
   * @return The revision
   */
  function getRevision() internal pure virtual override returns (uint256) {
    return TOKEN_REVISION;
  }
}

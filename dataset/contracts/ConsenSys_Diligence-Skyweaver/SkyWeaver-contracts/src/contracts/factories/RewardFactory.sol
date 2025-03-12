pragma solidity 0.7.4;

import "../utils/TieredOwnable.sol";
import "../interfaces/ISkyweaverAssets.sol";
import "@0xsequence/erc-1155/contracts/utils/SafeMath.sol";
import "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";

/**
 * @notice This is a contract allowing contract owner to mint up to N 
 *         assets per period of 6 hours.
 * @dev This contract should only be able to mint some asset types
 */
contract RewardFactory is TieredOwnable {
  using SafeMath for uint256;

  /***********************************|
  |             Variables             |
  |__________________________________*/

  // Token information
  ISkyweaverAssets immutable public skyweaverAssets; // ERC-1155 Skyweaver assets contract

  // Period variables
  uint256 internal period;                // Current period
  uint256 internal availableSupply;       // Amount of assets that can currently be minted
  uint256 public periodMintLimit;         // Amount that can be minted within 6h
  uint256 immutable public PERIOD_LENGTH; // Length of each mint periods in seconds

  // Whitelist
  bool internal immutable MINT_WHITELIST_ONLY;
  mapping(uint256 => bool) public mintWhitelist;

  // Event
  event PeriodMintLimitChanged(uint256 oldMintingLimit, uint256 newMintingLimit);
  event AssetsEnabled(uint256[] enabledIds);
  event AssetsDisabled(uint256[] disabledIds);
  
  /***********************************|
  |            Constructor            |
  |__________________________________*/

  /**
   * @notice Create factory, link skyweaver assets and store initial parameters
   * @param _firstOwner      Address of the first owner
   * @param _assetsAddr      The address of the ERC-1155 Assets Token contract
   * @param _periodLength    Number of seconds each period lasts
   * @param _periodMintLimit Can only mint N assets per period
   * @param _whitelistOnly   Whether this factory uses a mint whitelist or not
   */
  constructor(
    address _firstOwner,
    address _assetsAddr,
    uint256 _periodLength,
    uint256 _periodMintLimit,
    bool _whitelistOnly
  ) TieredOwnable(_firstOwner) public {
    require(
      _assetsAddr != address(0) &&
      _periodLength > 0 &&
      _periodMintLimit > 0,
      "RewardFactory#constructor: INVALID_INPUT"
    );

    // Assets
    skyweaverAssets = ISkyweaverAssets(_assetsAddr);

    // Set Period length
    PERIOD_LENGTH = _periodLength;

    // Set whether this factory uses a mint whitelist or not
    MINT_WHITELIST_ONLY = _whitelistOnly;

    // Set current period
    period = block.timestamp / _periodLength; // From livePeriod()
    availableSupply = _periodMintLimit;

    // Rewards parameters
    periodMintLimit = _periodMintLimit;
    emit PeriodMintLimitChanged(0, _periodMintLimit);
  }


  /***********************************|
  |         Management Methods        |
  |__________________________________*/

  /**
   * @notice Will update the daily mint limit
   * @dev This change will take effect immediatly once executed
   * @param _newPeriodMintLimit Amount of assets that can be minted within a period
   */
  function updatePeriodMintLimit(uint256 _newPeriodMintLimit) external onlyOwnerTier(HIGHEST_OWNER_TIER) {
    // Immediately update supply instead of waiting for next period
    if (availableSupply > _newPeriodMintLimit) {
      availableSupply = _newPeriodMintLimit;
    }

    emit PeriodMintLimitChanged(periodMintLimit, _newPeriodMintLimit);
    periodMintLimit = _newPeriodMintLimit;
  }

  /**
   * @notice Will enable these tokens to be minted by this factory
   * @param _enabledIds IDs this factory can mint
   */
  function enableMint(uint256[] calldata _enabledIds) external onlyOwnerTier(HIGHEST_OWNER_TIER) {
    for (uint256 i = 0; i < _enabledIds.length; i++) {
      mintWhitelist[_enabledIds[i]] = true;
    }
    emit AssetsEnabled(_enabledIds);
  }

  /**
   * @notice Will prevent these ids from being minted by this factory
   * @param _disabledIds IDs this factory can mint
   */
  function disableMint(uint256[] calldata _disabledIds) external onlyOwnerTier(HIGHEST_OWNER_TIER) {
    for (uint256 i = 0; i < _disabledIds.length; i++) {
      mintWhitelist[_disabledIds[i]] = false;
    }
    emit AssetsDisabled(_disabledIds);
  }


  /***********************************|
  |      Receiver Method Handler      |
  |__________________________________*/

  /**
   * @notice Prevents receiving Ether or calls to unsuported methods
   */
  fallback () external {
    revert("RewardFactory#_: UNSUPPORTED_METHOD");
  }

  /***********************************|
  |         Minting Functions         |
  |__________________________________*/

  /**
   * @notice Will mint tokens to user
   * @dev Can only mint up to the periodMintLimit in a given 6hour period
   * @param _to      The address that receives the assets
   * @param _ids     Array of Tokens ID that are minted
   * @param _amounts Amount of Tokens id minted for each corresponding Token id in _ids
   * @param _data    Byte array passed to recipient if recipient is a contract
   */
  function batchMint(address _to, uint256[] calldata _ids, uint256[] calldata _amounts, bytes calldata _data)
    external onlyOwnerTier(1)
  {
    uint256 live_period = livePeriod();
    uint256 stored_period = period;
    uint256 available_supply;

    // Update period and refresh the available supply if period
    // is different, otherwise use current available supply.
    if (live_period == stored_period) {
      available_supply = availableSupply;
    } else {
      available_supply = periodMintLimit;
      period = live_period;
    }

    // If there is an insufficient available supply, this will revert
    for (uint256 i = 0; i < _ids.length; i++) {
      available_supply = available_supply.sub(_amounts[i]);
      if (MINT_WHITELIST_ONLY) {
        require(mintWhitelist[_ids[i]], "RewardFactory#batchMint: ID_IS_NOT_WHITELISTED");
      }
    }

    // Store available supply
    availableSupply = available_supply;
    
    // Mint assets
    skyweaverAssets.batchMint(_to, _ids, _amounts, _data);
  }


  /***********************************|
  |         Utility Functions         |
  |__________________________________*/

  /**
   * @notice Returns how many cards can currently be minted by this factory
   */
  function getAvailableSupply() external view returns (uint256) {
    return livePeriod() == period ? availableSupply : periodMintLimit;
  }

  /**
   * @notice Calculate the current period
   */
  function livePeriod() public view returns (uint256) {
    return block.timestamp / PERIOD_LENGTH;
  }

  /**
   * @notice Indicates whether a contract implements a given interface.
   * @param interfaceID The ERC-165 interface ID that is queried for support.
   * @return True if contract interface is supported.
   */
  function supportsInterface(bytes4 interfaceID) external pure returns (bool) {
    return  interfaceID == type(IERC165).interfaceId;
  }
}

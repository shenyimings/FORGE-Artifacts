pragma solidity 0.7.4;

import "../utils/TieredOwnable.sol";
import "../interfaces/ISkyweaverAssets.sol";
import "@0xsequence/erc-1155/contracts/utils/SafeMath.sol";
import "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";

/**
 * @notice This is a contract allowing contract owner to mint up to N
 * assets per period of 6 hours.
 * @dev This contract will only be able to mint tokens with ids that have a given itemType.
 * @dev The itemType is a uint8 that is the 2nd byte of the tokenID.
 *       Unused (1 byte)   Variant Type (2 bytes)   Variant ID (2 bytes)   Item Type (1 byte)   Item ID (2 bytes)
 *  0x   FF                FFFF                     FFFF                   FF                   FFFF
 */
contract VariantRewardFactory is TieredOwnable {
    using SafeMath for uint256;

    /***********************************|
    |             Variables             |
    |__________________________________*/

    // Packed booleans
    mapping(uint256 => uint256) private mintedBitMap;

    // Token information
    ISkyweaverAssets public immutable skyweaverAssets; // ERC-1155 Skyweaver assets contract
    uint8 public immutable allowedItemType;

    // Period variables
    uint256 internal period; // Current period
    uint256 internal availableSupply; // Amount of assets that can currently be minted
    uint256 public periodMintLimit; // Amount that can be minted within 6h
    uint256 public immutable PERIOD_LENGTH; // Length of each mint periods in seconds

    // Event
    event PeriodMintLimitChanged(uint256 oldMintingLimit, uint256 newMintingLimit);

    /***********************************|
    |            Constructor            |
    |__________________________________*/

    /**
     * @notice Create factory, link skyweaver assets and store initial parameters
     * @param _firstOwner      Address of the first owner
     * @param _assetsAddr      The address of the ERC-1155 Assets Token contract
     * @param _periodLength    Number of seconds each period lasts
     * @param _periodMintLimit Can only mint N assets per period
     */
    constructor(
        address _firstOwner,
        address _assetsAddr,
        uint256 _periodLength,
        uint256 _periodMintLimit,
        uint8 _itemType
    )
        public
        TieredOwnable(_firstOwner)
    {
        require(
            _assetsAddr != address(0) && _periodLength > 0 && _periodMintLimit > 0,
            "RewardFactory#constructor: INVALID_INPUT"
        );

        // Assets
        skyweaverAssets = ISkyweaverAssets(_assetsAddr);

        // Set Period length
        PERIOD_LENGTH = _periodLength;

        // Set current period
        period = block.timestamp / _periodLength; // From livePeriod()
        availableSupply = _periodMintLimit;

        // Rewards parameters
        periodMintLimit = _periodMintLimit;
        emit PeriodMintLimitChanged(0, _periodMintLimit);

        allowedItemType = uint8(_itemType);
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

    /***********************************|
    |      Receiver Method Handler      |
    |__________________________________*/

    /**
     * @notice Prevents receiving Ether or calls to unsuported methods
     */
    fallback() external {
        revert("RewardFactory#_: UNSUPPORTED_METHOD");
    }

    /***********************************|
    |         Minting Functions         |
    |__________________________________*/

    /**
     * @notice Returns whether a given token id has been minted or not
     * @param id The id of the token to check
     * @return Whether the token has been minted or not
     */
    function isMinted(uint256 id) public view returns (bool) {
        uint256 mintedWordIdx = id / 256;
        uint256 mintedBitIdx = id % 256;
        uint256 mintedWord = mintedBitMap[mintedWordIdx];
        uint256 mask = (1 << mintedBitIdx);
        return mintedWord & mask == mask;
    }

    /**
     * @notice Sets a given token id as minted
     * @param id The id of the token to set as minted
     * @dev This setting cannot be reversed
     */
    function _setMinted(uint256 id) private {
        uint256 mintedWordIdx = id / 256;
        uint256 mintedBitIdx = id % 256;
        mintedBitMap[mintedWordIdx] = mintedBitMap[mintedWordIdx] | (1 << mintedBitIdx);
    }

    /**
     * Checks if the given token id is valid for this factory.
     * @param id The id of the token to check
     * @return Whether the token is valid or not
     */
    function validTokenId(uint256 id) public view returns (bool) {
        uint8 itemType = uint8((id & 0x0000000000FF0000) >> 16);
        return itemType == allowedItemType;
    }

    /**
     * @notice Will mint tokens to user
     * @dev Can only mint up to the periodMintLimit in a given 6hour period
     * @param _to      The address that receives the assets
     * @param _ids     Array of Tokens ID that are minted
     * @param _amounts Amount of Tokens id minted for each corresponding Token id in _ids
     * @param _data    Byte array passed to recipient if recipient is a contract
     */
    function batchMint(address _to, uint256[] calldata _ids, uint256[] calldata _amounts, bytes calldata _data)
        external
        onlyOwnerTier(1)
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
            uint256 id = _ids[i];
            require(validTokenId(id), "VariantRewardFactory#batchMint: INVALID_TOKEN_ID");
            require(!isMinted(id), "VariantRewardFactory#batchMint: ID_ALREADY_MINTED");
            require(_amounts[i] == 1, "VariantRewardFactory#batchMint: NON_EXCLUSIVE_MINTING");
            _setMinted(id);

            available_supply = available_supply.sub(1);
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
        return interfaceID == type(IERC165).interfaceId;
    }
}

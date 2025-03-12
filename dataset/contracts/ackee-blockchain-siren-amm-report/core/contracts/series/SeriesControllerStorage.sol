// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.0;

import "./ISeriesController.sol";
import "../configuration/IAddressesProvider.sol";

/// This contract stores all new local variables for the SeriesController.sol contract.
/// This allows us to upgrade the contract and add new variables without worrying about
///   memory layout when we add new variables.
/// Each time a new version is created with new variables, the version "V1, V2, etc" should
//    be bumped and inherit from the previous version, and the MinterAmm should inherit from
///   the newest version.
abstract contract SeriesControllerStorageV1 is ISeriesController {
    /// @dev The price oracle consulted for any price data needed by the individual Series
    address internal priceOracle;

    /// @dev The address of the SeriesVault that stores all of this SeriesController's tokens
    address internal vault;

    /// @dev The fees charged for different methods on the SeriesController
    ISeriesController.Fees internal fees;

    /// @notice Monotonically incrementing index, used when creating Series.
    uint64 public override latestIndex;

    /// @dev The address of the ERC1155Controler that performs minting and burning of option tokens
    address public override erc1155Controller;

    /// @dev An array of all the Series structs ever created by the SeriesController
    ISeriesController.Series[] internal allSeries;

    /// @dev Stores the balance of a Series' ERC20 collateralToken
    /// e.g. seriesBalances[_seriesId] = 1,337,000,000
    mapping(uint64 => uint256) internal seriesBalances;

    /// @dev Price decimals
    uint8 public constant override priceDecimals = 8;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @dev These contract variables, as well as the `nonReentrant` modifier further down below,
    /// are copied from OpenZeppelin's ReentrancyGuard contract. We chose to copy ReentrancyGuard instead of
    /// having SeriesController inherit it because we intend use this SeriesController contract to upgrade already-deployed
    /// SeriesController contracts. If the SeriesController were to inherit from ReentrancyGuard, the ReentrancyGuard's
    /// contract storage variables would overwrite existing storage variables on the contract and it would
    /// break the contract. So by manually implementing ReentrancyGuard's logic we have full control over
    /// the position of the variable in the contract's storage, and we can ensure the SeriesController's contract
    /// storage variables are only ever appended to. See this OpenZeppelin article about contract upgradeability
    /// for more info on the contract storage variable requirement:
    /// https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable#modifying-your-contracts
    uint256 internal constant _NOT_ENTERED = 1;
    uint256 internal constant _ENTERED = 2;
    uint256 internal _status;

    /// @dev Stores the allowed expiration dates for series created by the auto series creation feature
    // Mapping is (ExpirationDate => ExpirationID); If the expiration ID is not 0 then it is a valid expiration date.
    // This is a convenience lookup mapping -> corresponds with allowedExpirationsList
    // ExpirationID lookup of value 0 means it is not set
    mapping(uint256 => uint256) public override allowedExpirationsMap;

    /// @dev Stores an array of allowed expirations.
    // The index in the array is the ExpirationID, the value is the ExpirationDate
    // This is a convenience lookup array -> corresponds with allowedExpirations
    // @note The 0th element in the list (first one) is a place holder, since we do not want any
    // expirations with ID 0 (we need to verify in the mapping that 0 means it is not set)
    uint256[] public override allowedExpirationsList;
}

abstract contract SeriesControllerStorageV2 is SeriesControllerStorageV1 {
    IAddressesProvider public addressesProvider;

    mapping(bytes32 => bool) public addedSeries;

    bytes32 public constant SERIES_DEPLOYER_ROLE =
        keccak256("SERIES_DEPLOYER_ROLE");
}

// Next version example:
/// contract SeriesControllerStorageV2 is SeriesControllerStorageV1 {
///   address public myAddress;
/// }
/// Then... SeriesController should inherit from SeriesControllerStorageV2

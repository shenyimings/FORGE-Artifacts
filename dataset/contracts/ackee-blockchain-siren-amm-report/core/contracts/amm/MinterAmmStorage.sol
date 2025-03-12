// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IMinterAmm.sol";
import "../oz/EnumerableSet.sol";
import "../series/ISeriesController.sol";
import "../series/SeriesLibrary.sol";
import "../token/ISimpleToken.sol";
import "../configuration/IAddressesProvider.sol";

/// This contract stores all new local variables for the MinterAmm.sol contract.
/// This allows us to upgrade the contract and add new variables without worrying about
///   memory layout when we add new variables.
/// Each time a new version is created with new variables, the version "V1, V2, etc" should
//    be bumped and inherit from the previous version, and the MinterAmm should inherit from
///   the newest version.
abstract contract MinterAmmStorageV1 is IMinterAmm {
    /// @dev The token contract that will track lp ownership of the AMM
    ISimpleToken public override lpToken;

    /// @dev The ERC20 tokens used by all the Series associated with this AMM
    IERC20 public override underlyingToken;
    IERC20 public override priceToken;
    IERC20 public override collateralToken;

    /// @dev The registry which the AMM will use to lookup individual Series
    ISeriesController public seriesController;

    /// @notice The contract used to mint the option tokens
    IERC1155 public erc1155Controller;

    /// @dev Fees on trading
    uint16 public tradeFeeBasisPoints;

    // volatilityFactor is depricated and replaced with seriesVolatilities
    uint256 public volatilityFactor;

    /// @dev Flag to ensure initialization can only happen once
    bool initialized = false;

    uint256 public constant MINIMUM_TRADE_SIZE = 1000;

    /// @dev A price oracle contract used to get onchain price data
    address internal sirenPriceOracle;

    /// @dev Collection of ids of open series
    /// @dev If we ever re-deploy MinterAmm we need to check that the EnumerableSet implementation hasnâ€™t changed,
    /// because we rely on undocumented implementation details (see Note in MinterAmm.claimAllExpiredTokens on
    /// removing series)
    EnumerableSet.UintSet internal openSeries;

    /// @dev These contract variables, as well as the `nonReentrant` modifier further down below,
    /// are copied from OpenZeppelin's ReentrancyGuard contract. We chose to copy ReentrancyGuard instead of
    /// having MinterAmm inherit it because we intend use this MinterAmm contract to upgrade already-deployed
    /// MinterAmm contracts. If The MinterAmm were to inherit from ReentrancyGuard, the ReentrancyGuard's
    /// contract storage variables would overwrite existing storage variables on the contract and it would
    /// break the contract. So by manually implementing ReentrancyGuard's logic we have full control over
    /// the position of the variable in the contract's storage, and we can ensure the MinterAmm's contract
    /// storage variables are only ever appended to. See this OpenZeppelin article about contract upgradeability
    /// for more info on the contract storage variable requirement:
    /// https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable#modifying-your-contracts
    uint256 internal constant _NOT_ENTERED = 1;
    uint256 internal constant _ENTERED = 2;
    uint256 internal _status;

    /// @dev Max fee basis points on the value of the option
    uint16 public maxOptionFeeBasisPoints;

    /// @dev Address where fees are sent on each trade
    address public feeDestinationAddress;

    /// @dev The contract used to make pricing calculations for the MinterAmm
    address public ammDataProvider;

    /// @dev The address for the airswap Light contract on-chain.
    address public lightAirswapAddress;
}

abstract contract MinterAmmStorageV2 is MinterAmmStorageV1 {
    /// @dev Stores volatility mapped to each series
    struct SeriesVolatility {
        uint256 volatility;
        uint256 updatedAt;
    }

    ///Replaces volatilityFactor
    mapping(uint64 => SeriesVolatility) public seriesVolatilities;

    /// @dev The address for the AddressesProvider
    IAddressesProvider addressesProvider;

    /// @dev Shift of baseline IV vs historical oracle feed (1e18)
    int256 public ivShift;

    /// @dev Turn dynamic IV on/off
    bool public dynamicIvEnabled;

    /// @dev IV drift rate towards baseline IV (smaller means faster convergence)
    uint16 public ivDriftRate;
}

abstract contract MinterAmmStorageV3 is MinterAmmStorageV2 {
    uint256 public lockedCollateral;
}

// Next version example:
/// contract MinterAmmStorageV3 is MinterAmmStorageV2 {
///   address public myAddress;
/// }
/// Then... MinterAmm should inherit from MinterAmmStorageV3

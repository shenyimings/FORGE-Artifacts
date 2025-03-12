// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.17;

import "./libraries/FloorMath.sol";

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";



/// @notice This contract contains global variables for the Zivoe protocol.
///         This contract has the following responsibilities:
///          - Maintain accounting of all defaults within the system in aggregate.
///          - Handle ZVL AccessControl (switching to other wallets).
///          - Whitelist management for "keepers" which are allowed to execute proposals within the TLC in advance.
///          - Whitelist management for "lockers" which ZivoeDAO can push/pull to.
///          - Whitelist management for "stablecoins" which are accepted in other Zivoe contracts.
///          - View function for standardized ERC20 precision handling.
///          - View function for adjusting the supplies of tranches (accounting purposes).
contract ZivoeGlobals is Ownable {

    using FloorMath for uint256;

    // ---------------------
    //    State Variables
    // ---------------------

    address public DAO;         /// @dev The ZivoeDAO contract.
    address public ITO;         /// @dev The ZivoeITO contract.
    address public stJTT;       /// @dev The ZivoeRewards ($stJTT) contract.
    address public stSTT;       /// @dev The ZivoeRewards ($stSTT) contract.
    address public stZVE;       /// @dev The ZivoeRewards ($stZVE) contract.
    address public vestZVE;     /// @dev The ZivoeRewardsVesting ($vestZVE) vesting contract.
    address public YDL;         /// @dev The ZivoeYDL contract.
    address public zJTT;        /// @dev The ZivoeTrancheToken ($zJTT) contract.
    address public zSTT;        /// @dev The ZivoeTrancheToken ($zSTT) contract.
    address public ZVE;         /// @dev The ZivoeToken ($ZVE) contract.
    address public ZVL;         /// @dev The Zivoe Laboratory.
    address public ZVT;         /// @dev The ZivoeTranches contract.
    address public GOV;         /// @dev The Governor contract.
    address public TLC;         /// @dev The TimelockController contract.

    uint256 public defaults;    /// @dev Tracks net defaults in the system.

    /// @dev Whitelist for keepers, responsible for pre-initiating actions.
    mapping(address => bool) public isKeeper;
    
    /// @dev Whitelist for lockers, for ZivoeDAO interactions and accounting accessibility.
    mapping(address => bool) public isLocker;

    /// @dev Whitelist for accepted stablecoins throughout Zivoe (e.g. ZVT or YDL).    
    mapping(address => bool) public stablecoinWhitelist;



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the ZivoeGlobals contract.
    constructor() { }



    // ------------
    //    Events
    // ------------

    /// @notice Emitted during decreaseDefaults().
    /// @param  locker          The locker updating the default amount.
    /// @param  amount          Amount of defaults decreased.
    /// @param  updatedDefaults Total default(s) in system after event.
    event DefaultsDecreased(address indexed locker, uint256 amount, uint256 updatedDefaults);

    /// @notice Emitted during increaseDefaults().
    /// @param  locker          The locker updating the default amount.
    /// @param  amount          Amount of defaults increased.
    /// @param  updatedDefaults Total default(s) in system after event.
    event DefaultsIncreased(address indexed locker, uint256 amount, uint256 updatedDefaults);

    /// @notice Emitted during initializeGlobals().
    /// @param  controller The address representing ZVL.
    event TransferredZVL(address indexed controller);

    /// @notice Emitted during updateIsKeeper().
    /// @param  account The address whose status as a keeper is being modified.
    /// @param  status  The new status of "account".
    event UpdatedKeeperStatus(address indexed account, bool status);

    /// @notice Emitted during updateIsLocker().
    /// @param  locker  The locker whose status as a locker is being modified.
    /// @param  status The new status of "locker".
    event UpdatedLockerStatus(address indexed locker, bool status);

    /// @notice Emitted during updateStablecoinWhitelist().
    /// @param  asset   The stablecoin to update.
    /// @param  allowed The boolean value to assign.
    event UpdatedStablecoinWhitelist(address indexed asset, bool allowed);



    // ---------------
    //    Modifiers
    // ---------------

    modifier onlyZVL() {
        require(_msgSender() == ZVL, "ZivoeGlobals::onlyZVL() _msgSender() != ZVL");
        _;
    }



    // ---------------
    //    Functions
    // ---------------

    /// @notice Call when a default is resolved, decreases net defaults system-wide.
    /// @dev    _msgSender() MUST be "true" on "isLocker" whitelist mapping.
    /// @dev    FloorMath should handle underflow and enforce defaults == 0 if there's an excess decrement.
    /// @dev    The value "amount" should be standardized to WEI (handle externally prior to calling this).
    /// @param  amount The amount to decrease defaults.
    function decreaseDefaults(uint256 amount) external {
        require(isLocker[_msgSender()], "ZivoeGlobals::decreaseDefaults() !isLocker[_msgSender()]");
        
        defaults = defaults.floorSub(amount);
        emit DefaultsDecreased(_msgSender(), amount, defaults);
    }

    /// @notice Call when a default occurs, increases net defaults system-wide.
    /// @dev    _msgSender() MUST be "true" on "isLocker" whitelist mapping.
    /// @dev    The value "amount" should be standardized to WEI (handle externally prior to calling this).
    /// @param  amount The amount to increase defaults.
    function increaseDefaults(uint256 amount) external {
        require(isLocker[_msgSender()], "ZivoeGlobals::increaseDefaults() !isLocker[_msgSender()]");

        defaults += amount;
        emit DefaultsIncreased(_msgSender(), amount, defaults);
    }

    /// @notice Initialze state variables (perform after all contracts have been deployed).
    /// @dev    This function MUST only be called once. This function MUST only be called by owner().
    /// @param  globals     Array of addresses representing all core system contracts.
    /// @param  stablecoins Array of stablecoins representing initial acceptable stablecoins.
    function initializeGlobals(
        address[] calldata globals,
        address[] calldata stablecoins
    ) external onlyOwner {
        require(DAO == address(0), "ZivoeGlobals::initializeGlobals() DAO != address(0)");

        emit TransferredZVL(globals[10]);

        DAO     = globals[0];
        ITO     = globals[1];
        stJTT   = globals[2];
        stSTT   = globals[3];
        stZVE   = globals[4];
        vestZVE = globals[5];
        YDL     = globals[6];
        zJTT    = globals[7];
        zSTT    = globals[8];
        ZVE     = globals[9];
        ZVL     = globals[10];
        GOV     = globals[11];
        TLC     = globals[12];
        ZVT     = globals[13];

        stablecoinWhitelist[stablecoins[0]] = true; // DAI
        stablecoinWhitelist[stablecoins[1]] = true; // USDC
        stablecoinWhitelist[stablecoins[2]] = true; // USDT
    }

    /// @notice Transfer ZVL access control to another account.
    /// @dev    This function MUST only be called by ZVL().
    /// @param  _ZVL The new address for ZVL.
    function transferZVL(address _ZVL) external onlyZVL {
        ZVL = _ZVL;
        emit TransferredZVL(_ZVL);
    }

    /// @notice Updates the keeper whitelist.
    /// @dev    This function MUST only be called by ZVL().
    /// @param  keeper The address of the keeper.
    /// @param  status The status to assign to the "keeper" (true = allowed, false = restricted).
    function updateIsKeeper(address keeper, bool status) external onlyZVL {
        emit UpdatedKeeperStatus(keeper, status);
        isKeeper[keeper] = status;
    }

    /// @notice Modifies the locker whitelist.
    /// @dev    This function MUST only be called by ZVL().
    /// @param  locker  The locker to update.
    /// @param  status The status to assign to the "locker" (true = permitted, false = prohibited).
    function updateIsLocker(address locker, bool status) external onlyZVL {
        emit UpdatedLockerStatus(locker, status);
        isLocker[locker] = status;
    }

    /// @notice Modifies the stablecoin whitelist.
    /// @dev    This function MUST only be called by ZVL().
    /// @param  stablecoin The stablecoin to update.
    /// @param  allowed The value to assign (true = permitted, false = prohibited).
    function updateStablecoinWhitelist(address stablecoin, bool allowed) external onlyZVL {
        emit UpdatedStablecoinWhitelist(stablecoin, allowed);
        stablecoinWhitelist[stablecoin] = allowed;
    }

    /// @notice Handles WEI standardization of a given asset amount (i.e. 6 decimal precision => 18 decimal precision).
    /// @param  amount              The amount of a given "asset".
    /// @param  asset               The asset (ERC-20) from which to standardize the amount to WEI.
    /// @return standardizedAmount  The input "amount" standardized to 18 decimals.
    function standardize(uint256 amount, address asset) external view returns (uint256 standardizedAmount) {
        standardizedAmount = amount;
        if (IERC20Metadata(asset).decimals() < 18) { 
            standardizedAmount *= 10 ** (18 - IERC20Metadata(asset).decimals()); 
        } 
        else if (IERC20Metadata(asset).decimals() > 18) { 
            standardizedAmount /= 10 ** (IERC20Metadata(asset).decimals() - 18);
        }
    }

    /// @notice Returns total circulating supply of zSTT and zJTT adjusted for defaults.
    /// @return zSTTAdjustedSupply  zSTT.totalSupply() adjusted for defaults.
    /// @return zJTTAdjustedSupply  zJTT.totalSupply() adjusted for defaults.
    function adjustedSupplies() external view returns (uint256 zSTTAdjustedSupply, uint256 zJTTAdjustedSupply) {
        // Junior tranche compresses based on defaults, to a floor of zero.
        uint256 totalSupplyJTT = IERC20(zJTT).totalSupply();
        zJTTAdjustedSupply = totalSupplyJTT.floorSub(defaults);

        // Senior tranche compresses based on excess defaults, to a floor of zero.
        if (defaults > totalSupplyJTT) {
            zSTTAdjustedSupply = IERC20(zSTT).totalSupply().floorSub(defaults - totalSupplyJTT);
        }
        else { zSTTAdjustedSupply = IERC20(zSTT).totalSupply(); }
    }

}

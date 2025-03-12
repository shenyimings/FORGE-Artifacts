// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../ZivoeLocker.sol";

import "../../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IERC20Burnable_OCR {
    /// @notice Burns tokens.
    /// @param  amount The number of tokens to burn.
    function burn(uint256 amount) external;
}

interface IZivoeGlobals_OCR {

    /// @notice Returns the address of the ZivoeDAO contract.
    function DAO() external view returns (address);

    /// @notice Returns the address of the Timelock contract.
    function TLC() external view returns (address);

    /// @notice Returns the address of the $zJTT contract.
    function zJTT() external view returns (address);

    /// @notice Returns the address of the $zSTT contract.
    function zSTT() external view returns (address);

    /// @notice Tracks net defaults in the system.
    function defaults() external view returns (uint256);

    /// @notice Handles WEI standardization of a given asset amount (i.e. 6 decimal precision => 18 decimal precision).
    /// @param  amount The amount of a given "asset".
    /// @param  asset The asset (ERC-20) from which to standardize the amount to WEI.
    /// @return standardizedAmount The above amount standardized to 18 decimals.
    function standardize(uint256 amount, address asset) external view returns (uint256 standardizedAmount);
}



/// @notice  OCR stands for "On-Chain Redemption".
///          This locker is responsible for handling redemptions of tranche tokens to stablecoins.
contract OCR_Modular is ZivoeLocker, ReentrancyGuard {

    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    struct Request {
        address account;        /// @dev The account making the request.
        uint256 amount;         /// @dev The amount of the request ($zSTT or $zJTT).
        uint256 unlocks;        /// @dev The timestamp after which this request may be processed.
        bool seniorElseJunior;  /// @dev The tranche this request is for (true = Senior, false = Junior).
    }

    address public immutable GBL;                   /// @dev The ZivoeGlobals contract.
    address public immutable stablecoin;            /// @dev The stablecoin redeemable in this contract.
    
    uint256 public epoch;                           /// @dev The timestamp of current epoch.
    uint256 public epochDiscountJunior;             /// @dev Redemption discount for $zJTT (junior tranche).
    uint256 public epochDiscountSenior;             /// @dev Redemption discount for $zSTT (senior tranche).
    uint256 public redemptionsAllowedJunior;        /// @dev Redemptions allowed for $zJTT (junior tranche).
    uint256 public redemptionsAllowedSenior;        /// @dev Redemptions allowed for $zSTT (senior tranche).
    uint256 public redemptionsFeeBIPS;              /// @dev Fee for redemptions (in BIPS).
    uint256 public redemptionsQueuedJunior;         /// @dev Redemptions queued for $zJTT (junior tranche).
    uint256 public redemptionsQueuedSenior;         /// @dev Redemptions queued for $zSTT (senior tranche).
    uint256 public requestCounter;                  /// @dev Increments with new requests.

    uint256 private constant BIPS = 10000;
    uint256 private constant RAY = 10**27;

    mapping(uint256 => Request) public requests;    /// @dev Mapping of all requests.



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCR_Modular contract.
    /// @param  DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param  _stablecoin The stablecoin redeemable in this OCR contract.
    /// @param  _GBL The ZivoeGlobals contract.
    /// @param  _redemptionsFeeBIPS Fee for redemptions (in BIPS).
    constructor(address DAO, address _stablecoin, address _GBL, uint16 _redemptionsFeeBIPS) {
        require(_redemptionsFeeBIPS <= 2000, "OCR_Modular::constructor() _redemptionsFeeBIPS > 2000");
        transferOwnershipAndLock(DAO);
        stablecoin = _stablecoin;
        GBL = _GBL;
        redemptionsFeeBIPS = _redemptionsFeeBIPS;
        epoch = block.timestamp;
    }



    // ------------
    //    Events
    // ------------

    /// @notice Emitted during tickEpoch().
    /// @param  epoch The timestamp of the start of this epoch.
    /// @param  redemptionsAllowedJunior Redemptions allowed for $zJTT (junior tranche) for this epoch.
    /// @param  redemptionsAllowedSenior Redemptions allowed for $zSTT (senior tranche) for this epoch.
    /// @param  epochDiscountJunior Redemption discount for $zJTT (junior tranche) for this epoch.
    /// @param  epochDiscountSenior Redemption discount for $zSTT (senior tranche) for this epoch.
    event EpochTicked(
        uint256 epoch, 
        uint256 redemptionsAllowedJunior, 
        uint256 redemptionsAllowedSenior,
        uint256 epochDiscountJunior, 
        uint256 epochDiscountSenior
    );

    /// @notice Emitted during createRequest().
    /// @param  id The ID of the request created.
    /// @param  account The account creating a request.
    /// @param  amount The amount deposited for the request ($zJTT or $zSTT).
    /// @param  seniorElseJunior The tranche deposited for (true = Senior, false = Junior).
    event RequestCreated(uint256 indexed id, address indexed account, uint256 amount, bool indexed seniorElseJunior);

    /// @notice Emitted during destroyRequest().
    /// @param  id The ID of the request destroyed.
    /// @param  account The account destroying the request.
    /// @param  amount The amount returned from the request ($zJTT or $zSTT)
    /// @param  seniorElseJunior The tranche deposited for (true = Senior, false = Junior).
    event RequestDestroyed(uint256 indexed id, address indexed account, uint256 amount, bool indexed seniorElseJunior);

    /// @notice Emitted during processRequest().
    /// @param  id The ID of the request processed.
    /// @param  account The account receiving the redeemd tokens.
    /// @param  burnAmount The amount of tranche tokens ($zJTT or $zSTT) burned from the request.
    /// @param  redeemAmount The amount reddeemed from the processed request.
    /// @param  seniorElseJunior The tranche deposited for (true = Senior, false = Junior).
    event RequestProcessed(
        uint256 indexed id, 
        address indexed account, 
        uint256 burnAmount, 
        uint256 redeemAmount, 
        bool indexed seniorElseJunior
    );

    /// @notice Emitted during updateRedemptiosnFee().
    /// @param  oldFee The old value of redemptionsFeeBIPS.
    /// @param  newFee The new value of redemptionsFeeBIPS.
    event UpdatedRedemptionsFeeBIPS(uint256 oldFee, uint256 newFee);



    // ---------------
    //    Modifiers
    // ---------------

    /// @notice This modifier ensures accounting is updated BEFORE mutative actions.
    modifier _tickEpoch() {
        tickEpoch();
        _;
    }



    // ---------------
    //    Functions
    // ---------------

    /// @notice Permission for owner to call pushToLocker().
    function canPush() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLocker().
    function canPull() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLockerPartial().
    function canPullPartial() public override pure returns (bool) { return true; }

    /// @notice This pulls capital from the DAO.
    /// @param  asset The asset to pull from the DAO.
    /// @param  amount The amount of asset to pull from the DAO.
    /// @param  data Accompanying transaction data.
    function pushToLocker(
        address asset, uint256 amount, bytes calldata data
    ) external override _tickEpoch onlyOwner nonReentrant {
        require(asset == stablecoin, "OCR_Modular::pushToLocker() asset != stablecoin");
        IERC20(asset).safeTransferFrom(owner(), address(this), amount);
    }

    /// @notice Migrates entire ERC20 balance from locker to owner().
    /// @param  asset The asset to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLocker(address asset, bytes calldata data) external override _tickEpoch onlyOwner nonReentrant {
        require(
            asset != IZivoeGlobals_OCR(GBL).zJTT() && asset != IZivoeGlobals_OCR(GBL).zSTT(),
            "OCR_Modular::pullFromLocker() asset == zJTT || asset == zSTT"
        );
        IERC20(asset).safeTransfer(owner(), IERC20(asset).balanceOf(address(this)));
    }

    /// @notice Migrates specific amount of ERC20 from locker to owner().
    /// @param  asset The asset to migrate.
    /// @param  amount The amount of "asset" to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLockerPartial(
        address asset, uint256 amount, bytes calldata data
    ) external override _tickEpoch onlyOwner nonReentrant {
        require(
            asset != IZivoeGlobals_OCR(GBL).zJTT() && asset != IZivoeGlobals_OCR(GBL).zSTT(),
            "OCR_Modular::pullFromLockerPartial() asset == zJTT || asset == zSTT"
        );
        IERC20(asset).safeTransfer(owner(), amount);
    }

    /// @notice Creates a redemption request.
    /// @param  amount The amount to deposit for the request.
    /// @param  seniorElseJunior The tranche to deposit for (true = Senior, false = Junior).
    function createRequest(uint256 amount, bool seniorElseJunior) external _tickEpoch nonReentrant {
        require(amount > 0, "OCR_Modular::createRequest() amount == 0");
        emit RequestCreated(requestCounter, _msgSender(), amount, seniorElseJunior);
        requests[requestCounter] = Request(_msgSender(), amount, epoch + 14 days, seniorElseJunior);
        if (seniorElseJunior) {
            redemptionsQueuedSenior += amount;
            IERC20(IZivoeGlobals_OCR(GBL).zSTT()).safeTransferFrom(_msgSender(), address(this), amount);
        }
        else {
            redemptionsQueuedJunior += amount;
            IERC20(IZivoeGlobals_OCR(GBL).zJTT()).safeTransferFrom(_msgSender(), address(this), amount);
        }
        requestCounter += 1;
    }

    /// @notice Destroys a redemption request.
    /// @param  id The ID of the request to destroy.
    function destroyRequest(uint256 id) external _tickEpoch nonReentrant {
        require(
            requests[id].account == _msgSender(),
             "OCR_Modular::destroyRequest() requests[id].account != _msgSender()"
        );
        require(requests[id].amount > 0, "OCR_Modular::destroyRequest() requests[id].amount == 0");

        emit RequestDestroyed(id, requests[id].account, requests[id].amount, requests[id].seniorElseJunior);
        if (requests[id].seniorElseJunior) {
            IERC20(IZivoeGlobals_OCR(GBL).zSTT()).safeTransfer(requests[id].account, requests[id].amount);
            if (requests[id].unlocks > epoch) { redemptionsQueuedSenior -= requests[id].amount; }
            else { redemptionsAllowedSenior -= requests[id].amount; }
        }
        else {
            IERC20(IZivoeGlobals_OCR(GBL).zJTT()).safeTransfer(requests[id].account, requests[id].amount);
            if (requests[id].unlocks > epoch) { redemptionsQueuedJunior -= requests[id].amount; }
            else { redemptionsAllowedJunior -= requests[id].amount; }
        }
        requests[id].amount = 0;
    }

    /// @notice Processes a redemption request.
    /// @param  id The ID of the request to process.
    function processRequest(uint256 id) external _tickEpoch nonReentrant {
        require(requests[id].amount > 0, "OCR_Modular::processRequest() requests[id].amount == 0");
        require(requests[id].unlocks <= epoch, "OCR_Modular::processRequest() requests[id].unlocks > epoch");

        requests[id].unlocks = epoch + 14 days;

        // Calculate the full amount of redemptions allowed for current epoch.
        uint256 totalRedemptions = redemptionsAllowedSenior + redemptionsAllowedJunior;

        // Standardize the amount of stablecoins present (given totalRedemptions is in WEI precision).
        uint stablecoinBalance = IZivoeGlobals_OCR(GBL).standardize(
            IERC20(stablecoin).balanceOf(address(this)), 
            stablecoin
        );

        // Calculate portion of stablecoins present relative to totalRedemptions requests, in BIPS precision.
        uint256 portion = (stablecoinBalance * RAY / totalRedemptions) / 10**23;

        // Hardcap portion at 10,000 (BIPS) to prevent overflow.
        if (portion > BIPS) { portion = BIPS; }

        // Identify the amount of tokens burnable (redeemable) relative to allowed redemptions and stablecoins present.
        uint256 burnAmount = requests[id].amount * portion / BIPS;

        uint256 redeemAmount;

        if (requests[id].seniorElseJunior) {
            IERC20Burnable_OCR(IZivoeGlobals_OCR(GBL).zSTT()).burn(burnAmount);
            // Reduce redeemable amount by the defaulted portion relative to tranche.
            redeemAmount = burnAmount * (BIPS - epochDiscountSenior) / BIPS;
            redemptionsAllowedSenior -= requests[id].amount;
            requests[id].amount -= burnAmount;
            redemptionsQueuedSenior += requests[id].amount;
        }
        else {
            IERC20Burnable_OCR(IZivoeGlobals_OCR(GBL).zJTT()).burn(burnAmount);
            // Reduce redeemable amount by the defaulted portion relative to tranche.
            redeemAmount = burnAmount * (BIPS - epochDiscountJunior) / BIPS;
            redemptionsAllowedJunior -= requests[id].amount;
            requests[id].amount -= burnAmount;
            redemptionsQueuedJunior += requests[id].amount;
        }

        if (IERC20Metadata(stablecoin).decimals() < 18) {
            redeemAmount /= 10 ** (18 - IERC20Metadata(stablecoin).decimals());
        }

        require(redeemAmount > 0, "OCR_Modular::processRequest() redeemAmount == 0");
        
        IERC20(stablecoin).safeTransfer(requests[id].account, redeemAmount * (BIPS - redemptionsFeeBIPS) / BIPS);
        IERC20(stablecoin).safeTransfer(IZivoeGlobals_OCR(GBL).DAO(), redeemAmount * redemptionsFeeBIPS / BIPS);
        emit RequestProcessed(id, requests[id].account, burnAmount, redeemAmount, requests[id].seniorElseJunior);
    }

    /// @notice Ticks the epoch.
    function tickEpoch() public {
        while (block.timestamp >= epoch + 14 days) { 
            epoch += 14 days;
            redemptionsAllowedJunior += redemptionsQueuedJunior;
            redemptionsAllowedSenior += redemptionsQueuedSenior;
            redemptionsQueuedJunior = 0;
            redemptionsQueuedSenior = 0;
            uint256 totalDefaults = IZivoeGlobals_OCR(GBL).defaults();
            uint256 zSTTSupply = IERC20(IZivoeGlobals_OCR(GBL).zSTT()).totalSupply();
            uint256 zJTTSupply = IERC20(IZivoeGlobals_OCR(GBL).zJTT()).totalSupply();
            if (totalDefaults > zJTTSupply) {
                epochDiscountJunior = BIPS;
                totalDefaults -= zJTTSupply;
                epochDiscountSenior = (totalDefaults * RAY / zSTTSupply) / 10**23;
            }
            else {
                epochDiscountJunior = (totalDefaults * RAY / zJTTSupply) / 10**23;
            }
            emit EpochTicked(
                epoch, 
                redemptionsAllowedJunior, 
                redemptionsAllowedSenior, 
                epochDiscountJunior, 
                epochDiscountSenior
            );
        }
    }

    /// @notice Updates the state variable "redemptionsFeeBIPS".
    /// @param  _redemptionsFeeBIPS The new value for redemptionsFeeBIPS (in BIPS).
    function updateRedemptionsFeeBIPS(uint256 _redemptionsFeeBIPS) external _tickEpoch {
        require(
            _msgSender() == IZivoeGlobals_OCR(GBL).TLC(), 
            "OCR_Modular::updateRedemptionsFeeBIPS() _msgSender() != TLC()"
        );
        require(
            _redemptionsFeeBIPS <= 2000, "OCR_Modular::updateRedemptionsFeeBIPS() _redemptionsFeeBIPS > 2000"
        );
        emit UpdatedRedemptionsFeeBIPS(redemptionsFeeBIPS, _redemptionsFeeBIPS);
        redemptionsFeeBIPS = _redemptionsFeeBIPS;
    }

}
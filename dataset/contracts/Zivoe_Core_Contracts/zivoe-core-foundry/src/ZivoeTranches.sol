// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.17;

import "./ZivoeLocker.sol";

import "../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

interface IERC20Mintable_ZivoeTranches {
    /// @notice Creates ERC20 tokens and assigns them to an address, increasing the total supply.
    /// @param account The address to send the newly created tokens to.
    /// @param amount The amount of tokens to create and send.
    function mint(address account, uint256 amount) external;
}

interface IZivoeGlobals_ZivoeTranches {
    /// @notice Returns the address of the ZivoeDAO contract.
    function DAO() external view returns (address);

    /// @notice Returns the address of the ZivoeITO contract.
    function ITO() external view returns (address);

    /// @notice Returns the address of the Timelock contract.
    function TLC() external view returns (address);

    /// @notice Returns the address of the ZivoeTrancheToken ($zSTT) contract.
    function zSTT() external view returns (address);

    /// @notice Returns the address of the ZivoeTrancheToken ($zJTT) contract.
    function zJTT() external view returns (address);

    /// @notice Returns the address of the ZivoeToken contract.
    function ZVE() external view returns (address);

    /// @notice Returns the address of the Zivoe Laboratory.
    function ZVL() external view returns (address);

    /// @notice Returns total circulating supply of zSTT and zJTT, accounting for defaults via markdowns.
    /// @return zSTTSupply zSTT.totalSupply() adjusted for defaults.
    /// @return zJTTSupply zJTT.totalSupply() adjusted for defaults.
    function adjustedSupplies() external view returns (uint256 zSTTSupply, uint256 zJTTSupply);

    /// @notice This function will verify if a given stablecoin has been whitelisted for use throughout system.
    /// @param stablecoin address of the stablecoin to verify acceptance for.
    function stablecoinWhitelist(address stablecoin) external view returns (bool);

    /// @notice Handles WEI standardization of a given asset amount (i.e. 6 decimal precision => 18 decimal precision).
    /// @param amount The amount of a given "asset".
    /// @param asset The asset (ERC-20) from which to standardize the amount to WEI.
    /// @return standardizedAmount The above amount standardized to 18 decimals.
    function standardize(uint256 amount, address asset) external view returns (uint256 standardizedAmount);
}



/// @notice  This contract will facilitate ongoing liquidity provision to Zivoe tranches - Junior, Senior.
///          This contract will be permissioned by $zJTT and $zSTT to call mint().
///          This contract will support a whitelist for stablecoins to provide as liquidity.
contract ZivoeTranches is ZivoeLocker, ReentrancyGuard {

    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL;   /// @dev The ZivoeGlobals contract.

    /// @dev This ratio represents the maximum size allowed for junior tranche, relative to senior tranche.
    ///      A value of 2,000 represent 20%, thus junior tranche at maximum can be 20% the size of senior tranche.
    uint256 public maxTrancheRatioBIPS = 4250;

    /// @dev These two values control the min/max $ZVE minted per stablecoin deposited to ZivoeTranches.
    uint256 public minZVEPerJTTMint = 0;
    uint256 public maxZVEPerJTTMint = 0;

    /// @dev Basis points ratio between zJTT.totalSupply():zSTT.totalSupply() for maximum rewards (affects above slope).
    uint256 public lowerRatioIncentiveBIPS = 1000;
    uint256 public upperRatioIncentiveBIPS = 2000;

    bool public tranchesUnlocked;   /// @dev Prevents contract from supporting functionality until unlocked.
    bool public paused;             /// @dev Temporary mechanism for pausing deposits.

    uint256 private constant BIPS = 10000;



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the ZivoeTranches contract.
    /// @param _GBL The ZivoeGlobals contract.
    constructor(address _GBL) { GBL = _GBL; }



    // ------------
    //    Events
    // ------------

    /// @notice Emitted during depositJunior().
    /// @param  account The account depositing stablecoins to junior tranche.
    /// @param  asset The stablecoin deposited.
    /// @param  amount The amount of stablecoins deposited.
    /// @param  incentives The amount of incentives ($ZVE) distributed.
    event JuniorDeposit(address indexed account, address indexed asset, uint256 amount, uint256 incentives);

    /// @notice Emitted during depositSenior().
    /// @param  account The account depositing stablecoins to senior tranche.
    /// @param  asset The stablecoin deposited.
    /// @param  amount The amount of stablecoins deposited.
    /// @param  incentives The amount of incentives ($ZVE) distributed.
    event SeniorDeposit(address indexed account, address indexed asset, uint256 amount, uint256 incentives);

    /// @notice Emitted during updateLowerRatioIncentiveBIPS().
    /// @param  oldValue The old value of lowerRatioJTT.
    /// @param  newValue The new value of lowerRatioJTT.
    event UpdatedLowerRatioIncentiveBIPS(uint256 oldValue, uint256 newValue);

    /// @notice Emitted during updateMaxTrancheRatio().
    /// @param  oldValue The old value of maxTrancheRatioBIPS.
    /// @param  newValue The new value of maxTrancheRatioBIPS.
    event UpdatedMaxTrancheRatioBIPS(uint256 oldValue, uint256 newValue);

    /// @notice Emitted during updateMaxZVEPerJTTMint().
    /// @param  oldValue The old value of maxZVEPerJTTMint.
    /// @param  newValue The new value of maxZVEPerJTTMint.
    event UpdatedMaxZVEPerJTTMint(uint256 oldValue, uint256 newValue);

    /// @notice Emitted during updateMinZVEPerJTTMint().
    /// @param  oldValue The old value of minZVEPerJTTMint.
    /// @param  newValue The new value of minZVEPerJTTMint.
    event UpdatedMinZVEPerJTTMint(uint256 oldValue, uint256 newValue);

    /// @notice Emitted during updateUpperRatioIncentiveBIPS().
    /// @param  oldValue The old value of upperRatioJTT.
    /// @param  newValue The new value of upperRatioJTT.
    event UpdatedUpperRatioIncentiveBIPS(uint256 oldValue, uint256 newValue);



    // ---------------
    //    Functions
    // ---------------

    modifier notPaused() {
        require(!paused, "ZivoeTranches::whenPaused() notPaused");
        _;
    }

    modifier onlyGovernance() {
        require(
            _msgSender() == IZivoeGlobals_ZivoeTranches(GBL).TLC(), 
            "ZivoeTranches::onlyGovernance() _msgSender() != IZivoeGlobals_ZivoeTranches(GBL).TLC()"
        );
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

    /// @notice This pulls capital from the DAO, does any necessary pre-conversions, and escrows ZVE for incentives.
    /// @param asset The asset to pull from the DAO.
    /// @param amount The amount of asset to pull from the DAO.
    /// @param  data Accompanying transaction data.
    function pushToLocker(address asset, uint256 amount, bytes calldata data) external override onlyOwner {
        require(
            asset == IZivoeGlobals_ZivoeTranches(GBL).ZVE(), 
            "ZivoeTranches::pushToLocker() asset != IZivoeGlobals_ZivoeTranches(GBL).ZVE()"
        );
        IERC20(asset).safeTransferFrom(owner(), address(this), amount);
    }

    /// @notice Checks if stablecoins deposits into the Junior Tranche are open.
    /// @param  amount The amount to deposit.
    /// @param  asset The asset (stablecoin) to deposit.
    /// @return open Will return "true" if the deposits into the Junior Tranche are open.
    function isJuniorOpen(uint256 amount, address asset) public view returns (bool open) {
        uint256 convertedAmount = IZivoeGlobals_ZivoeTranches(GBL).standardize(amount, asset);
        (uint256 seniorSupp, uint256 juniorSupp) = IZivoeGlobals_ZivoeTranches(GBL).adjustedSupplies();
        return convertedAmount + juniorSupp < seniorSupp * maxTrancheRatioBIPS / BIPS;
    }
    
    /// @notice Returns the total rewards in $ZVE for a certain junior tranche deposit amount.
    /// @dev Input amount MUST be in WEI (use GBL.standardize(amount, asset)).
    /// @dev Output amount MUST be in WEI.
    /// @param deposit The amount supplied to the junior tranche.
    /// @return reward The rewards in $ZVE to be received.
    function rewardZVEJuniorDeposit(uint256 deposit) public view returns (uint256 reward) {

        (uint256 seniorSupp, uint256 juniorSupp) = IZivoeGlobals_ZivoeTranches(GBL).adjustedSupplies();

        uint256 avgRate;    // The avg ZVE per stablecoin deposit reward, used for reward calculation.

        uint256 diffRate = maxZVEPerJTTMint - minZVEPerJTTMint;

        uint256 startRatio = juniorSupp * BIPS / seniorSupp;
        uint256 finalRatio = (juniorSupp + deposit) * BIPS / seniorSupp;
        uint256 avgRatio = (startRatio + finalRatio) / 2;

        if (avgRatio <= lowerRatioIncentiveBIPS) {
            avgRate = maxZVEPerJTTMint;
        } else if (avgRatio >= upperRatioIncentiveBIPS) {
            avgRate = minZVEPerJTTMint;
        } else {
            avgRate = maxZVEPerJTTMint - diffRate * (avgRatio - 1000) / (1500);
        }

        reward = avgRate * deposit / 1 ether;

        // Reduce if ZVE balance < reward.
        if (IERC20(IZivoeGlobals_ZivoeTranches(GBL).ZVE()).balanceOf(address(this)) < reward) {
            reward = IERC20(IZivoeGlobals_ZivoeTranches(GBL).ZVE()).balanceOf(address(this));
        }
    }

    /// @notice Returns the total rewards in $ZVE for a certain senior tranche deposit amount.
    /// @dev Input amount MUST be in WEI (use GBL.standardize(amount, asset)).
    /// @dev Output amount MUST be in WEI.
    /// @param deposit The amount supplied to the senior tranche.
    /// @return reward The rewards in $ZVE to be received.
    function rewardZVESeniorDeposit(uint256 deposit) public view returns (uint256 reward) {

        (uint256 seniorSupp, uint256 juniorSupp) = IZivoeGlobals_ZivoeTranches(GBL).adjustedSupplies();

        uint256 avgRate;    // The avg ZVE per stablecoin deposit reward, used for reward calculation.

        uint256 diffRate = maxZVEPerJTTMint - minZVEPerJTTMint;

        uint256 startRatio = juniorSupp * BIPS / seniorSupp;
        uint256 finalRatio = juniorSupp * BIPS / (seniorSupp + deposit);
        uint256 avgRatio = (startRatio + finalRatio) / 2;

        if (avgRatio <= lowerRatioIncentiveBIPS) {
            avgRate = minZVEPerJTTMint;
        } else if (avgRatio >= upperRatioIncentiveBIPS) {
            avgRate = maxZVEPerJTTMint;
        } else {
            avgRate = minZVEPerJTTMint + diffRate * (avgRatio - 1000) / (1500);
        }

        reward = avgRate * deposit / 1 ether;

        // Reduce if ZVE balance < reward.
        if (IERC20(IZivoeGlobals_ZivoeTranches(GBL).ZVE()).balanceOf(address(this)) < reward) {
            reward = IERC20(IZivoeGlobals_ZivoeTranches(GBL).ZVE()).balanceOf(address(this));
        }
    }

    /// @notice Deposit stablecoins into the junior tranche.
    /// @dev    Mints Zivoe Junior Tranche ($zJTT) tokens in 1:1 ratio.
    /// @param  amount The amount to deposit.
    /// @param  asset The asset (stablecoin) to deposit.
    function depositJunior(uint256 amount, address asset) external notPaused nonReentrant {
        require(
            IZivoeGlobals_ZivoeTranches(GBL).stablecoinWhitelist(asset), 
            "ZivoeTranches::depositJunior() !IZivoeGlobals_ZivoeTranches(GBL).stablecoinWhitelist(asset)"
        );
        require(tranchesUnlocked, "ZivoeTranches::depositJunior() !tranchesUnlocked");

        address depositor = _msgSender();

        IERC20(asset).safeTransferFrom(depositor, IZivoeGlobals_ZivoeTranches(GBL).DAO(), amount);
        
        uint256 convertedAmount = IZivoeGlobals_ZivoeTranches(GBL).standardize(amount, asset);

        require(isJuniorOpen(amount, asset),"ZivoeTranches::depositJunior() !isJuniorOpen(amount, asset)");

        uint256 incentives = rewardZVEJuniorDeposit(convertedAmount);
        emit JuniorDeposit(depositor, asset, amount, incentives);

        // NOTE: Ordering important, transfer ZVE rewards prior to minting zJTT() due to totalSupply() changes.
        IERC20(IZivoeGlobals_ZivoeTranches(GBL).ZVE()).safeTransfer(depositor, incentives);
        IERC20Mintable_ZivoeTranches(IZivoeGlobals_ZivoeTranches(GBL).zJTT()).mint(depositor, convertedAmount);
    }

    /// @notice Deposit stablecoins into the senior tranche.
    /// @dev    Mints Zivoe Senior Tranche ($zSTT) tokens in 1:1 ratio.
    /// @param  amount The amount to deposit.
    /// @param  asset The asset (stablecoin) to deposit.
    function depositSenior(uint256 amount, address asset) external notPaused nonReentrant {
        require(
            IZivoeGlobals_ZivoeTranches(GBL).stablecoinWhitelist(asset), 
            "ZivoeTranches::depositSenior() !IZivoeGlobals_ZivoeTranches(GBL).stablecoinWhitelist(asset)"
        );
        require(tranchesUnlocked, "ZivoeTranches::depositSenior() !tranchesUnlocked");

        address depositor = _msgSender();

        IERC20(asset).safeTransferFrom(depositor, IZivoeGlobals_ZivoeTranches(GBL).DAO(), amount);
        
        uint256 convertedAmount = IZivoeGlobals_ZivoeTranches(GBL).standardize(amount, asset);

        uint256 incentives = rewardZVESeniorDeposit(convertedAmount);

        emit SeniorDeposit(depositor, asset, amount, incentives);

        // NOTE: Ordering important, transfer ZVE rewards prior to minting zJTT() due to totalSupply() changes.
        IERC20(IZivoeGlobals_ZivoeTranches(GBL).ZVE()).safeTransfer(depositor, incentives);
        IERC20Mintable_ZivoeTranches(IZivoeGlobals_ZivoeTranches(GBL).zSTT()).mint(depositor, convertedAmount);
    }

    /// @notice Pauses or unpauses the contract, enabling or disabling depositJunior() and depositSenior().
    function switchPause() external {
        require(
            _msgSender() == IZivoeGlobals_ZivoeTranches(GBL).ZVL(), 
            "ZivoeTranches::switchPause() _msgSender() != IZivoeGlobals_ZivoeTranches(GBL).ZVL()"
        );
        paused = !paused;
    }

    /// @notice Updates the lower ratio between tranches for minting incentivization model.
    /// @dev    A value of 1,000 represents 10%, indicating that maximum $ZVE incentives are offered for
    ///         minting $zJTT (Junior Tranche Tokens) when the actual tranche ratio is <=10%.
    ///         Likewise, due to inverse relationship between incentives for $zJTT and $zSTT minting,
    ///         a value of 1,000 represents 10%, indicating that minimum $ZVE incentives are offered for
    ///         minting $zSTT (Senior Tranche Tokens) when the actual tranche ratio is <=10% 
    /// @param  _lowerRatioIncentiveBIPS The lower ratio to handle incentivize thresholds.
    function updateLowerRatioIncentiveBIPS(uint256 _lowerRatioIncentiveBIPS) external onlyGovernance {
        require(
            _lowerRatioIncentiveBIPS >= 1000, 
            "ZivoeTranches::updateLowerRatioIncentiveBIPS() _lowerRatioIncentiveBIPS < 1000")
        ;
        require(
            _lowerRatioIncentiveBIPS < upperRatioIncentiveBIPS, 
            "ZivoeTranches::updateLowerRatioIncentiveBIPS() _lowerRatioIncentiveBIPS >= upperRatioIncentiveBIPS"
        );
        emit UpdatedLowerRatioIncentiveBIPS(lowerRatioIncentiveBIPS, _lowerRatioIncentiveBIPS);
        lowerRatioIncentiveBIPS = _lowerRatioIncentiveBIPS; 
    }

    /// @notice Updates the maximum size of junior tranche, relative to senior tranche.
    /// @dev    A value of 2,000 represents 20% (basis points), meaning the junior tranche 
    ///         at maximum can be 20% the size of senior tranche.
    /// @param  ratio The new ratio value.
    function updateMaxTrancheRatio(uint256 ratio) external onlyGovernance {
        require(ratio <= 4500, "ZivoeTranches::updateMaxTrancheRatio() ratio > 4500");
        emit UpdatedMaxTrancheRatioBIPS(maxTrancheRatioBIPS, ratio);
        maxTrancheRatioBIPS = ratio;
    }

    /// @notice Updates the maximum $ZVE minted per stablecoin deposited to ZivoeTranches.
    /// @param  max Maximum $ZVE minted per stablecoin.
    function updateMaxZVEPerJTTMint(uint256 max) external onlyGovernance {
        require(minZVEPerJTTMint < max, "ZivoeTranches::updateMaxZVEPerJTTMint() minZVEPerJTTMint >= max");
        require(max < 0.1 * 10**18, "ZivoeTranches::updateMaxZVEPerJTTMint() max >= 0.1 * 10**18");
        emit UpdatedMaxZVEPerJTTMint(maxZVEPerJTTMint, max);
        maxZVEPerJTTMint = max; 
    }

    /// @notice Updates the minimum $ZVE minted per stablecoin deposited to ZivoeTranches.
    /// @param  min Minimum $ZVE minted per stablecoin.
    function updateMinZVEPerJTTMint(uint256 min) external onlyGovernance {
        require(min < maxZVEPerJTTMint, "ZivoeTranches::updateMinZVEPerJTTMint() min >= maxZVEPerJTTMint");
        emit UpdatedMinZVEPerJTTMint(minZVEPerJTTMint, min);
        minZVEPerJTTMint = min;
    }

    /// @notice Updates the upper ratio between tranches for minting incentivization model.
    /// @dev    A value of 2,000 represents 20%, indicating that minimum $ZVE incentives are offered for
    ///         minting $zJTT (Junior Tranche Tokens) when the actual tranche ratio is >= 20%.
    ///         Likewise, due to inverse relationship between incentives for $zJTT and $zSTT minting,
    ///         a value of 2,000 represents 20%, indicating that maximum $ZVE incentives are offered for
    ///         minting $zSTT (Senior Tranche Tokens) when the actual tranche ratio is >= 20%.
    /// @param  _upperRatioIncentiveBIPS The upper ratio to handle incentivize thresholds.
    function updateUpperRatioIncentiveBIPS(uint256 _upperRatioIncentiveBIPS) external onlyGovernance {
        require(
            lowerRatioIncentiveBIPS < _upperRatioIncentiveBIPS, 
            "ZivoeTranches::updateUpperRatioIncentiveBIPS() lowerRatioIncentiveBIPS >= _upperRatioIncentiveBIPS"
        );
        require(
            _upperRatioIncentiveBIPS <= 2500, 
            "ZivoeTranches::updateUpperRatioIncentiveBIPS() _upperRatioIncentiveBIPS > 2500"
        );
        emit UpdatedUpperRatioIncentiveBIPS(upperRatioIncentiveBIPS, _upperRatioIncentiveBIPS);
        upperRatioIncentiveBIPS = _upperRatioIncentiveBIPS; 
    }

    /// @notice Unlocks this contract for distributions, sets some initial variables.
    function unlock() external {
        require(
            _msgSender() == IZivoeGlobals_ZivoeTranches(GBL).ITO(), 
            "ZivoeTranches::unlock() _msgSender() != IZivoeGlobals_ZivoeTranches(GBL).ITO()"
        );
        tranchesUnlocked = true;
    }

}
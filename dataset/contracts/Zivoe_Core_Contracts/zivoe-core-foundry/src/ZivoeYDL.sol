// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.17;

import "./ZivoeMath.sol";

import "./libraries/FloorMath.sol";

import "../lib/openzeppelin-contracts/contracts/utils/Context.sol";
import "../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

interface IZivoeGlobals_YDL {
    /// @notice Returns the address of the ZivoeDAO contract.
    function DAO() external view returns (address);

    /// @notice Returns the address of the ZivoeITO contract.
    function ITO() external view returns (address);
    
    /// @notice Returns the address of the ZivoeRewards ($zSTT) contract.
    function stSTT() external view returns (address);

    /// @notice Returns the address of the ZivoeRewards ($zJTT) contract.
    function stJTT() external view returns (address);

    /// @notice Returns the address of the ZivoeRewards ($ZVE) contract.
    function stZVE() external view returns (address);

    /// @notice Returns the address of the Timelock contract.
    function TLC() external view returns (address);

    /// @notice Returns the address of the ZivoeRewardsVesting ($ZVE) vesting contract.
    function vestZVE() external view returns (address);

    /// @notice Returns the address of the ZivoeTrancheToken ($zSTT) contract.
    function zSTT() external view returns (address);

    /// @notice Returns the address of the ZivoeTrancheToken ($zJTT) contract.
    function zJTT() external view returns (address);

    /// @notice Returns total circulating supply of zSTT and zJTT, accounting for defaults via markdowns.
    /// @return zSTTSupply zSTT.totalSupply() adjusted for defaults.
    /// @return zJTTSupply zJTT.totalSupply() adjusted for defaults.
    function adjustedSupplies() external view returns (uint256 zSTTSupply, uint256 zJTTSupply);

    /// @notice Handles WEI standardization of a given asset amount (i.e. 6 decimal precision => 18 decimal precision).
    /// @param  amount The amount of a given "asset".
    /// @param  asset The asset (ERC-20) from which to standardize the amount to WEI.
    /// @return standardizedAmount The above amount standardized to 18 decimals.
    function standardize(uint256 amount, address asset) external view returns (uint256 standardizedAmount);

    /// @notice This function will verify if a given stablecoin has been whitelisted for use throughout system.
    /// @param  stablecoin address of the stablecoin to verify acceptance for.
    function stablecoinWhitelist(address stablecoin) external view returns (bool);
}

interface IZivoeRewards_YDL {
    /// @notice Deposits a reward to this contract for distribution.
    /// @param  _rewardsToken The asset that's being distributed.
    /// @param  reward The amount of the _rewardsToken to deposit.
    function depositReward(address _rewardsToken, uint256 reward) external;
}



/// @notice  This contract manages the accounting for distributing yield across multiple contracts.
///          This contract has the following responsibilities:
///            - Escrows yield in between distribution periods.
///            - Manages accounting for yield distribution.
///            - Supports modification of certain state variables for governance purposes.
///            - Tracks historical values using EMA (exponential moving average) on 30-day basis.
///            - Facilitates arbitrary swaps from non-distributeAsset tokens to distributedAsset tokens.
contract ZivoeYDL is Context, ReentrancyGuard {

    using SafeERC20 for IERC20;
    using FloorMath for uint256;

    // ---------------------
    //    State Variables
    // ---------------------

    struct Recipients {
        address[] recipients;
        uint256[] proportion;
    }

    Recipients protocolRecipients;          /// @dev Tracks the distributions for protocol earnings.
    Recipients residualRecipients;          /// @dev Tracks the distributions for residual earnings.

    address public immutable GBL;           /// @dev The ZivoeGlobals contract.

    address public distributedAsset;        /// @dev The "stablecoin" that will be distributed via YDL.

    // Weighted moving averages.
    uint256 public emaSTT;          /// @dev Weighted moving average for senior tranche size, a.k.a. zSTT.totalSupply().
    uint256 public emaJTT;          /// @dev Weighted moving average for junior tranche size, a.k.a. zJTT.totalSupply().

    // Indexing.
    uint256 public distributionCounter;     /// @dev Number of calls to distributeYield().
    uint256 public lastDistribution;        /// @dev Used for timelock constraint to call distributeYield().

    // Accounting vars (governable).
    uint256 public targetAPYBIPS = 800;                 /// @dev The target annualized yield for senior tranche.
    uint256 public targetRatioBIPS = 16250;             /// @dev The target ratio of junior to senior tranche.
    uint256 public protocolEarningsRateBIPS = 2000;     /// @dev The protocol earnings rate.

    // Accounting vars (constant).
    uint256 public constant daysBetweenDistributions = 30;   /// @dev Number of days between yield distributions.
    uint256 public constant retrospectiveDistributions = 6;  /// @dev Retrospective moving average period.
    
    bool public unlocked;                   /// @dev Prevents contract from supporting functionality until unlocked.

    uint256 private constant BIPS = 10000;
    uint256 private constant RAY = 10 ** 27;

    ZivoeMath public MATH;



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initialize the ZivoeYDL contract.
    /// @param  _GBL The ZivoeGlobals contract.
    /// @param  _distributedAsset The "stablecoin" that will be distributed via YDL.
    constructor(address _GBL, address _distributedAsset) {
        GBL = _GBL;
        distributedAsset = _distributedAsset;
        MATH = new ZivoeMath();
    }



    // ------------
    //    Events
    // ------------

    /// @notice Emitted during returnAsset().
    /// @param  asset The asset returned.
    /// @param  amount The amount of "asset" returned to DAO.
    event AssetReturned(address indexed asset, uint256 amount);

    /// @notice Emitted during updateDistributedAsset().
    /// @param  oldAsset The old asset of distributedAsset.
    /// @param  newAsset The new asset of distributedAsset.
    event UpdatedDistributedAsset(address indexed oldAsset, address indexed newAsset);

    /// @notice Emitted during updateProtocolEarningsRateBIPS().
    /// @param  oldValue The old value of protocolEarningsRateBIPS.
    /// @param  newValue The new value of protocolEarningsRateBIPS.
    event UpdatedProtocolEarningsRateBIPS(uint256 oldValue, uint256 newValue);

    /// @notice Emitted during updateRecipients().
    /// @param  recipients The new recipients to receive protocol earnings.
    /// @param  proportion The proportion distributed across recipients.
    event UpdatedProtocolRecipients(address[] recipients, uint256[] proportion);

    /// @notice Emitted during updateRecipients().
    /// @param  recipients The new recipients to receive residual earnings.
    /// @param  proportion The proportion distributed across recipients.
    event UpdatedResidualRecipients(address[] recipients, uint256[] proportion);

    /// @notice Emitted during updateTargetAPYBIPS().
    /// @param  oldValue The old value of targetAPYBIPS.
    /// @param  newValue The new value of targetAPYBIPS.
    event UpdatedTargetAPYBIPS(uint256 oldValue, uint256 newValue);

    /// @notice Emitted during updateTargetRatioBIPS().
    /// @param  oldValue The old value of targetRatioBIPS.
    /// @param  newValue The new value of targetRatioBIPS.
    event UpdatedTargetRatioBIPS(uint256 oldValue, uint256 newValue);

    /// @notice Emitted during distributeYield().
    /// @param  protocol The amount of earnings distributed to protocol earnings recipients.
    /// @param  senior The amount of earnings distributed to the senior tranche.
    /// @param  junior The amount of earnings distributed to the junior tranche.
    /// @param  residual The amount of earnings distributed to residual earnings recipients.
    event YieldDistributed(uint256[] protocol, uint256 senior, uint256 junior, uint256[] residual);

    /// @notice Emitted during distributeYield().
    /// @param  asset The "asset" being distributed.
    /// @param  recipient The recipient of the distribution.
    /// @param  amount The amount distributed.
    event YieldDistributedSingle(address indexed asset, address indexed recipient, uint256 amount);



    // ---------------
    //    Functions
    // ---------------

    /// @notice View distribution information for protocol and residual earnings recipients.
    /// @return protocolEarningsRecipients The destinations for protocol earnings distributions.
    /// @return protocolEarningsProportion The proportions for protocol earnings distributions.
    /// @return residualEarningsRecipients The destinations for residual earnings distributions.
    /// @return residualEarningsProportion The proportions for residual earnings distributions.
    function viewDistributions() external view returns (
        address[] memory protocolEarningsRecipients, uint256[] memory protocolEarningsProportion, 
        address[] memory residualEarningsRecipients, uint256[] memory residualEarningsProportion
    ) {
        return (
            protocolRecipients.recipients, 
            protocolRecipients.proportion, 
            residualRecipients.recipients, 
            residualRecipients.proportion
        );
    }
    
    /// @notice Distributes available yield within this contract to appropriate entities.
    function distributeYield() external nonReentrant {
        require(unlocked, "ZivoeYDL::distributeYield() !unlocked"); 
        require(
            block.timestamp >= lastDistribution + daysBetweenDistributions * 86400, 
            "ZivoeYDL::distributeYield() block.timestamp < lastDistribution + daysBetweenDistributions * 86400"
        );

        // Calculate protocol earnings.
        uint256 earnings = IERC20(distributedAsset).balanceOf(address(this));
        uint256 protocolEarnings = protocolEarningsRateBIPS * earnings / BIPS;
        uint256 postFeeYield = earnings.floorSub(protocolEarnings);

        // Update timeline.
        distributionCounter += 1;
        lastDistribution = block.timestamp;

        // Calculate yield distribution (trancheuse = "slicer" in French).
        (
            uint256[] memory _protocol, uint256 _seniorTranche, uint256 _juniorTranche, uint256[] memory _residual
        ) = earningsTrancheuse(protocolEarnings, postFeeYield); 

        emit YieldDistributed(_protocol, _seniorTranche, _juniorTranche, _residual);
        
        // Update ema-based supply values.
        (uint256 aSTT, uint256 aJTT) = IZivoeGlobals_YDL(GBL).adjustedSupplies();
        emaSTT = MATH.ema(emaSTT, aSTT, retrospectiveDistributions.min(distributionCounter));
        emaJTT = MATH.ema(emaJTT, aJTT, retrospectiveDistributions.min(distributionCounter));

        // Distribute protocol earnings.
        for (uint256 i = 0; i < protocolRecipients.recipients.length; i++) {
            address _recipient = protocolRecipients.recipients[i];
            if (_recipient == IZivoeGlobals_YDL(GBL).stSTT() ||_recipient == IZivoeGlobals_YDL(GBL).stJTT()) {
                IERC20(distributedAsset).safeIncreaseAllowance(_recipient, _protocol[i]);
                IZivoeRewards_YDL(_recipient).depositReward(distributedAsset, _protocol[i]);
                emit YieldDistributedSingle(distributedAsset, _recipient, _protocol[i]);
            }
            else if (_recipient == IZivoeGlobals_YDL(GBL).stZVE()) {
                uint256 splitBIPS = (
                    IERC20(IZivoeGlobals_YDL(GBL).stZVE()).totalSupply() * BIPS
                ) / (
                    IERC20(IZivoeGlobals_YDL(GBL).stZVE()).totalSupply() + 
                    IERC20(IZivoeGlobals_YDL(GBL).vestZVE()).totalSupply()
                );
                uint stZVEAllocation = _protocol[i] * splitBIPS / BIPS;
                uint vestZVEAllocation = _protocol[i] * (BIPS - splitBIPS) / BIPS;
                IERC20(distributedAsset).safeIncreaseAllowance(IZivoeGlobals_YDL(GBL).stZVE(), stZVEAllocation);
                IERC20(distributedAsset).safeIncreaseAllowance(IZivoeGlobals_YDL(GBL).vestZVE(),vestZVEAllocation);
                IZivoeRewards_YDL(IZivoeGlobals_YDL(GBL).stZVE()).depositReward(distributedAsset, stZVEAllocation);
                IZivoeRewards_YDL(IZivoeGlobals_YDL(GBL).vestZVE()).depositReward(distributedAsset, vestZVEAllocation);
                emit YieldDistributedSingle(distributedAsset, IZivoeGlobals_YDL(GBL).stZVE(), stZVEAllocation);
                emit YieldDistributedSingle(distributedAsset, IZivoeGlobals_YDL(GBL).vestZVE(), vestZVEAllocation);
            }
            else {
                IERC20(distributedAsset).safeTransfer(_recipient, _protocol[i]);
                emit YieldDistributedSingle(distributedAsset, _recipient, _protocol[i]);
            }
        }

        // Distribute senior and junior tranche earnings.
        IERC20(distributedAsset).safeIncreaseAllowance(IZivoeGlobals_YDL(GBL).stSTT(), _seniorTranche);
        IERC20(distributedAsset).safeIncreaseAllowance(IZivoeGlobals_YDL(GBL).stJTT(), _juniorTranche);
        IZivoeRewards_YDL(IZivoeGlobals_YDL(GBL).stSTT()).depositReward(distributedAsset, _seniorTranche);
        IZivoeRewards_YDL(IZivoeGlobals_YDL(GBL).stJTT()).depositReward(distributedAsset, _juniorTranche);
        emit YieldDistributedSingle(distributedAsset, IZivoeGlobals_YDL(GBL).stSTT(), _seniorTranche);
        emit YieldDistributedSingle(distributedAsset, IZivoeGlobals_YDL(GBL).stJTT(), _juniorTranche);

        // Distribute residual earnings.
        for (uint256 i = 0; i < residualRecipients.recipients.length; i++) {
            if (_residual[i] > 0) {
                address _recipient = residualRecipients.recipients[i];
                if (_recipient == IZivoeGlobals_YDL(GBL).stSTT() ||_recipient == IZivoeGlobals_YDL(GBL).stJTT()) {
                    IERC20(distributedAsset).safeIncreaseAllowance(_recipient, _residual[i]);
                    IZivoeRewards_YDL(_recipient).depositReward(distributedAsset, _residual[i]);
                    emit YieldDistributedSingle(distributedAsset, _recipient, _protocol[i]);
                }
                else if (_recipient == IZivoeGlobals_YDL(GBL).stZVE()) {
                    uint256 splitBIPS = (
                        IERC20(IZivoeGlobals_YDL(GBL).stZVE()).totalSupply() * BIPS
                    ) / (
                        IERC20(IZivoeGlobals_YDL(GBL).stZVE()).totalSupply() + 
                        IERC20(IZivoeGlobals_YDL(GBL).vestZVE()).totalSupply()
                    );
                    uint stZVEAllocation = _residual[i] * splitBIPS / BIPS;
                    uint vestZVEAllocation = _residual[i] * (BIPS - splitBIPS) / BIPS;
                    IERC20(distributedAsset).safeIncreaseAllowance(IZivoeGlobals_YDL(GBL).stZVE(), stZVEAllocation);
                    IERC20(distributedAsset).safeIncreaseAllowance(IZivoeGlobals_YDL(GBL).vestZVE(), vestZVEAllocation);
                    IZivoeRewards_YDL(IZivoeGlobals_YDL(GBL).stZVE()).depositReward(distributedAsset, stZVEAllocation);
                    IZivoeRewards_YDL(IZivoeGlobals_YDL(GBL).vestZVE()).depositReward(distributedAsset, vestZVEAllocation);
                    emit YieldDistributedSingle(distributedAsset, IZivoeGlobals_YDL(GBL).stZVE(), stZVEAllocation);
                    emit YieldDistributedSingle(distributedAsset, IZivoeGlobals_YDL(GBL).vestZVE(), vestZVEAllocation);
                }
                else {
                    IERC20(distributedAsset).safeTransfer(_recipient, _residual[i]);
                    emit YieldDistributedSingle(distributedAsset, _recipient, _residual[i]);
                }
            }
        }
    }

    /// @notice Returns an asset to DAO if not distributedAsset().
    function returnAsset(address asset) external {
        require(asset != distributedAsset, "ZivoeYDL::returnAsset() asset == distributedAsset");
        emit AssetReturned(asset, IERC20(asset).balanceOf(address(this)));
        IERC20(asset).safeTransfer(IZivoeGlobals_YDL(GBL).DAO(), IERC20(asset).balanceOf(address(this)));
    }

    /// @notice Unlocks this contract for distributions, initializes values.
    function unlock() external {
        require(
            _msgSender() == IZivoeGlobals_YDL(GBL).ITO(), 
            "ZivoeYDL::unlock() _msgSender() != IZivoeGlobals_YDL(GBL).ITO()"
        );

        unlocked = true;
        lastDistribution = block.timestamp + 30 days;

        emaSTT = IERC20(IZivoeGlobals_YDL(GBL).zSTT()).totalSupply();
        emaJTT = IERC20(IZivoeGlobals_YDL(GBL).zJTT()).totalSupply();

        // NOTE: The protocolRecipients and residualRecipients parameters are hardcoded, may change before deployment.

        address[] memory protocolRecipientAcc = new address[](2);
        uint256[] memory protocolRecipientAmt = new uint256[](2);

        protocolRecipientAcc[0] = address(IZivoeGlobals_YDL(GBL).stZVE());
        protocolRecipientAmt[0] = 7500;
        protocolRecipientAcc[1] = address(IZivoeGlobals_YDL(GBL).DAO());
        protocolRecipientAmt[1] = 2500;

        protocolRecipients = Recipients(protocolRecipientAcc, protocolRecipientAmt);

        address[] memory residualRecipientAcc = new address[](4);
        uint256[] memory residualRecipientAmt = new uint256[](4);

        residualRecipientAcc[0] = address(IZivoeGlobals_YDL(GBL).stJTT());
        residualRecipientAmt[0] = 2500;
        residualRecipientAcc[1] = address(IZivoeGlobals_YDL(GBL).stSTT());
        residualRecipientAmt[1] = 500;
        residualRecipientAcc[2] = address(IZivoeGlobals_YDL(GBL).stZVE());
        residualRecipientAmt[2] = 4500;
        residualRecipientAcc[3] = address(IZivoeGlobals_YDL(GBL).DAO());
        residualRecipientAmt[3] = 2500;

        residualRecipients = Recipients(residualRecipientAcc, residualRecipientAmt);
    }

    /// @notice Updates the distributed asset for this particular contract.
    /// @param  _distributedAsset The new value for distributedAsset.
    function updateDistributedAsset(address _distributedAsset) external nonReentrant {
        require(
            _distributedAsset != distributedAsset, 
            "ZivoeYDL::updateDistributedAsset() _distributedAsset == distributedAsset"
        );
        require(
            _msgSender() == IZivoeGlobals_YDL(GBL).TLC(), 
            "ZivoeYDL::updateDistributedAsset() _msgSender() != TLC()"
        );
        require(
            IZivoeGlobals_YDL(GBL).stablecoinWhitelist(_distributedAsset),
            "ZivoeYDL::updateDistributedAsset() !IZivoeGlobals_YDL(GBL).stablecoinWhitelist(_distributedAsset)"
        );
        emit UpdatedDistributedAsset(distributedAsset, _distributedAsset);
        distributedAsset = _distributedAsset;
    }

    /// @notice Updates the state variable "protocolEarningsRateBIPS".
    /// @param  _protocolEarningsRateBIPS The new value for protocolEarningsRateBIPS.
    function updateProtocolEarningsRateBIPS(uint256 _protocolEarningsRateBIPS) external {
        require(
            _msgSender() == IZivoeGlobals_YDL(GBL).TLC(), 
            "ZivoeYDL::updateProtocolEarningsRateBIPS() _msgSender() != TLC()"
        );
        require(
            _protocolEarningsRateBIPS <= 9000, 
            "ZivoeYDL::updateProtocolEarningsRateBIPS() _protocolEarningsRateBIPS > 9000"
        );
        emit UpdatedProtocolEarningsRateBIPS(protocolEarningsRateBIPS, _protocolEarningsRateBIPS);
        protocolEarningsRateBIPS = _protocolEarningsRateBIPS;
    }

    /// @notice Updates the protocolRecipients or residualRecipients.
    /// @param  recipients An array of addresses to which protocol earnings will be distributed.
    /// @param  proportions An array of ratios relative to the recipients - in BIPS. Sum should equal to 10000.
    function updateRecipients(address[] memory recipients, uint256[] memory proportions, bool protocol) external {
        require(_msgSender() == IZivoeGlobals_YDL(GBL).TLC(), "ZivoeYDL::updateRecipients() _msgSender() != TLC()");
        require(
            recipients.length == proportions.length && recipients.length > 0, 
            "ZivoeYDL::updateRecipients() recipients.length != proportions.length || recipients.length == 0"
        );
        require(unlocked, "ZivoeYDL::updateRecipients() !unlocked");

        uint256 proportionTotal;
        for (uint256 i = 0; i < recipients.length; i++) {
            proportionTotal += proportions[i];
            require(proportions[i] > 0, "ZivoeYDL::updateRecipients() proportions[i] == 0");
            require(recipients[i] != address(0), "ZivoeYDL::updateRecipients() recipients[i] == address(0)");
        }

        require(proportionTotal == BIPS, "ZivoeYDL::updateRecipients() proportionTotal != BIPS (10,000)");
        if (protocol) {
            emit UpdatedProtocolRecipients(recipients, proportions);
            protocolRecipients = Recipients(recipients, proportions);
        }
        else {
            emit UpdatedResidualRecipients(recipients, proportions);
            residualRecipients = Recipients(recipients, proportions);
        }
    }

    /// @notice Updates the state variable "targetAPYBIPS".
    /// @param  _targetAPYBIPS The new value for targetAPYBIPS.
    function updateTargetAPYBIPS(uint256 _targetAPYBIPS) external {
        require(_msgSender() == IZivoeGlobals_YDL(GBL).TLC(), "ZivoeYDL::updateTargetAPYBIPS() _msgSender() != TLC()");
        emit UpdatedTargetAPYBIPS(targetAPYBIPS, _targetAPYBIPS);
        targetAPYBIPS = _targetAPYBIPS;
    }

    /// @notice Updates the state variable "targetRatioBIPS".
    /// @param  _targetRatioBIPS The new value for targetRatioBIPS.
    function updateTargetRatioBIPS(uint256 _targetRatioBIPS) external {
        require(_msgSender() == IZivoeGlobals_YDL(GBL).TLC(), "ZivoeYDL::updateTargetRatioBIPS() _msgSender() != TLC()");
        emit UpdatedTargetRatioBIPS(targetRatioBIPS, _targetRatioBIPS);
        targetRatioBIPS = _targetRatioBIPS;
    }



    // ----------
    //    Math
    // ----------

    /// @notice Calculates the distribution of yield ("earnings") for the four primary groups.
    /// @param  yP Yield for the protocol.
    /// @param  yD Yield for the remaining three groups.
    /// @return protocol Protocol earnings.
    /// @return senior Senior tranche earnings.
    /// @return junior Junior tranche earnings.
    /// @return residual Residual earnings.
    function earningsTrancheuse(uint256 yP, uint256 yD) public view returns (
        uint256[] memory protocol, uint256 senior, uint256 junior, uint256[] memory residual
    ) {
        protocol = new uint256[](protocolRecipients.recipients.length);
        residual = new uint256[](residualRecipients.recipients.length);
        
        // Accounting for protocol earnings.
        for (uint256 i = 0; i < protocolRecipients.recipients.length; i++) {
            protocol[i] = protocolRecipients.proportion[i] * yP / BIPS;
        }

        // Accounting for senior and junior earnings.
        uint256 _seniorProportion = MATH.seniorProportion(
            IZivoeGlobals_YDL(GBL).standardize(yD, distributedAsset),
            MATH.yieldTarget(emaSTT, emaJTT, targetAPYBIPS, targetRatioBIPS, daysBetweenDistributions),
            emaSTT, emaJTT, targetAPYBIPS, targetRatioBIPS, daysBetweenDistributions
        );
        senior = (yD * _seniorProportion) / RAY;
        junior = (yD * MATH.juniorProportion(emaSTT, emaJTT, _seniorProportion, targetRatioBIPS)) / RAY;
        
        // Handle accounting for residual earnings.
        yD = yD.floorSub(senior + junior);
        for (uint256 i = 0; i < residualRecipients.recipients.length; i++) {
            residual[i] = residualRecipients.proportion[i] * yD / BIPS;
        }
    }

}

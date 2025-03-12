// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { IERC20, ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "../interfaces/IRadiantStaking.sol";
import "../interfaces/IBaseRewardPool.sol";
import "../libraries/RadiantUtilLib.sol";
import "../interfaces/IRDNTRewardManager.sol";

import "../interfaces/radiant/ILendingPool.sol";
import "../interfaces/radiant/IChefIncentivesController.sol";
import "../interfaces/radiant/IEligibilityDataProvider.sol";

/// @title RewardHelper
/// @dev RewardHelper is the helper contract that help radiantstaking contract to send user rewards into the RDNTRewardManager for distribution
/// @author Magpie Team

contract RewardDistributor is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using SafeERC20 for IERC20;

    /* ============ Structs ============ */

    struct Fees {
        uint256 value; // allocation denominated by DENOMINATOR
        address to;
        bool isAddress;
        bool isActive;
    }

    struct StreamingFeeState {
        uint256 streamingFeePercentage; // Percent of Set accruing to manager annually, denominated by DENOMINATOR
        uint256 lastStreamingFeeTimestamp; // Timestamp last streaming fee was accrued
    }

    address public rdnt;
    ILendingPool public lendingPool;
    IMultiFeeDistribution public multiFeeDistributor;
    IChefIncentivesController public chefIncentivesController;
    IEligibilityDataProvider public eligibilityDataProvider;

    IRadiantStaking public radiantStaking;
    IRDNTRewardManager public rdntRewardManager;

    /* ============ State Variables ============ */

    // Lp Fees

    uint256 public totalRDNTFee; // total fee percentage for RDNT token reward
    uint256 public totalRTokenFee; // total fee percentage for revenue share reward (such as rWBTC, rWETH, rUSDC etc)
    Fees[] public radiantFeeInfos; // info of RDNT reward fee and destination (For rewards from liquidity,borrowing on Radiant)
    Fees[] public rTokenFeeInfos; // info of rTokens reward fee and destination (For rewards from locked dlp on Radiant)

    // Management streaming fee
    mapping(address => StreamingFeeState) public streamingFeeInfos; // streaming fee info by receipt token for Radiant pools

    uint256 public constant ONE_YEAR_IN_SECONDS = 365.25 days;
    uint256 public constant DENOMINATOR = 10000;

    /* ============ Errors ============ */

    error InvalidFee();
    error InvalidIndex();
    error OnlyRewardQeuer();
    error ExceedsDenominator();
    /* ============ Events ============ */

    // Fee
    event AddFee(address _to, uint256 _value, bool _isForRDNT, bool _isAddress);
    event SetFee(address _to, uint256 _value, bool _isForRDNT);
    event RemoveFee(uint256 value, address to, bool _isAddress, bool _isForRDNT);
    event EntitledRDNT(address _asset, uint256 _feeAmount);
    event RewardPaidTo(
        address _rewardSource,
        address _to,
        address _rewardToken,
        uint256 _feeAmount
    );
    event RewardFeeDustTo(address _reward, address _to, uint256 _amount);
    event StreamingFeeDataSet(
        address _radpieReceipt,
        uint256 _streamingFeePercentage,
        uint256 _lastStreamingFeeTimestamp
    );
    event lastStreamingFeeTimestampUpdated(
        address _radpieReceipt,
        uint256 _lastStreamingFeeTimestamp
    );

    /* ============ Modifiers ============ */

    modifier _onlyRewardQeuer() {
        if (msg.sender != address(radiantStaking)) revert OnlyRewardQeuer();
        _;
    }

    /* ============ Constructor ============ */

    function __RewardDistributor_init(
        address _rdnt,
        address _rdntRewardManager,
        address _radiantStaking,
        address _lendingPool,
        address _multiFeeDistributor,
        address _chefIncentivesController,
        address _eligibilityDataProvider
    ) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        rdnt = _rdnt;
        lendingPool = ILendingPool(_lendingPool);
        multiFeeDistributor = IMultiFeeDistribution(_multiFeeDistributor);
        radiantStaking = IRadiantStaking(_radiantStaking);
        rdntRewardManager = IRDNTRewardManager(_rdntRewardManager);
        chefIncentivesController = IChefIncentivesController(_chefIncentivesController);
        eligibilityDataProvider = IEligibilityDataProvider(_eligibilityDataProvider);
    }

    /* ============ External Read Function ============ */

    /// @dev Radpie's locked dlp amount on Radiant
    function getTotalDlpLocked() external view returns (uint256) {
        (uint256 totalLocked, , , , ) = IMultiFeeDistribution(multiFeeDistributor).lockedBalances(
            address(radiantStaking)
        );
        return totalLocked;
    }

    /// @dev claimable rTokens reward for locked dlp on Radiant
    function claimableDlpRewards()
        external
        view
        returns (address[] memory _rewardTokens, uint256[] memory _amounts)
    {
        return RadiantUtilLib.claimableDlpRewards(multiFeeDistributor, address(radiantStaking));
    }

    /// @dev To return claimable and pending RDNT reward of RadiantStaking on Radiant ChefIncentiveContoler.
    // _tokens should be rToken or vdTokens
    function claimableAndPendingRDNT(
        address[] calldata _tokens
    )
        external
        view
        returns (uint256 claimable, uint256[] memory pendings, uint256 vesting, uint256 vested)
    {
        return
            RadiantUtilLib.rdntRewardStats(
                chefIncentivesController,
                multiFeeDistributor,
                address(radiantStaking),
                _tokens
            );
    }

    function rdntRewardEligibility()
        external
        view
        returns (
            bool isEligibleForRDNT,
            uint256 lockedDLPUSD,
            uint256 totalCollateralUSD,
            uint256 requiredDLPUSD,
            uint256 requiredDLPUSDWithTolerance
        )
    {
        return
            RadiantUtilLib.rdntEligibility(
                eligibilityDataProvider,
                lendingPool,
                address(radiantStaking)
            );
    }

    function getCalculatedStreamingFeePercentage(
        address _radpieReceipt
    ) public view returns (uint256) {
        uint256 timeSinceLastFee = block.timestamp -
            (streamingFeeInfos[_radpieReceipt].lastStreamingFeeTimestamp);

        return
            (timeSinceLastFee * (streamingFeePercentage(_radpieReceipt))) / (ONE_YEAR_IN_SECONDS);
    }

    function calculateStreamingFeeInflation(
        address receiptToken,
        uint256 _feePercentage
    ) external view returns (uint256) {
        uint256 totalSupply = IERC20(receiptToken).totalSupply();
        if (totalSupply != 0 && _feePercentage != 0) {
            uint256 a = _feePercentage * (totalSupply);
            uint256 b = DENOMINATOR - (_feePercentage);
            return a / b;
        }
        return 0;
    }

    function streamingFeePercentage(address _radpieReceipt) public view returns (uint256) {
        return streamingFeeInfos[_radpieReceipt].streamingFeePercentage;
    }

    /* ============ External Write Function ============ */

    /// @dev Queue Entitled RDNT reward to rewarder for an asset. Entitled rewarder RDNT are not in vesting nor vested yet, user will have to
    /// Explicitly start vesting for their Entitled RDNT reward.
    /// Basicall the pending RDNT token on Radiant.
    /// @param _amount the entitled amount of RDNT
    /// @param _receipt receipt token for the asset deposited on Radpie.
    function enqueueEntitledRDNT(
        address _receipt,
        uint256 _amount
    ) external nonReentrant _onlyRewardQeuer {
        uint256 originalRewardAmount = _amount;
        for (uint256 i = 0; i < radiantFeeInfos.length; i++) {
            Fees storage feeInfo = radiantFeeInfos[i];
            if (feeInfo.isActive) {
                uint256 feeAmount = (originalRewardAmount * feeInfo.value) / DENOMINATOR;
                _amount -= feeAmount;
                uint256 feeTosend = feeAmount;

                IRDNTRewardManager(rdntRewardManager).queueEntitledRDNT(feeInfo.to, feeTosend);

                emit EntitledRDNT(feeInfo.to, feeTosend);
            }
        }

        IRDNTRewardManager(rdntRewardManager).queueEntitledRDNT(_receipt, _amount);
        emit EntitledRDNT(_receipt, _amount);
    }

    /// @dev Send rewards to the rewarders
    /// @param _rewardToken the address of the reward token to send
    /// @param _amount total reward amount to distribute
    function sendRewards(
        address _rewardSource,
        address _rewardToken,
        uint256 _amount
    ) external nonReentrant _onlyRewardQeuer {
        IERC20(_rewardToken).safeTransferFrom(msg.sender, address(this), _amount);

        for (uint256 i = 0; i < rTokenFeeInfos.length; i++) {
            uint256 feeAmount = (_amount * rTokenFeeInfos[i].value) / DENOMINATOR;
            uint256 feeTosend = feeAmount;

            if (!rTokenFeeInfos[i].isAddress) {
                IERC20(_rewardToken).safeApprove(rTokenFeeInfos[i].to, feeTosend);
                IBaseRewardPool(rTokenFeeInfos[i].to).queueNewRewards(feeTosend, _rewardToken);
            } else {
                IERC20(_rewardToken).safeTransfer(rTokenFeeInfos[i].to, feeTosend);
            }

            emit RewardPaidTo(_rewardSource, rTokenFeeInfos[i].to, _rewardToken, feeTosend);
        }

        // if there is somehow reward left, sent it to owner
        uint256 rewardLeft = IERC20(_rewardToken).balanceOf(address(this));
        if (rewardLeft > 0) {
            IERC20(_rewardToken).safeTransfer(owner(), rewardLeft);
            emit RewardFeeDustTo(_rewardToken, owner(), rewardLeft);
        }
    }

    function updatelastStreamingLastFeeTimestamp(
        address _radpieReceipt,
        uint256 _updatedLastStreamingTime
    ) external _onlyRewardQeuer {
        StreamingFeeState storage feeInfo = streamingFeeInfos[_radpieReceipt];

        feeInfo.lastStreamingFeeTimestamp = _updatedLastStreamingTime;

        emit lastStreamingFeeTimestampUpdated(_radpieReceipt, _updatedLastStreamingTime);
    }

    /* ============ Admin Functions ============ */

    /// @dev This function adds a fee to the Radpie protocol
    /// @param _value the initial value for that fee
    /// @param _to the address or contract that receives the fee
    /// @param _isAddress true if the receiver is an address, otherwise it's a BaseRewarder
    function addFee(
        uint256 _value,
        address _to,
        bool _isForRDNT,
        bool _isAddress
    ) external onlyOwner {
        if (_value > DENOMINATOR) revert InvalidFee();

        uint256 totalFee;
        Fees[] storage feeInfos;

        if (_isForRDNT) {
            feeInfos = radiantFeeInfos;
            totalFee = totalRDNTFee;
        } else {
            feeInfos = rTokenFeeInfos;
            totalFee = totalRTokenFee;
        }

        if (totalFee + _value > DENOMINATOR) revert ExceedsDenominator();

        feeInfos.push(Fees({ value: _value, to: _to, isAddress: _isAddress, isActive: true }));

        if (_isForRDNT) {
            totalRDNTFee += _value;
        } else {
            totalRTokenFee += _value;
        }

        emit AddFee(_to, _value, _isForRDNT, _isAddress);
    }

    /// @dev change the value of some fee
    /// @dev the value must be between the min and the max specified when registering the fee
    /// @dev the value must match the max fee requirements
    /// @param _index the index of the fee in the fee list
    /// @param _value the new value of the fee
    /// @param _isRDNTFee true if the fee is for RDNT, false if it is for rToken
    function setFee(
        uint256 _index,
        uint256 _value,
        address _to,
        bool _isRDNTFee,
        bool _isAddress,
        bool _isActive
    ) external onlyOwner {
        if (_value > DENOMINATOR) revert InvalidFee();

        Fees[] storage feeInfo;
        if (_isRDNTFee) feeInfo = radiantFeeInfos;
        else feeInfo = rTokenFeeInfos;

        if (_index > feeInfo.length) revert InvalidIndex();

        Fees storage fee = feeInfo[_index];
        fee.to = _to;
        fee.isAddress = _isAddress;
        fee.isActive = _isActive;

        uint256 currentTotalFee = _isRDNTFee ? totalRDNTFee : totalRTokenFee;
        uint256 updatedTotalFee = currentTotalFee - feeInfo[_index].value + _value;

        if (updatedTotalFee > DENOMINATOR) {
            revert ExceedsDenominator();
        }

        if (_isRDNTFee) totalRDNTFee = updatedTotalFee;
        else totalRTokenFee = updatedTotalFee;

        fee.value = _value;

        emit SetFee(_to, _value, _isRDNTFee);
    }

    /// @dev remove some fee
    /// @param _index the index of the fee in the fee list
    /// @param _isRDNTFee true if the fee is for RDNT, false if it is for rToken
    function removeFee(uint256 _index, bool _isRDNTFee) external onlyOwner {
        Fees[] storage feeInfos;

        if (_isRDNTFee) {
            feeInfos = radiantFeeInfos;
            if (_index >= feeInfos.length) revert InvalidIndex();
            totalRDNTFee = totalRDNTFee - feeInfos[_index].value;
        } else {
            feeInfos = rTokenFeeInfos;
            if (_index >= feeInfos.length) revert InvalidIndex();
            totalRTokenFee = totalRTokenFee - feeInfos[_index].value;
        }

        Fees memory feeToRemove = feeInfos[_index];

        for (uint256 i = _index; i < feeInfos.length - 1; i++) {
            feeInfos[i] = feeInfos[i + 1];
        }

        feeInfos.pop();

        emit RemoveFee(feeToRemove.value, feeToRemove.to, feeToRemove.isAddress, _isRDNTFee);
    }

    function setStreamingFeeData(
        address _radpieReceipt,
        uint256 _streamingFeePercentage
    ) external onlyOwner {
        StreamingFeeState storage feeInfo = streamingFeeInfos[_radpieReceipt];

        if (feeInfo.streamingFeePercentage >= DENOMINATOR) revert InvalidFee();

        feeInfo.streamingFeePercentage = _streamingFeePercentage;
        feeInfo.lastStreamingFeeTimestamp = block.timestamp;

        emit StreamingFeeDataSet(
            _radpieReceipt,
            _streamingFeePercentage,
            feeInfo.lastStreamingFeeTimestamp
        );
    }
}

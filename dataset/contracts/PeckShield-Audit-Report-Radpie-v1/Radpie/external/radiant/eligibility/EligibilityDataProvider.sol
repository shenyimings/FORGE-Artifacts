// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../../../interfaces/radiant/ILendingPool.sol";
import "../../../interfaces/radiant/IMultiFeeDistribution.sol";
import "../../../interfaces/radiant/IChefIncentivesController.sol";
import "../../../interfaces/radiant/IPriceProvider.sol";
import "../../../interfaces/radiant/IMiddleFeeDistribution.sol";
import "../../../interfaces/radiant/LockedBalance.sol";


/// @title Eligible Deposit Provider
/// @author Radiant Labs
/// @dev All function calls are currently implemented without side effects
contract EligibilityDataProvider is OwnableUpgradeable {
    using SafeMath for uint256;

    /********************** Common Info ***********************/

    /// @notice RATIO BASE equal to 100%
    uint256 public constant RATIO_DIVISOR = 10000;

    /// @notice Address of Lending Pool
    ILendingPool public lendingPool;

    /// @notice Address of CIC
    IChefIncentivesController public chef;

    /// @notice Address of Middle fee distribution
    IMiddleFeeDistribution public middleFeeDistribution;

    /// @notice RDNT + LP price provider
    IPriceProvider public priceProvider;

    /// @notice Required ratio of TVL to get reward; in bips
    uint256 public requiredDepositRatio;

    /// @notice Ratio of the required price to still allow without disqualification; in bips
    uint256 public priceToleranceRatio;

    /// @notice RDNT-ETH LP token
    address public lpToken;

    /********************** Eligible info ***********************/

    /// @notice Last eligible status of the user
    mapping(address => bool) public lastEligibleStatus;

    /// @notice Disqualified time of the user
    mapping(address => uint256) public disqualifiedTime;

    // Elgible deposits per rToken
    mapping(address => uint256) private eligibleDeposits;

    /// @notice User's deposits per rToken; rToken => user => amount
    mapping(address => mapping(address => uint256)) public userDeposits;

    /********************** Events ***********************/

    /// @notice Emitted when CIC is set
    event ChefIncentivesControllerUpdated(IChefIncentivesController _chef);

    /// @notice Emitted when LP token is set
    event LPTokenUpdated(address _lpToken);

    /// @notice Emitted when required TVL ratio is updated
    event RequiredDepositRatioUpdated(uint256 requiredDepositRatio);

    /// @notice Emitted when price tolerance ratio is updated
    event PriceToleranceRatioUpdated(uint256 priceToleranceRatio);

    /// @notice Emitted when DQ time is set
    event DqTimeUpdated(address _user, uint256 _time);

    /// @notice Emitted when a new token is added
    event AddToken(address indexed token);

    /**
     * @notice Constructor
     * @param _lendingPool Address of lending pool.
     * @param _middleFeeDistribution MiddleFeeDistribution address.
     * @param _priceProvider PriceProvider address.
     */
    constructor(
        ILendingPool _lendingPool,
        IMiddleFeeDistribution _middleFeeDistribution,
        IPriceProvider _priceProvider
    ) {
        lendingPool = _lendingPool;
        middleFeeDistribution = _middleFeeDistribution;
        priceProvider = _priceProvider;
        requiredDepositRatio = 500;
        priceToleranceRatio = 9000;
    }

    /********************** Setters ***********************/

    /**
     * @notice Set CIC
     * @param _chef address.
     */
    function setChefIncentivesController(IChefIncentivesController _chef) external {
        require(address(_chef) != address(0), "chef is 0 address");
        chef = _chef;
        emit ChefIncentivesControllerUpdated(_chef);
    }

    /**
     * @notice Set LP token
     */
    function setLPToken(address _lpToken) external onlyOwner {
        require(lpToken == address(0), "LP token already set");
        lpToken = _lpToken;

        emit LPTokenUpdated(_lpToken);
    }

    /**
     * @notice Sets required tvl ratio. Can only be called by the owner.
     * @param _requiredDepositRatio Ratio in bips.
     */
    function setRequiredDepositRatio(uint256 _requiredDepositRatio) external onlyOwner {
        require(_requiredDepositRatio <= RATIO_DIVISOR, "Invalid ratio");
        requiredDepositRatio = _requiredDepositRatio;

        emit RequiredDepositRatioUpdated(_requiredDepositRatio);
    }

    /**
     * @notice Sets price tolerance ratio. Can only be called by the owner.
     * @param _priceToleranceRatio Ratio in bips.
     */
    function setPriceToleranceRatio(uint256 _priceToleranceRatio) external onlyOwner {
        require(
            _priceToleranceRatio >= 8000 && _priceToleranceRatio <= RATIO_DIVISOR,
            "Invalid ratio"
        );
        priceToleranceRatio = _priceToleranceRatio;

        emit PriceToleranceRatioUpdated(_priceToleranceRatio);
    }

    /**
     * @notice Sets DQ time of the user
     * @dev Only callable by CIC
     * @param _user's address
     * @param _time for DQ
     */
    function setDqTime(address _user, uint256 _time) external {
        require(msg.sender == address(chef), "Only CIC");
        disqualifiedTime[_user] = _time;

        emit DqTimeUpdated(_user, _time);
    }

    /********************** View functions ***********************/

    /**
     * @notice Returns locked RDNT and LP token value in eth
     * @param user's address
     */
    function lockedUsdValue(address user) public view returns (uint256) {
        IMultiFeeDistribution multiFeeDistribution = IMultiFeeDistribution(
            middleFeeDistribution.getMultiFeeDistributionAddress()
        );
        (, , uint256 lockedLP, , ) = multiFeeDistribution.lockedBalances(user);
        return _lockedUsdValue(lockedLP);
    }

    /**
     * @notice Returns USD value required to be locked
     * @param user's address
     * @return required USD value.
     */
    function requiredUsdValue(address user) public view returns (uint256 required) {
        (uint256 totalCollateralUSD, , , , , ) = lendingPool.getUserAccountData(user);
        required = totalCollateralUSD.mul(requiredDepositRatio).div(RATIO_DIVISOR);
    }

    /**
     * @notice Is user DQed due to lock expire or price update
     * @param _user's address
     */
    function isMarketDisqualified(address _user) public view returns (bool) {
        return
            requiredUsdValue(_user) > 0 &&
            !isEligibleForRewards(_user) &&
            lastEligibleTime(_user) > block.timestamp;
    }

    /**
     * @notice Returns if the user is eligible to receive rewards
     * @param _user's address
     */
    function isEligibleForRewards(address _user) public view returns (bool isEligible) {
        uint256 lockedValue = lockedUsdValue(_user);
        uint256 requiredValue = requiredUsdValue(_user).mul(priceToleranceRatio).div(RATIO_DIVISOR);
        return requiredValue != 0 && lockedValue >= requiredValue;
    }

    /**
     * @notice Returns DQ time of the user
     * @param _user's address
     */
    function getDqTime(address _user) public view returns (uint256) {
        return disqualifiedTime[_user];
    }

    /**
     * @notice Returns last eligible time of the user
     * @dev If user is still eligible, it will return future time
     *  CAUTION: this function only works perfect when the array
     *  is ordered by lock time. This is assured when _stake happens.
     * @param user's address
     */
    function lastEligibleTime(address user) public view returns (uint256 lastEligibleTimestamp) {
        uint256 requiredValue = requiredUsdValue(user);

        IMultiFeeDistribution multiFeeDistribution = IMultiFeeDistribution(
            middleFeeDistribution.getMultiFeeDistributionAddress()
        );
        LockedBalance[] memory lpLockData = multiFeeDistribution.lockInfo(user);

        uint256 lockedLP;
        uint256 i = lpLockData.length;
        while (i > 0) {
            i = i - 1;
            lastEligibleTimestamp = lpLockData[i].unlockTime;
            lockedLP = lockedLP + lpLockData[i].amount;

            if (_lockedUsdValue(lockedLP) >= requiredValue) {
                break;
            }
        }
    }

    /********************** Operate functions ***********************/
    /**
     * @notice Refresh token amount for eligibility
     * @param user's address
     */
    function refresh(address user) external {
        require(msg.sender == address(chef), "Can only be called by CIC");
        assert(user != address(0));

        bool currentEligble = isEligibleForRewards(user);
        if (currentEligble && disqualifiedTime[user] != 0) {
            disqualifiedTime[user] = 0;
        }
        lastEligibleStatus[user] = currentEligble;
    }

    /**
     * @notice Update token price
     */
    function updatePrice() public {
        // priceProvider.update();
    }

    /********************** Internal functions ***********************/

    /**
     * @notice Returns locked RDNT and LP token value in eth
     * @param lockedLP is locked lp amount
     */
    function _lockedUsdValue(uint256 lockedLP) internal view returns (uint256) {
        uint256 lpPrice = 133732741; //priceProvider.getLpTokenPriceUsd();
        return lockedLP.mul(lpPrice).div(10 ** 18);
    }
}

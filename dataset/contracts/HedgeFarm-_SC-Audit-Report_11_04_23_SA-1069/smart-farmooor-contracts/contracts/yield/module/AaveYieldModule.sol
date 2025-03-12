// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./BaseModule.sol";
import {IPool as IPoolAave} from "../interface/aave/IPool.sol";
import "../interface/aave/IRewardsController.sol";
import "../interface/aave/IScaledBalanceToken.sol";
import "../interface/aave/WadRayMath.sol";

/**
 * @author  HedgeFarm team
 * @title   Aave Yield module
 * @dev     The Aave module is reponsible for interacting with the Aave lending protocol
 * @notice  Upgradability is needed because Aave protocol is built with Proxy - it's implementation could be updated
 */

contract AaveYieldModule is BaseModule {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using WadRayMath for uint256;

    /// @dev A constant specific to Aave
    uint16 private constant REFERRAL_CODE = 0;
    /// @dev A constant used for calculating shares
    uint256 private constant IOU_DECIMALS_EXP = 1e18;

    /// @dev The list of params needed to initialise the module
    struct AaveParams {
        address _pool;
        address _poolDataProvider;
        address _rewardsController;
        address _aToken;
    }

    /// @notice The Aave pool contract
    address public pool;
    /// @notice The Aave pool data provider contract
    address public poolDataProvider;
    /// @notice The Aave rewards controller
    address public rewardsController;
    /// @notice The aave aToken contract used by the module
    address public aToken;
    /// @notice The last price per share used by the harvest
    uint256 public lastPricePerShare;

    /** proxy **/

    /**
     * @notice  Initializes
     * @dev     Should always be called on deployment
     * @param   _smartFarmooor  Smart Farmooor of the Module
     * @param   _manager  Manager of the Module
     * @param   _baseToken  Asset contract address
     * @param   _executionFee  Execution fee for withdrawals
     * @param   _dex  Dex Router contract address
     * @param   _rewards  Reward contract addresses
     * @param   _params Aave configuration parameters
     * @param   _name  Name of the Module
     * @param   _wrappedNative  Address of the Wrapped Native token
     */
    function initialize(
        address _smartFarmooor,
        address _manager,
        address _baseToken,
        uint256 _executionFee,
        address _dex,
        address[] memory _rewards,
        AaveParams memory _params,
        string memory _name,
        address _wrappedNative
    ) public initializer {
        _initializeBase(_smartFarmooor, _manager, _baseToken, _executionFee, _dex, _rewards, _name, _wrappedNative);

        pool = _params._pool;
        poolDataProvider = _params._poolDataProvider;
        rewardsController = _params._rewardsController;
        aToken = _params._aToken;
        lastPricePerShare = IPoolAave(pool).getReserveNormalizedIncome(_baseToken);

        IERC20Upgradeable(_baseToken).safeApprove(_params._pool, type(uint256).max);
    }

    /** manager **/

    /**
     * @notice  Deposit Base token into Aave - provide liquidity
     * @param   amount  Amount of Base token to be deposited
     */
    function deposit(uint256 amount) external onlySmartFarmooor {
        require(amount > 0, "Aave: deposit amount cannot be zero");
        IERC20Upgradeable(baseToken).safeTransferFrom(msg.sender, address(this), amount);
        IPoolAave(pool).supply(baseToken, amount, address(this), REFERRAL_CODE);
        emit Deposit(baseToken, amount);
    }

    /**
     * @notice  Withdraw Base token from Aave
     * @dev     Amount gets converted to shares for withdrawal
     * @param   shareFraction  Fraction representing user share of Base token to withdraw
     * @param   receiver  Receiver of the funds
     * @return  instant  Instant amount of Base token received
     * @return  pending  Pending amount of base token to be received
     */
    function withdraw(uint256 shareFraction, address receiver)
    external
    payable
    onlySmartFarmooor
    returns (uint256 instant, uint256 pending)
    {
        require(shareFraction > 0, "Aave: withdraw amount cannot be zero");
        require(msg.value == 0, "Aave: msg.value must be zero");
        uint256 totalShares = getBalance();
        uint256 sharesAmount = shareFraction * totalShares / IOU_DECIMALS_EXP;
        uint256 withdrawnAmount = IPoolAave(pool).withdraw(baseToken, sharesAmount, address(this));
        emit Withdraw(baseToken, withdrawnAmount);
        IERC20Upgradeable(baseToken).safeTransfer(receiver, withdrawnAmount);
        return (withdrawnAmount, 0);
    }

    /**
     * @notice  Harvest the rewards from Aave
     * @param   receiver  Receiver of the harvested rewards, in Base token
     * @return  uint256  Total profit harvested
     */
    function harvest(address receiver)
    external
    onlySmartFarmooor
    returns (uint256)
    {
        _lpProfit();
        _rewardsProfit();
        uint256 totalProfit = IERC20Upgradeable(baseToken).balanceOf(address(this));
        if (totalProfit != 0) {
            IERC20Upgradeable(baseToken).safeTransfer(receiver, totalProfit);
        }
        emit Harvest(baseToken, totalProfit);
        return totalProfit;
    }

    /**
     * @notice  Get current balance on Aave
     * @dev     Returns an amount in Base token
     * @return  uint256  Amount of base token
     */
    function getBalance() public view returns (uint256) {
        return IScaledBalanceToken(aToken).balanceOf(address(this));
    }

    /**
     * @notice  Get last updated balance on CompoundV2 fork
     * @dev     Returns an amount in Base token
     * @return  uint256  Amount of base token
     */
    function getLastUpdatedBalance() public view returns (uint256) {
        return getBalance();
    }

    /**
     * @notice  Get execution fee needed to withdraw from Aave
     * @dev     Returns an amount in native token
     * @return  uint256  Amount of native token
     */
    function getExecutionFee(uint256 shareFraction)
        external
        view
        override
        returns (uint256)
    {
        return executionFee;
    }

    /** helper **/

    /**
     * @notice  Calculates the profit - the extra Base token earned on top of aum
     */
    function _lpProfit() private {
        uint256 totalShares = IScaledBalanceToken(aToken).scaledBalanceOf(address(this));
        uint256 currentPricePerShare = IPoolAave(pool).getReserveNormalizedIncome(baseToken);
        require(currentPricePerShare >= lastPricePerShare, "Aave: module not profitable");
        uint256 lastAum = totalShares.rayMul(lastPricePerShare);
        uint256 currentAum = totalShares.rayMul(currentPricePerShare);
        uint256 aumDelta = currentAum - lastAum;
        if(aumDelta > 0) {
            IPoolAave(pool).withdraw(baseToken, aumDelta, address(this));
            lastPricePerShare = currentPricePerShare;
        }
    }

    /**
     * @notice  Collects the rewards tokens earned on CompoundV2 fork
     * @dev     Reward tokens are swapped for Base token
     */
    function _rewardsProfit() private {
        // Claim and swap rewards
        address[] memory assets = new address[](1);
        assets[0] = aToken;
        IRewardsController(rewardsController).claimAllRewardsToSelf(assets);
        uint256 rewardBalance = IERC20Upgradeable(rewards[0]).balanceOf(address(this));
        if (rewards[0] != baseToken) {
            IDex(dex).swap(rewardBalance, rewards[0], baseToken, address(this));
        }
    }

    /**
     * @notice  Aave lp token
     * @dev     overridden for aToken address which is aave lp token
     * @return  aToken address
     */
    function _lpToken() internal override view returns(address) {
        return aToken;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./BaseModule.sol";
import "../interface/stargate/IStargateRouter.sol";
import "../interface/stargate/ILpStaking.sol";
import {IPool as IPoolStargate} from "../interface/stargate/IPool.sol";

/**
 * @author  HedgeFarm team
 * @title   Stargate Yield module
 * @dev     The Stargate Yield module is responsible for interacting with the Stargate protocol and manage liquidity on it
 * @notice  Upgradability is needed because Stargate protocol is built with Proxy - it's implementation could be updated
 */

contract StargateYieldModule is BaseModule {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @dev A constant used for calculating shares
    uint256 constant private IOU_DECIMALS_EXP = 1e18;

    /// @dev The list of params needed to initialise the module
    struct StargateParams {
        address lpStaking;
        address stargateRouter;
        address pool;
        uint16 routerPoolId;
        uint16 redeemFromChainId;
        uint256 lpStakingPoolId;
        uint256 lpProfitWithdrawalThreshold;
    }

    /// @notice The Stargate staking contract
    address public lpStaking;
    /// @notice The Stargate router contract
    address public stargateRouter;
    /// @notice The Stargate pool contract
    address public pool;
    /// @notice The Stargate router pool id
    uint16 public routerPoolId;
    /// @notice The id of the chain used for async redeem
    uint16 public redeemFromChainId;
    /// @notice The Stargate staking pool id
    uint256 public lpStakingPoolId;
    /// @notice The threshold in base token to harvest lp profit
    uint256 public lpProfitWithdrawalThreshold;
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
     * @param   params  Stargate configuration parameters
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
        StargateParams memory params,
        string memory _name,
        address _wrappedNative
    ) public initializer {
        _initializeBase(_smartFarmooor, _manager, _baseToken, _executionFee, _dex, _rewards, _name, _wrappedNative);
        _setStargateRouter(params.stargateRouter);
        _setLpStaking(params.lpStaking);
        _setPool(params.pool);
        _setRouterPoolId(params.routerPoolId);
        _setRedeemFromChainId(params.redeemFromChainId);
        _setLpStakingPoolId(params.lpStakingPoolId);
        _setLpProfitWithdrawalThreshold(params.lpProfitWithdrawalThreshold);

        lastPricePerShare = IPoolStargate(pool).totalLiquidity() * _baseTokenDecimalsExp() / IPoolStargate(pool).totalSupply();
    }

    /** admin **/

    /**
     * @notice  Sets the Stargate PoolId
     * @dev     Often subject to changes
     * @param   _routerPoolId  New Id of the pool
     */
    function setRouterPoolId(uint16 _routerPoolId) external onlyOwnerOrManager {
        _setRouterPoolId(_routerPoolId);
    }

    /**
     * @notice  Sets the Stargate redeem Chain ID
     * @dev     Id of the chain where the funds could be withdrawn to
     * @param   _redeemFromChainId  New Chain Id for remote redeems
     */
    function setRedeemFromChainId(uint16 _redeemFromChainId) external onlyOwnerOrManager {
        _setRedeemFromChainId(_redeemFromChainId);
    }

    /**
     * @notice  Sets the Stargate stacking pool Id
     * @param   _lpStakingPoolId  New Stacking pool Id
     */
    function setLpStakingPoolId(uint256 _lpStakingPoolId) external onlyOwnerOrManager {
        _setLpStakingPoolId(_lpStakingPoolId);
    }

    /**
     * @notice  Sets the minimum LP profit threshold
     * @param   _lpProfitWithdrawalThreshold  Threshold amount in Base token
     */
    function setLpProfitWithdrawalThreshold(uint256 _lpProfitWithdrawalThreshold) external onlyOwnerOrManager {
        _setLpProfitWithdrawalThreshold(_lpProfitWithdrawalThreshold);
    }

    /** manager **/

    /**
     * @notice  Deposit Base token into Stargate - provide liquidity and stake the LP
     * @param   amount  Amount of Base token to be deposited
     */
    function deposit(uint256 amount) external onlySmartFarmooor {
        require(amount > 0, "Stargate: deposit amount cannot be zero");
        IERC20Upgradeable(baseToken).safeTransferFrom(msg.sender, address(this), amount);
        IStargateRouter(stargateRouter).addLiquidity(routerPoolId, amount, address(this));
        uint256 receivedLpToken = IERC20Upgradeable(pool).balanceOf(address(this));
        ILpStaking(lpStaking).deposit(lpStakingPoolId, receivedLpToken);
        emit Deposit(baseToken, amount);
    }

    /**
     * @notice  Withdraw Base token from Stargate
     * @dev     Amount gets converted to shares for withdrawal
     * @param   shareFraction  Fraction representing user share of Base token to withdraw
     * @param   receiver  Receiver of the funds
     * @return  instant  Instant amount of Base token received
     * @return  pending  Pending amount of base token to be received
     */
    function withdraw(uint256 shareFraction, address receiver) external payable onlySmartFarmooor returns (uint256 instant, uint256 pending) {
        require(shareFraction > 0, "Stargate: withdraw shareFraction cannot be zero");
        uint256 deltaCredit = _poolDeltaCredit();
        uint256 instantAmount = 0;
        uint256 pendingAmount = 0;
        uint256 withdrawalAmount = _amountFromShareFraction(shareFraction);
        if (withdrawalAmount <= deltaCredit) {
            instantAmount = _withdraw(withdrawalAmount, receiver, _syncRedeem);
            emit Withdraw(baseToken, instantAmount);
            return (instantAmount, pendingAmount);
        }
        pendingAmount = _withdraw(withdrawalAmount, receiver, _asyncRedeem);
        emit Withdraw(baseToken, pendingAmount);
        return (instantAmount, pendingAmount);
    }

    /**
     * @notice  Harvest the rewards from Stargate
     * @param   receiver  Receiver of the harvested rewards, in Base token
     * @return  uint256  Total profit harvested
     */
    function harvest(address receiver) external onlySmartFarmooor returns (uint256) {
        _lpProfit();
        _rewardsProfit();
        uint256 totalProfit = IERC20Upgradeable(baseToken).balanceOf(address(this));
        IERC20Upgradeable(baseToken).safeTransfer(receiver, totalProfit);
        emit Harvest(baseToken, totalProfit);
        return totalProfit;
    }

    /**
     * @notice  Get current balance on Stargate
     * @dev     Returns an amount in Base token
     * @return  uint256  Amount of base token
     */
    function getBalance() public view returns (uint256) {
        return IPoolStargate(pool).amountLPtoLD(_totalLpTokens());
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
     * @notice  Get execution fee needed to withdraw
     * @dev     Returns an amount in native token
     * @return  uint256  Amount of native token
     */
    function getExecutionFee(uint256 shareFraction) external view returns (uint256) {
        uint256 amount = _amountFromShareFraction(shareFraction);
        uint256 deltaCredit = _poolDeltaCredit();
        if (amount <= deltaCredit) {
            return 0;
        }
        return executionFee;
    }

    /** admin helper **/

    /**
     * @notice  Set Stargate lpStaking contract
     * @param   _lpStaking  Address of lpStaking contract
     */
    function _setLpStaking(address _lpStaking) private {
        require(_lpStaking != address(0), "Stargate: cannot be the zero address");
        lpStaking = _lpStaking;
    }

    /**
     * @notice  Set Stargate Router contract
     * @param   _stargateRouter  Address of Router contract
     */
    function _setStargateRouter(address _stargateRouter) private {
        require(_stargateRouter != address(0), "Stargate: cannot be the zero address");
        require(baseToken != address(0), "Stargate: baseToken not initialized");
        stargateRouter = _stargateRouter;
        IERC20Upgradeable(baseToken).safeApprove(_stargateRouter, type(uint256).max);

    }

    /**
     * @notice  Set Stargate Pool
     * @param   _pool  Address of Pool contract
     */
    function _setPool(address _pool) private {
        require(_pool != address(0), "Stargate: cannot be the zero address");
        require(lpStaking != address(0), "Stargate: lpStaking not initialized");
        pool = _pool;
        IERC20Upgradeable(_pool).safeApprove(lpStaking, type(uint256).max);
    }

    /**
     * @notice  Set Stargate PoolId
     * @param   _routerPoolId  Pool Id
     */
    function _setRouterPoolId(uint16 _routerPoolId) private {
        routerPoolId = _routerPoolId;
    }

    /**
     * @notice  Set Stargate Redeem chain Id
     * @param   _redeemFromChainId  Redeem Chain Id
     */
    function _setRedeemFromChainId(uint16 _redeemFromChainId) private {
        redeemFromChainId = _redeemFromChainId;
    }

    /**
     * @notice  Set Stargate Staking pool Id
     * @param   _lpStakingPoolId  Redeem Chain Id
     */
    function _setLpStakingPoolId(uint256 _lpStakingPoolId) private {
        lpStakingPoolId = _lpStakingPoolId;
    }

    /**
     * @notice  Set the minimum LP profit threshold
     * @param   _lpProfitWithdrawalThreshold  Threshold amount in Base token
     */
    function _setLpProfitWithdrawalThreshold(uint256 _lpProfitWithdrawalThreshold) private {
        require(baseToken != address(0), "Stargate: baseToken not initialized");
        require(_lpProfitWithdrawalThreshold >= _baseTokenDecimalsExp() , "Stargate: lpProfitWithdrawalThreshold must be at least 1 dollar");
        lpProfitWithdrawalThreshold = _lpProfitWithdrawalThreshold;
    }

    /** manager helper **/

    /**
     * @notice  Calculates the profit - the extra Base token earned on top of aum
     */
    function _lpProfit() private {
        uint256 currentPricePerShare = IPoolStargate(pool).totalLiquidity() * _baseTokenDecimalsExp() / IPoolStargate(pool).totalSupply();
        require(currentPricePerShare >= lastPricePerShare, "Stargate: currentPricePerShare smaller than last one");
        uint256 pricePerShareDelta = currentPricePerShare - lastPricePerShare;
        uint256 expectedLpProfit = pricePerShareDelta * _totalLpTokens() / _baseTokenDecimalsExp();
        // If profitable and can be redeemed instant
        if (expectedLpProfit > lpProfitWithdrawalThreshold && expectedLpProfit <= _poolDeltaCredit()) {
            _withdraw(expectedLpProfit, address(this), _syncRedeem);
            lastPricePerShare = currentPricePerShare;
        }
    }

    /**
     * @notice  Collects the rewards tokens earned on Stargate
     * @dev     Reward tokens are swapped for Base token
     */
    function _rewardsProfit() private {
        // deposit 0 claim the rewards
        ILpStaking(lpStaking).deposit(lpStakingPoolId, 0);
        uint256 stgBalance = IERC20Upgradeable(rewards[0]).balanceOf(address(this));
        IDex(dex).swap(stgBalance, rewards[0], baseToken, address(this));
    }

    /**
     * @notice  Withdraw Base token from Stargate
     * @dev     Amount gets converted to LP shares for withdrawal
     * @param   amount  Amount of Base token to withdraw
     * @param   receiver  Receiver of the funds
     * @return  Amount of Base token received
     */
    function _withdraw(uint256 amount, address receiver, function (uint256, address) internal redeem) private returns (uint256) {
        uint256 lpAmount = _totalLpTokens() * _fixoor(amount) / getBalance();
        // if delta credits ~ 0 we might try to withdraw 0 because of rounding
        if(lpAmount == 0) {
            return 0;
        }
        ILpStaking(lpStaking).withdraw(lpStakingPoolId, lpAmount);
        redeem(lpAmount, receiver);
        uint256 expectedAmount = IPoolStargate(pool).amountLPtoLD(lpAmount);
        return expectedAmount;
    }

    /**
     * @notice  Synchronous and instant withdraw from Stargate pool
     * @dev     When Stargate has enough delta credits, Withdrawals should be instant
     * @param   lpAmount  amount of Stargate LP to withdraw
     * @param   receiver  Receiver of the Base token
     */
    function _syncRedeem(uint256 lpAmount, address receiver) private {
        IStargateRouter(stargateRouter).instantRedeemLocal(routerPoolId, lpAmount, receiver);
    }

    /**
     * @notice  Asynchronous and delayed withdraw from Stargate pool
     * @dev     When Stargate does not have enough delta credits, Withdrawals are asynchronous
     * @param   lpAmount  amount of Stargate LP to withdraw
     * @param   receiver  Receiver of the Base token
     */
    function _asyncRedeem(uint256 lpAmount, address receiver) private {
        require(address(this).balance >= executionFee, "Stargate: cannot withdraw because msg.value < executionFee");
        IStargateRouter.lzTxObj memory lzTxObj = IStargateRouter.lzTxObj(0, 0, "0x");
        IStargateRouter(stargateRouter).redeemLocal{value : executionFee}(
            redeemFromChainId,
            routerPoolId, // src pool
            routerPoolId, // dst pool
            payable(receiver), // refund extra native gas to this address
            lpAmount,
            abi.encodePacked(receiver), // receiver
            lzTxObj
        );
    }

    /**
     * @notice  Get total Stargate Lp tokens staked
     * @return  uint256  Amount of Stargate Lp tokens
     */
    function _totalLpTokens() private view returns (uint256) {
        (uint256 amount,) = ILpStaking(lpStaking).userInfo(lpStakingPoolId, address(this));
        return amount;
    }

    /**
     * @notice  Amount of Delta credits available on Stargate Pool
     */
    function _poolDeltaCredit() internal virtual view returns(uint256) {
        return IPoolStargate(pool).deltaCredit();
    }

    /**
     * @notice  Stargate balance fixer - needed for 100% withdrawals
     * @dev     Stargate is not accurate enough to rely on Base token amount during withdrawals
     * @param   amount  Amount of Base token
     */
    function _fixoor(uint amount) private view returns(uint256) {
        if (amount > getBalance())
            return getBalance();
        return amount;
    }

    /**
     * @notice  Calculate amount of base tokens from given share fraction
     * @dev     share fraction that represents 1 (100%) is equal to IOU_DECIMALS so if fraction is bigger we just return the maximum value ( getBalance())
     * @param   shareFraction  fraction of user iou share
     */
    function _amountFromShareFraction(uint256 shareFraction) private view returns(uint256) {
        if(shareFraction > IOU_DECIMALS_EXP) {
            return getBalance();
        } else {
            return shareFraction * getBalance() / IOU_DECIMALS_EXP;
        }
    }

    /**
     * @notice  Exponentiation. 10 is base and decimals() is the exponent
     */
    function _baseTokenDecimalsExp() private view returns(uint256) {
        return 10 ** IERC20Metadata(baseToken).decimals();
    }

    /**
     * @notice  Stargate lp token
     * @dev     Pool is ERC20 contract which emits lp tokens
     * @return  pool ERC20 address
     */
    function _lpToken() internal override view returns(address) {
        return pool;
    }
}

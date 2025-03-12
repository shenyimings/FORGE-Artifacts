// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.19;

import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import "openzeppelin/utils/Address.sol";
import "openzeppelin/utils/math/SafeCast.sol";
import "openzeppelin/utils/Strings.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import "./BaseAdapter.sol";
import "../interfaces/IAdapter.sol";
import "../interfaces/IBalancer.sol";
import "../interfaces/velodrome/IPool.sol";
import "../interfaces/velodrome/IGauge.sol";

abstract contract VelodromePoolAdapter is BaseAdapter {

    using SafeERC20 for IERC20;

    IPool   public immutable POOL;
    IGauge  public immutable GAUGE;
    IERC20  public immutable TOKEN0;
    IERC20  public immutable TOKEN1;
    IERC20  public immutable REWARD_TOKEN;

    constructor(address _balancer, address _gauge) BaseAdapter(_balancer) {
        GAUGE = IGauge(_gauge);
        POOL = IPool(GAUGE.stakingToken());

        (address token0, address token1) = POOL.tokens();
        TOKEN0 = IERC20(token0);
        TOKEN1 = IERC20(token1);
        REWARD_TOKEN = IERC20(GAUGE.rewardToken());

        TOKEN0.approve(address(POOL), type(uint256).max);
        TOKEN1.approve(address(POOL), type(uint256).max);
        IERC20(address(POOL)).approve(address(GAUGE), type(uint256).max);
    }

    function _invest() internal override {
        uint deposit0;
        uint deposit1;
        {
            // Because pair requires a certain proportion of the tokens for the deposit we can't just deposit all
            // the tokens we have on our balance. We need to deposit them in accordance to the pair's ratio
            uint balance0 = TOKEN0.balanceOf(address(this));
            uint balance1 = TOKEN1.balanceOf(address(this));
            (uint reserve0, uint reserve1,) = POOL.getReserves();
            if(reserve0 == 0 || reserve1 == 0){
                revert ZeroReserveBalance(reserve0,reserve1);
            }

            deposit0 = balance0;
            deposit1 = deposit0 * reserve1 / reserve0;

            if (deposit1 > balance1) {
                deposit1 = balance1;
                deposit0 = deposit1 * reserve0 / reserve1;
            }
        }

        TOKEN0.safeTransfer(address(POOL), deposit0);
        TOKEN1.safeTransfer(address(POOL), deposit1);
        POOL.mint(address(this));
        GAUGE.deposit(POOL.balanceOf(address(this)));
    }

    function _redeem(uint lpAmount, address to)
        internal
        override
        returns (address[] memory tokens, uint[] memory amounts)
    {
        GAUGE.withdraw(lpAmount);
        POOL.transfer(address(POOL), lpAmount);
        (uint amount0, uint amount1) = POOL.burn(to);

        tokens = depositTokens();

        amounts = new uint[](2);
        amounts[0] = amount0;
        amounts[1] = amount1;
    }

    function _claimAll() internal override {
        GAUGE.getReward(address(this));
    }

    function value() public override view returns (uint _estimatedValue, uint _lps) {
        (uint reserve0, uint reserve1,) = POOL.getReserves();
        (uint value0, uint value1) = _values(reserve0, reserve1);

        _lps = GAUGE.balanceOf(address(this));
        _estimatedValue = (value0 + value1) * _lps / POOL.totalSupply();
    }

    function negotiableTokens() public virtual override returns(address[] memory tokens) {
        tokens = new address[](3);
        tokens[0] = address(TOKEN0);
        tokens[1] = address(TOKEN1);
        tokens[2] = address(REWARD_TOKEN);
    }

    function depositTokens() public override view returns (address[] memory tokens) {
        tokens = new address[](2);
        tokens[0] = address(TOKEN0);
        tokens[1] = address(TOKEN1);
    }

    /// @notice returns amount of pending rewards in the reward token
    /// @dev for offchain use
    function pendingRewards() external override view returns(address[] memory tokens, uint[] memory amounts) {
        tokens  = new address[](1);
        tokens[0] = address(REWARD_TOKEN);

        amounts = new uint[](1);
        amounts[0] = GAUGE.earned(address(this));
    }

    /// @dev for offchain use
    function ratios() external override view returns (address[] memory tokens, uint[] memory ratio) {
        tokens = depositTokens();
        ratio = new uint[](2);
        (ratio[0], ratio[1],) = POOL.getReserves();
    }

    /// @dev for offchain use
    function description() external view override returns (string memory) {
        return string.concat('{"type":"velodromeGauge","vaultAddress": "', Strings.toHexString(address(GAUGE)), '"}');
    }

    function _values(uint256 _amount0, uint256 _amount1) internal view virtual returns (uint256 _value0, uint256 _value1);

}
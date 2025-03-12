// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/connectors/contracts/stuff/Dodo.sol";
import "@overnight-contracts/connectors/contracts/stuff/Balancer.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";

contract StrategyDodoUsdc is Strategy, DodoExchange, BalancerExchange {
    using OvnMath for uint256;

    IERC20 public usdcToken;
    IERC20 public usdtToken;
    IERC20 public dodoToken;
    IERC20 public wmaticToken;
    IERC20 public usdcLPToken;

    IDODOV1 public dodoV1UsdcUsdtPool;
    IDODOV2 public dodoV2DodoUsdtPool;
    IDODOMine public dodoMine;
    bytes32 public balancerPoolIdWmaticUsdcWethBal;


    // --- events

    event StrategyUpdatedTokens(address usdcToken, address usdtToken, address dodoToken, address wmaticToken, address usdcLPToken);

    event StrategyUpdatedParams(address dodoV1UsdcUsdtPool, address dodoV2DodoUsdtPool, address dodoMine, address dodoV1Helper,
        address dodoProxy, address dodoApprove, address balancerVault, bytes32 balancerPoolIdWmaticUsdcWethBal);


    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }


    // --- Setters

    function setTokens(
        address _usdcToken,
        address _usdtToken,
        address _dodoToken,
        address _wmaticToken,
        address _usdcLPToken
    ) external onlyAdmin {

        require(_usdcToken != address(0), "Zero address not allowed");
        require(_usdtToken != address(0), "Zero address not allowed");
        require(_dodoToken != address(0), "Zero address not allowed");
        require(_wmaticToken != address(0), "Zero address not allowed");
        require(_usdcLPToken != address(0), "Zero address not allowed");

        usdcToken = IERC20(_usdcToken);
        usdtToken = IERC20(_usdtToken);
        dodoToken = IERC20(_dodoToken);
        wmaticToken = IERC20(_wmaticToken);
        usdcLPToken = IERC20(_usdcLPToken);

        emit StrategyUpdatedTokens(_usdcToken, _usdtToken, _dodoToken, _wmaticToken, _usdcLPToken);
    }

    function setParams(
        address _dodoV1UsdcUsdtPool,
        address _dodoV2DodoUsdtPool,
        address _dodoMine,
        address _dodoV1Helper,
        address _dodoProxy,
        address _dodoApprove,
        address _balancerVault,
        bytes32 _balancerPoolIdWmaticUsdcWethBal
    ) external onlyAdmin {

        require(_dodoV1UsdcUsdtPool != address(0), "Zero address not allowed");
        require(_dodoV2DodoUsdtPool != address(0), "Zero address not allowed");
        require(_dodoMine != address(0), "Zero address not allowed");
        require(_dodoV1Helper != address(0), "Zero address not allowed");
        require(_dodoProxy != address(0), "Zero address not allowed");
        require(_dodoApprove != address(0), "Zero address not allowed");
        require(_balancerPoolIdWmaticUsdcWethBal != "", "Empty pool id not allowed");

        dodoV1UsdcUsdtPool = IDODOV1(_dodoV1UsdcUsdtPool);
        dodoV2DodoUsdtPool = IDODOV2(_dodoV2DodoUsdtPool);
        dodoMine = IDODOMine(_dodoMine);
        _setDodoParams(_dodoV1Helper, _dodoProxy, _dodoApprove);
        setBalancerVault(_balancerVault);
        balancerPoolIdWmaticUsdcWethBal = _balancerPoolIdWmaticUsdcWethBal;

        emit StrategyUpdatedParams(_dodoV1UsdcUsdtPool, _dodoV2DodoUsdtPool, _dodoMine, _dodoV1Helper, _dodoProxy,
            _dodoApprove, _balancerVault, _balancerPoolIdWmaticUsdcWethBal);
    }


    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(usdcToken), "Some token not compatible");

        // stake all usdc tokens
        uint256 usdcTokenAmount = usdcToken.balanceOf(address(this));

        // add liquidity to pool
        usdcToken.approve(address(dodoV1UsdcUsdtPool), usdcTokenAmount);
        dodoV1UsdcUsdtPool.depositBaseTo(address(this), usdcTokenAmount);

        // stake all lp tokens
        uint256 usdcLPTokenBalance = usdcLPToken.balanceOf(address(this));
        usdcLPToken.approve(address(dodoMine), usdcLPTokenBalance);
        dodoMine.deposit(usdcLPTokenBalance);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        // get lp tokens
        uint256 usdcLPTokenTotalSupply = usdcLPToken.totalSupply();
        (uint256 baseTarget,) = dodoV1UsdcUsdtPool.getExpectedTarget();

        // Calculate:
        // 1) need amount by total supply and base target
        // 2) penalty value
        // 3) +1 for fix routing
        uint256 unstakeLpBalance = (_amount * usdcLPTokenTotalSupply / baseTarget) + dodoV1UsdcUsdtPool.getWithdrawBasePenalty(_amount) + 1 ;
        uint256 userLPBalance = dodoMine.balanceOf(address(this));
        if (unstakeLpBalance > userLPBalance) {
            unstakeLpBalance = userLPBalance;
        }

        // unstake lp tokens
        dodoMine.withdraw(unstakeLpBalance);

        // remove liquidity from pool
        dodoV1UsdcUsdtPool.withdrawAllBase();

        // return all usdc tokens
        return usdcToken.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        // get all lp tokens
        uint256 userLPBalance = dodoMine.balanceOf(address(this));
        if (userLPBalance == 0) {
            return usdcToken.balanceOf(address(this));
        }

        // unstake lp tokens
        dodoMine.withdraw(userLPBalance);

        // remove liquidity from pool
        dodoV1UsdcUsdtPool.withdrawAllBase();

        // return all usdc tokens
        return usdcToken.balanceOf(address(this));
    }

    function netAssetValue() external override view returns (uint256) {
        return _totalValue(true);
    }

    function liquidationValue() external override view returns (uint256) {
        return _totalValue(false);
    }

    function _totalValue(bool nav) internal view returns (uint256) {
        uint256 usdcBalance = usdcToken.balanceOf(address(this));

        uint256 userLPBalance = dodoMine.balanceOf(address(this));
        if (userLPBalance > 0) {
            uint256 usdcLPTokenTotalSupply = usdcLPToken.totalSupply();
            (uint256 baseTarget,) = dodoV1UsdcUsdtPool.getExpectedTarget();
            uint256 usdcTokenAmount = baseTarget * userLPBalance / usdcLPTokenTotalSupply;

            if(nav){
                usdcBalance += usdcTokenAmount;
            }else {
                // minus 0.06%
                usdcBalance += usdcTokenAmount - (usdcTokenAmount * 6 / 10000);
            }

        }

        return usdcBalance;
    }

    function _claimRewards(address _to) internal override returns (uint256) {

        uint256 userLPBalance = dodoMine.balanceOf(address(this));
        if (userLPBalance == 0) {
            return 0;
        }

        // claim rewards
        dodoMine.claimAllRewards();

        // sell rewards
        uint256 totalUsdc;

        uint256 dodoBalance = dodoToken.balanceOf(address(this));
        if (dodoBalance > 0) {
            // swap v2 dodo -> usdt
            uint256 usdtTokenAmount = _useDodoSwapV2(
                address(dodoV2DodoUsdtPool),
                address(dodoToken),
                address(usdtToken),
                dodoBalance,
                1,
                0
            );

            uint256 usdcTokenAmount;
            if (usdtTokenAmount > 0) {
                // swap v1 usdt -> usdc
                usdcTokenAmount = _useDodoSwapV1(
                    address(dodoV1UsdcUsdtPool),
                    address(usdtToken),
                    address(usdcToken),
                    usdtTokenAmount,
                    1,
                    1
                );
            }

            totalUsdc += usdcTokenAmount;
        }

        uint256 wmaticBalance = wmaticToken.balanceOf(address(this));
        if (wmaticBalance > 0) {
            uint256 wmaticUsdc = swap(
                balancerPoolIdWmaticUsdcWethBal,
                IVault.SwapKind.GIVEN_IN,
                IAsset(address(wmaticToken)),
                IAsset(address(usdcToken)),
                address(this),
                address(this),
                wmaticBalance,
                0
            );

            totalUsdc += wmaticUsdc;
        }

        if (totalUsdc > 0) {
            usdcToken.transfer(_to, totalUsdc);
        }

        return totalUsdc;
    }

}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/connectors/contracts/stuff/Dodo.sol";
import "@overnight-contracts/connectors/contracts/stuff/Balancer.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";


contract StrategyDodoUsdt is Strategy, DodoExchange, BalancerExchange {
    using OvnMath for uint256;

    IERC20 public usdcToken;
    IERC20 public usdtToken;
    IERC20 public dodoToken;
    IERC20 public wmaticToken;
    IERC20 public usdtLPToken;

    IDODOV1 public dodoV1UsdcUsdtPool;
    IDODOV2 public dodoV2DodoUsdtPool;
    IDODOMine public dodoMine;
    bytes32 public balancerPoolIdUsdcTusdDaiUsdt;
    bytes32 public balancerPoolIdWmaticUsdcWethBal;


    // --- events

    event StrategyUpdatedTokens(address usdcToken, address usdtToken, address dodoToken, address wmaticToken, address usdtLPToken);

    event StrategyUpdatedParams(address dodoV1UsdcUsdtPool, address dodoV2DodoUsdtPool, address dodoMine, address dodoV1Helper,
        address dodoProxy, address dodoApprove, address balancerVault, bytes32 balancerPoolIdUsdcTusdDaiUsdt, bytes32 balancerPoolIdWmaticUsdcWethBal);


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
        address _usdtLPToken
    ) external onlyAdmin {

        require(_usdcToken != address(0), "Zero address not allowed");
        require(_usdtToken != address(0), "Zero address not allowed");
        require(_dodoToken != address(0), "Zero address not allowed");
        require(_wmaticToken != address(0), "Zero address not allowed");
        require(_usdtLPToken != address(0), "Zero address not allowed");

        usdcToken = IERC20(_usdcToken);
        usdtToken = IERC20(_usdtToken);
        dodoToken = IERC20(_dodoToken);
        wmaticToken = IERC20(_wmaticToken);
        usdtLPToken = IERC20(_usdtLPToken);

        emit StrategyUpdatedTokens(_usdcToken, _usdtToken, _dodoToken, _wmaticToken, _usdtLPToken);
    }

    function setParams(
        address _dodoV1UsdcUsdtPool,
        address _dodoV2DodoUsdtPool,
        address _dodoMine,
        address _dodoV1Helper,
        address _dodoProxy,
        address _dodoApprove,
        address _balancerVault,
        bytes32 _balancerPoolIdUsdcTusdDaiUsdt,
        bytes32 _balancerPoolIdWmaticUsdcWethBal
    ) external onlyAdmin {

        require(_dodoV1UsdcUsdtPool != address(0), "Zero address not allowed");
        require(_dodoV2DodoUsdtPool != address(0), "Zero address not allowed");
        require(_dodoMine != address(0), "Zero address not allowed");
        require(_dodoV1Helper != address(0), "Zero address not allowed");
        require(_dodoProxy != address(0), "Zero address not allowed");
        require(_dodoApprove != address(0), "Zero address not allowed");
        require(_balancerVault != address(0), "Zero address not allowed");
        require(_balancerPoolIdUsdcTusdDaiUsdt != "", "Empty pool id not allowed");
        require(_balancerPoolIdWmaticUsdcWethBal != "", "Empty pool id not allowed");

        dodoV1UsdcUsdtPool = IDODOV1(_dodoV1UsdcUsdtPool);
        dodoV2DodoUsdtPool = IDODOV2(_dodoV2DodoUsdtPool);
        dodoMine = IDODOMine(_dodoMine);
        _setDodoParams(_dodoV1Helper, _dodoProxy, _dodoApprove);
        setBalancerVault(_balancerVault);
        balancerPoolIdUsdcTusdDaiUsdt = _balancerPoolIdUsdcTusdDaiUsdt;
        balancerPoolIdWmaticUsdcWethBal = _balancerPoolIdWmaticUsdcWethBal;

        emit StrategyUpdatedParams(_dodoV1UsdcUsdtPool, _dodoV2DodoUsdtPool, _dodoMine, _dodoV1Helper, _dodoProxy,
            _dodoApprove, _balancerVault, _balancerPoolIdUsdcTusdDaiUsdt, _balancerPoolIdWmaticUsdcWethBal);
    }


    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(usdcToken), "Some token not compatible");

        // swap all usdc to usdt
        swap(
            balancerPoolIdUsdcTusdDaiUsdt,
            IVault.SwapKind.GIVEN_IN,
            IAsset(address(usdcToken)),
            IAsset(address(usdtToken)),
            address(this),
            address(this),
            usdcToken.balanceOf(address(this)),
            0
        );

        // add liquidity to pool
        uint256 usdtTokenAmount = usdtToken.balanceOf(address(this));
        usdtToken.approve(address(dodoV1UsdcUsdtPool), usdtTokenAmount);
        dodoV1UsdcUsdtPool.depositQuoteTo(address(this), usdtTokenAmount);

        // stake all lp tokens
        uint256 usdtLPTokenBalance = usdtLPToken.balanceOf(address(this));
        usdtLPToken.approve(address(dodoMine), usdtLPTokenBalance);
        dodoMine.deposit(usdtLPTokenBalance);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        // add 5 basis points and 0.000005 usdc for small values
        uint256 amountToUnstake = _amount.addBasisPoints(5) + 5;

        // get usdt amount
        uint256 usdtTokenAmount = onSwap(
            balancerPoolIdUsdcTusdDaiUsdt,
            IVault.SwapKind.GIVEN_OUT,
            usdtToken,
            usdcToken,
            amountToUnstake
        );

        // get lp tokens
        uint256 usdtLPTokenTotalSupply = usdtLPToken.totalSupply();
        (, uint256 quoteTarget) = dodoV1UsdcUsdtPool.getExpectedTarget();
        uint256 unstakeLpBalance = usdtTokenAmount * usdtLPTokenTotalSupply / quoteTarget;
        uint256 userLPBalance = dodoMine.balanceOf(address(this));
        if (unstakeLpBalance > userLPBalance) {
            unstakeLpBalance = userLPBalance;
        }

        // unstake lp tokens
        dodoMine.withdraw(unstakeLpBalance);

        // remove liquidity from pool
        dodoV1UsdcUsdtPool.withdrawAllQuote();

        // swap all usdt to usdc
        swap(
            balancerPoolIdUsdcTusdDaiUsdt,
            IVault.SwapKind.GIVEN_IN,
            IAsset(address(usdtToken)),
            IAsset(address(usdcToken)),
            address(this),
            address(this),
            usdtToken.balanceOf(address(this)),
            0
        );

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
        dodoV1UsdcUsdtPool.withdrawAllQuote();

        // swap all usdt to usdc
        swap(
            balancerPoolIdUsdcTusdDaiUsdt,
            IVault.SwapKind.GIVEN_IN,
            IAsset(address(usdtToken)),
            IAsset(address(usdcToken)),
            address(this),
            address(this),
            usdtToken.balanceOf(address(this)),
            0
        );

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
        uint256 usdtBalance = usdtToken.balanceOf(address(this));

        uint256 userLPBalance = dodoMine.balanceOf(address(this));
        if (userLPBalance > 0) {
            uint256 usdcLPTokenTotalSupply = usdtLPToken.totalSupply();
            (, uint256 quoteTarget) = dodoV1UsdcUsdtPool.getExpectedTarget();
            uint256 usdtTokenAmount = quoteTarget * userLPBalance / usdcLPTokenTotalSupply;
            usdtBalance += usdtTokenAmount;
        }

        if (usdtBalance > 0) {
            uint256 usdtBalanceInUsdc;
            if (nav) {
                // check how many USDC tokens we have by current price
                uint256 priceUsdt = onSwap(
                    balancerPoolIdUsdcTusdDaiUsdt,
                    IVault.SwapKind.GIVEN_IN,
                    usdtToken,
                    usdcToken,
                    1e6
                );
                usdtBalanceInUsdc = (priceUsdt * usdtBalance) / 1e6;
            } else {
                // check how many USDC tokens we will get if we sell USDT tokens now
                usdtBalanceInUsdc = onSwap(
                    balancerPoolIdUsdcTusdDaiUsdt,
                    IVault.SwapKind.GIVEN_IN,
                    usdtToken,
                    usdcToken,
                    usdtBalance
                );
            }
            usdcBalance += usdtBalanceInUsdc;
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
                // swap usdt -> usdc
                usdcTokenAmount = swap(
                    balancerPoolIdUsdcTusdDaiUsdt,
                    IVault.SwapKind.GIVEN_IN,
                    IAsset(address(usdtToken)),
                    IAsset(address(usdcToken)),
                    address(this),
                    address(this),
                    usdtTokenAmount,
                    0
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

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/connectors/contracts/stuff/Balancer.sol";
import "@overnight-contracts/connectors/contracts/stuff/Impermax.sol";
import "@overnight-contracts/connectors/contracts/stuff/UniswapV2.sol";

contract StrategyImpermaxQsUsdt is Strategy, BalancerExchange {

    IERC20 public usdcToken;
    IERC20 public usdtToken;
    IPoolToken public imxBToken;

    bytes32 public balancerPoolId;

    IImpermaxRouter public impermaxRouter;
    IUniswapV2Pair public pair;


    // --- events

    event StrategyUpdatedTokens(address usdcToken, address usdtToken, address imxBToken);

    event StrategyUpdatedParams(address impermaxRouter, address balancerVault,  bytes32 balancerPoolId);


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
        address _imxBToken
    ) external onlyAdmin {

        require(_usdcToken != address(0), "Zero address not allowed");
        require(_usdtToken != address(0), "Zero address not allowed");
        require(_imxBToken != address(0), "Zero address not allowed");

        usdcToken = IERC20(_usdcToken);
        usdtToken = IERC20(_usdtToken);
        imxBToken = IPoolToken(_imxBToken);

        emit StrategyUpdatedTokens(_usdcToken, _usdtToken, _imxBToken);
    }

    function setParams(
        address _impermaxRouter,
        address _balancerVault,
        bytes32 _balancerPoolId
    ) external onlyAdmin {

        require(_impermaxRouter != address(0), "Zero address not allowed");
        require(_balancerVault != address(0), "Zero address not allowed");
        require(_balancerPoolId != "", "Empty pool id not allowed");

        impermaxRouter = IImpermaxRouter(_impermaxRouter);

        pair = IUniswapV2Pair(impermaxRouter.getUniswapV2Pair(imxBToken.underlying()));

        balancerPoolId = _balancerPoolId;
        setBalancerVault(_balancerVault);

        emit StrategyUpdatedParams(_impermaxRouter, _balancerVault, _balancerPoolId);
    }


    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {
        require(_asset == address(usdcToken), "Some token not compatible");

        address current = address(this);

        swap(balancerPoolId, IVault.SwapKind.GIVEN_IN, IAsset(address(usdcToken)), IAsset(address(usdtToken)), current, current, usdcToken.balanceOf(current), 0);

        usdtToken.approve(address(impermaxRouter), usdtToken.balanceOf(current));
        impermaxRouter.mint(address(imxBToken), usdtToken.balanceOf(current), current, block.timestamp);

    }


    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {
        require(_asset == address(usdcToken), "Some token not compatible");

        address current = address(this);

        imxBToken.approve(address(impermaxRouter), imxBToken.balanceOf(current));
        impermaxRouter.redeem(address(imxBToken), imxBToken.balanceOf(current), current, block.timestamp, "");

        swap(balancerPoolId, IVault.SwapKind.GIVEN_OUT, IAsset(address(usdtToken)), IAsset(address(usdcToken)), current, current, _amount);

        usdtToken.approve(address(impermaxRouter), usdtToken.balanceOf(current));
        impermaxRouter.mint(address(imxBToken), usdtToken.balanceOf(current), current, block.timestamp);


        return usdcToken.balanceOf(current);
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {
        require(_asset == address(usdcToken), "Some token not compatible");

        address current = address(this);

        imxBToken.approve(address(impermaxRouter), imxBToken.balanceOf(current));
        impermaxRouter.redeem(address(imxBToken), imxBToken.balanceOf(current), current, block.timestamp, "");

        swap(balancerPoolId, IVault.SwapKind.GIVEN_IN, IAsset(address(usdtToken)), IAsset(address(usdcToken)), current, current, usdtToken.balanceOf(current), 0);


        return usdcToken.balanceOf(current);
    }

    function netAssetValue() external view override returns (uint256) {
        return _getTotal();

    }

    function liquidationValue() external view override returns (uint256) {
        return _getTotal();
    }

    function _getTotal() internal view returns (uint256){
        uint256 balance = usdcToken.balanceOf(address(this));

        uint256 lockedBalance = imxBToken.balanceOf(address(this));

        if (lockedBalance != 0) {
            // 6 + 18 - 18 = 6
            uint256 balanceUsdt = (lockedBalance * imxBToken.exchangeRateLast()) / 1e18;
            balance += onSwap(balancerPoolId, IVault.SwapKind.GIVEN_OUT, usdcToken, usdtToken, balanceUsdt);
        }

        return balance;
    }


    // No claiming. Natural increase in liquidity.
    function _claimRewards(address _beneficiary) internal override returns (uint256) {
        return 0;
    }

}

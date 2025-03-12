// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/connectors/contracts/stuff/UniswapV2.sol";
import "@overnight-contracts/connectors/contracts/stuff/Balancer.sol";
import "@overnight-contracts/connectors/contracts/stuff/Mstable.sol";

contract StrategyMStable is Strategy, BalancerExchange, UniswapV2Exchange {

    IERC20 public usdcToken;
    IMasset public mUsdToken;
    ISavingsContractV2 public imUsdToken;
    IBoostedVaultWithLockup public vimUsdToken;
    IERC20 public mtaToken;
    IERC20 public wmaticToken;

    uint256 public usdcTokenDenominator;
    uint256 public vimUsdTokenDenominator;
    uint256 public wmaticTokenDenominator;

    bytes32 public balancerPoolId1;
    bytes32 public balancerPoolId2;


    // --- events

    event StrategyMStableUpdatedTokens(address usdcToken, address mUsdToken, address imUsdToken, address vimUsdToken, address mtaToken, address wmaticToken,
        uint256 usdcTokenDenominator, uint256 vimUsdTokenDenominator, uint256 wmaticTokenDenominator);

    event StrategyMStableUpdatedParams(address balancerVault, address uniswapRouter, bytes32 balancerPoolId1, bytes32 balancerPoolId2);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }


    // --- Setters

    function setTokens(
        address _usdcToken,
        address _mUsdToken,
        address _imUsdToken,
        address _vimUsdToken,
        address _mtaToken,
        address _wmaticToken
    ) external onlyAdmin {
        require(_usdcToken != address(0), "Zero address not allowed");
        require(_mUsdToken != address(0), "Zero address not allowed");
        require(_imUsdToken != address(0), "Zero address not allowed");
        require(_vimUsdToken != address(0), "Zero address not allowed");
        require(_mtaToken != address(0), "Zero address not allowed");
        require(_wmaticToken != address(0), "Zero address not allowed");

        usdcToken = IERC20(_usdcToken);
        mUsdToken = IMasset(_mUsdToken);
        imUsdToken = ISavingsContractV2(_imUsdToken);
        vimUsdToken = IBoostedVaultWithLockup(_vimUsdToken);
        mtaToken = IERC20(_mtaToken);
        wmaticToken = IERC20(_wmaticToken);

        usdcTokenDenominator = 10 ** IERC20Metadata(_usdcToken).decimals();
        vimUsdTokenDenominator = 10 ** IERC20Metadata(_vimUsdToken).decimals();
        wmaticTokenDenominator = 10 ** IERC20Metadata(_wmaticToken).decimals();

        emit StrategyMStableUpdatedTokens(_usdcToken, _mUsdToken, _imUsdToken, _vimUsdToken, _mtaToken, _wmaticToken,
            usdcTokenDenominator, vimUsdTokenDenominator, wmaticTokenDenominator);
    }

    function setParams(
        address _balancerVault,
        address _uniswapRouter,
        bytes32 _balancerPoolId1,
        bytes32 _balancerPoolId2
    ) external onlyAdmin {
        require(_balancerVault != address(0), "Zero address not allowed");
        require(_uniswapRouter != address(0), "Zero address not allowed");

        require(_balancerPoolId1 != "", "Empty pool id not allowed");
        require(_balancerPoolId2 != "", "Empty pool id not allowed");

        setBalancerVault(_balancerVault);
        _setUniswapRouter(_uniswapRouter);

        balancerPoolId1 = _balancerPoolId1;
        balancerPoolId2 = _balancerPoolId2;

        emit StrategyMStableUpdatedParams(_balancerVault, _uniswapRouter, _balancerPoolId1, _balancerPoolId2);
    }


    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(usdcToken), "Some token not compatible");

        // 1) Mint mUSD token
        usdcToken.approve(address(mUsdToken), _amount);
        uint256 mintedTokens = mUsdToken.mint(address(usdcToken), _amount, 0, address(this));

        // 2) Deposit mUsd
        mUsdToken.approve(address(imUsdToken), mintedTokens);
        uint256 savedTokens = imUsdToken.depositSavings(mintedTokens, address(this));

        // 3) Stake imUsd
        imUsdToken.approve(address(vimUsdToken), savedTokens);
        vimUsdToken.stake(address(this), savedTokens);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        uint256 mUsdAmount = mUsdToken.getMintOutput(address(usdcToken), _amount);
        uint256 imUsdAmount = imUsdToken.underlyingToCredits(mUsdAmount);
        // vimUsd and imUsd in ratio 1:1. we can use imUsdAmount for vimUsdAmount
        // add 0.1% to withdraw more than request amount
        uint256 vimUsdAmount = imUsdAmount * 1001 / 1000;

        vimUsdToken.withdraw(vimUsdAmount);

        imUsdToken.redeem(imUsdToken.balanceOf(address(this)));

        mUsdToken.redeem(address(usdcToken), mUsdToken.balanceOf(address(this)), 0, address(this));

        uint256 usdcBalance = usdcToken.balanceOf(address(this));

        return usdcBalance;
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        uint256 vimUsdBalance = vimUsdToken.balanceOf(address(this));

        vimUsdToken.withdraw(vimUsdBalance);

        imUsdToken.redeem(imUsdToken.balanceOf(address(this)));

        mUsdToken.redeem(address(usdcToken), mUsdToken.balanceOf(address(this)), 0, address(this));

        uint256 usdcBalance = usdcToken.balanceOf(address(this));

        return usdcBalance;
    }

    function netAssetValue() external override view returns (uint256) {
        return _totalValue();
    }

    function liquidationValue() external override view returns (uint256) {
        return _totalValue();
    }

    function _totalValue() internal view returns (uint256) {
        uint256 vimUsdBalance = vimUsdToken.balanceOf(address(this));
        if (vimUsdBalance == 0) {
            return 0;
        }

        // vimUsd and imUsd in ratio 1:1. we can use vimUsdBalance for imUsdBalance
        uint256 mUsdBalance = imUsdToken.creditsToUnderlying(vimUsdBalance);

        uint256 usdcBalance = mUsdToken.getRedeemOutput(address(usdcToken), mUsdBalance);

        return usdcBalance;
    }

    function _claimRewards(address _to) internal override returns (uint256) {
        vimUsdToken.claimReward();

        uint256 totalUsdc;

        uint256 mtaBalance = mtaToken.balanceOf(address(this));
        if (mtaBalance != 0) {
            uint256 mtaUsdc = batchSwap(balancerPoolId1, balancerPoolId2, IVault.SwapKind.GIVEN_IN, IAsset(address(mtaToken)),
                IAsset(address(wmaticToken)), IAsset(address(usdcToken)), address(this), payable(address(this)), mtaBalance);
            totalUsdc += mtaUsdc;
        }

        uint256 wmaticBalance = wmaticToken.balanceOf(address(this));
        if (wmaticBalance != 0) {
            uint256 wmaticUsdc = _swapExactTokensForTokens(
                address(wmaticToken),
                address(usdcToken),
                wmaticBalance,
                address(this)
            );
            totalUsdc += wmaticUsdc;
        }

        usdcToken.transfer(_to, usdcToken.balanceOf(address(this)));
        return totalUsdc;
    }
}

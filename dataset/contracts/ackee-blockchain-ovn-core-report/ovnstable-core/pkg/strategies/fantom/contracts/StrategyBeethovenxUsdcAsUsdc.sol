// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./core/Strategy.sol";
import "./exchanges/BeethovenxExchange.sol";
import "./connectors/beethovenx/interfaces/IVault.sol";
import "./connectors/beethovenx/interfaces/IAsset.sol";
import "./connectors/beethovenx/BeethovenxMasterChef.sol";
import "./libraries/OvnMath.sol";

contract StrategyBeethovenxUsdcAsUsdc is Strategy, BeethovenExchange {

    uint256 constant public BASIS_POINTS_FOR_SLIPPAGE = 4;

    IERC20 public usdcToken;
    IERC20 public bptUsdcAsUsdcToken;
    IERC20 public beetsToken;
    IERC20 public wFtmToken;
    IERC20 public asUsdcToken;

    uint256 public usdcTokenDenominator;
    uint256 public asUsdcTokenDenominator;

    IVault public beethovenxVault;
    BeethovenxMasterChef public beethovenxMasterChef;

    bytes32 public poolIdUsdcAsUsdc;
    bytes32 public poolIdBeetsWFtm;
    bytes32 public poolIdWFtmUsdc;

    uint256 public pidUsdcAsUsdc;


    // --- events

    event StrategyBalancerUpdatedTokens(
        address usdcToken,
        address bptUsdcAsUsdcToken,
        address beetsToken,
        address wFtmToken,
        uint256 usdcTokenDenominator,
        uint256 asUsdcTokenDenominator,
        address asUsdcToken
    );

    event StrategyBalancerUpdatedParams(
        address beethovenxVault,
        address beethovenxMasterChef,
        bytes32 poolIdUsdcAsUsdc,
        bytes32 poolIdBeetsWFtm,
        bytes32 poolIdWFtmUsdc,
        uint256 pidUsdcAsUsdc
    );


    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }


    // --- Setters

    function setTokens(
        address _usdcToken,
        address _bptUsdcAsUsdcToken,
        address _beetsToken,
        address _wFtmToken,
        address _asUsdcToken
    ) external onlyAdmin {

        require(_usdcToken != address(0), "Zero address not allowed");
        require(_bptUsdcAsUsdcToken != address(0), "Zero address not allowed");
        require(_beetsToken != address(0), "Zero address not allowed");
        require(_wFtmToken != address(0), "Zero address not allowed");

        usdcToken = IERC20(_usdcToken);
        bptUsdcAsUsdcToken = IERC20(_bptUsdcAsUsdcToken);
        beetsToken = IERC20(_beetsToken);
        wFtmToken = IERC20(_wFtmToken);
        asUsdcToken = IERC20(_asUsdcToken);

        usdcTokenDenominator = 10 ** IERC20Metadata(_usdcToken).decimals();
        asUsdcTokenDenominator = 10 ** IERC20Metadata(_asUsdcToken).decimals();

        emit StrategyBalancerUpdatedTokens(
            _usdcToken,
            _bptUsdcAsUsdcToken,
            _beetsToken,
            _wFtmToken,
            usdcTokenDenominator,
            asUsdcTokenDenominator,
            _asUsdcToken
        );
    }

    function setParams(
        address _beethovenxVault,
        address _beethovenxMasterChef,
        bytes32 _poolIdUsdcAsUsdc,
        bytes32 _poolIdBeetsWFtm,
        bytes32 _poolIdWFtmUsdc,
        uint256 _pidUsdcAsUsdc
    ) external onlyAdmin {

        require(_beethovenxVault != address(0), "Zero address not allowed");
        require(_beethovenxMasterChef != address(0), "Zero address not allowed");
        require(_poolIdUsdcAsUsdc != "", "Empty pool id not allowed");
        require(_poolIdBeetsWFtm != "", "Empty pool id not allowed");
        require(_poolIdWFtmUsdc != "", "Empty pool id not allowed");

        setBeethovenxVault(_beethovenxVault);

        beethovenxVault = IVault(_beethovenxVault);
        beethovenxMasterChef = BeethovenxMasterChef(_beethovenxMasterChef);
        poolIdUsdcAsUsdc = _poolIdUsdcAsUsdc;
        poolIdBeetsWFtm = _poolIdBeetsWFtm;
        poolIdWFtmUsdc = _poolIdWFtmUsdc;
        pidUsdcAsUsdc = _pidUsdcAsUsdc;

        emit StrategyBalancerUpdatedParams(
            _beethovenxVault,
            _beethovenxMasterChef,
            _poolIdUsdcAsUsdc,
            _poolIdBeetsWFtm,
            _poolIdWFtmUsdc,
            _pidUsdcAsUsdc
        );
    }


    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(usdcToken), "Some token not compatible");

        usdcToken.approve(address(beethovenxVault), _amount);

        (IERC20[] memory tokens, , ) = beethovenxVault.getPoolTokens(poolIdUsdcAsUsdc);

        IAsset[] memory assets = new IAsset[](2);
        uint256[] memory maxAmountsIn = new uint256[](2);
        uint256[] memory amountsIn = new uint256[](2);
        for (uint256 i; i < tokens.length; i++) {
            assets[i] = IAsset(address(tokens[i]));
            if (tokens[i] == usdcToken) {
                maxAmountsIn[i] = _amount;
                amountsIn[i] = _amount;
            } else {
                maxAmountsIn[i] = 0;
                amountsIn[i] = 0;
            }
        }

        uint256 joinKind = 1;
        uint256 minimumBPT = 0;
        bytes memory userData = abi.encode(joinKind, amountsIn, minimumBPT);

        IVault.JoinPoolRequest memory request = IVault.JoinPoolRequest(assets, maxAmountsIn, userData, false);

        beethovenxVault.joinPool(poolIdUsdcAsUsdc, address(this), address(this), request);

        uint256 amountBptUsdcAsUsdc = bptUsdcAsUsdcToken.balanceOf(address(this));

        bptUsdcAsUsdcToken.approve(address(beethovenxMasterChef), amountBptUsdcAsUsdc);

        beethovenxMasterChef.deposit(pidUsdcAsUsdc, amountBptUsdcAsUsdc, address(this));
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        uint256 slippageAmount = _amount;
        _amount = OvnMath.addBasisPoints(_amount, BASIS_POINTS_FOR_SLIPPAGE);

        (IERC20[] memory tokens, uint256[] memory balances, ) = beethovenxVault.getPoolTokens(poolIdUsdcAsUsdc);

        uint256 amountBptUsdcAsUsdc = _getAmountLPTokensForWithdraw(
            _amount, balances[0], balances[1], bptUsdcAsUsdcToken.totalSupply(), asUsdcTokenDenominator/usdcTokenDenominator);
        
        beethovenxMasterChef.withdrawAndHarvest(pidUsdcAsUsdc, amountBptUsdcAsUsdc, address(this));

        amountBptUsdcAsUsdc = bptUsdcAsUsdcToken.balanceOf(address(this));

        IAsset[] memory assets = new IAsset[](2);
        uint256[] memory minAmountsOut = new uint256[](2);
        uint256 exitTokenIndex;
        for (uint256 i; i < tokens.length; i++) {
            assets[i] = IAsset(address(tokens[i]));
            if (tokens[i] == usdcToken) {
                minAmountsOut[i] = slippageAmount;
                exitTokenIndex = i;
            } else {
                minAmountsOut[i] = 0;
            }
        }

        uint256 exitKind = 0;
        bytes memory userData = abi.encode(exitKind, amountBptUsdcAsUsdc, exitTokenIndex);

        IVault.ExitPoolRequest memory request = IVault.ExitPoolRequest(assets, minAmountsOut, userData, false);

        beethovenxVault.exitPool(poolIdUsdcAsUsdc, address(this), payable(address(this)), request);

        return usdcToken.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        (uint256 amountBptUsdcAsUsdc, ) = beethovenxMasterChef.userInfo(pidUsdcAsUsdc, address(this));

        beethovenxMasterChef.withdrawAndHarvest(pidUsdcAsUsdc, amountBptUsdcAsUsdc, address(this));

        uint256 amountUsdc = _getBptUsdcAsUsdcPrice(amountBptUsdcAsUsdc);

        (IERC20[] memory tokens, , ) = beethovenxVault.getPoolTokens(poolIdUsdcAsUsdc);

        IAsset[] memory assets = new IAsset[](2);
        uint256[] memory minAmountsOut = new uint256[](2);
        uint256 exitTokenIndex = 0;
        for (uint256 i; i < tokens.length; i++) {
            assets[i] = IAsset(address(tokens[i]));
            if (tokens[i] == usdcToken) {
                minAmountsOut[i] = OvnMath.subBasisPoints(amountUsdc, BASIS_POINTS_FOR_SLIPPAGE);
                exitTokenIndex = i;
            } else {
                minAmountsOut[i] = 0;
            }
        }

        uint256 exitKind = 0;
        bytes memory userData = abi.encode(exitKind, amountBptUsdcAsUsdc, exitTokenIndex);

        IVault.ExitPoolRequest memory request = IVault.ExitPoolRequest(assets, minAmountsOut, userData, false);

        beethovenxVault.exitPool(poolIdUsdcAsUsdc, address(this), payable(address(this)), request);

        return usdcToken.balanceOf(address(this));
    }

    function netAssetValue() external override view returns (uint256) {
        (uint256 amount, ) = beethovenxMasterChef.userInfo(pidUsdcAsUsdc, address(this));
        if (amount == 0) {
            return 0;
        }
        return _getBptUsdcAsUsdcPrice(amount);
    }

    function liquidationValue() external override view returns (uint256) {
        (uint256 amount, ) = beethovenxMasterChef.userInfo(pidUsdcAsUsdc, address(this));
        if (amount == 0) {
            return 0;
        }
        return _getBptUsdcAsUsdcPrice(amount);
    }

    function _getBptUsdcAsUsdcPrice(uint256 balanceBptUsdcAsUsdc) internal view returns (uint256) {
        uint256 totalSupply = bptUsdcAsUsdcToken.totalSupply();

        uint256 totalBalanceUsdc;
        (IERC20[] memory tokens, uint256[] memory balances, ) = beethovenxVault.getPoolTokens(poolIdUsdcAsUsdc);
        for (uint256 i; i < tokens.length; i++) {
            uint256 tokenBalance = balances[i] * balanceBptUsdcAsUsdc / totalSupply;
            if (tokens[i] != usdcToken) {
                totalBalanceUsdc += onSwap(poolIdUsdcAsUsdc, IVault.SwapKind.GIVEN_IN, tokens[i], usdcToken, tokenBalance);
            } else {
                totalBalanceUsdc += tokenBalance;
            }
        }

        return totalBalanceUsdc;
    }

    function _claimRewards(address _to) internal override returns (uint256) {

        beethovenxMasterChef.harvest(pidUsdcAsUsdc, address(this));

        uint256 totalUsdc;

        uint256 beetsBalance = beetsToken.balanceOf(address(this));
        if (beetsBalance > 0) {
            uint256 beetsUsdc = batchSwap(poolIdBeetsWFtm, poolIdWFtmUsdc, IVault.SwapKind.GIVEN_IN, IAsset(address(beetsToken)),
                IAsset(address(wFtmToken)), IAsset(address(usdcToken)), address(this), payable(address(this)), beetsBalance);
            totalUsdc += beetsUsdc;
        }

        usdcToken.transfer(_to, usdcToken.balanceOf(address(this)));

        return totalUsdc;
    }

    function _getAmountLPTokensForWithdraw(
        uint256 amount,
        uint256 reserveUsdc,
        uint256 reserveAsUsdc,
        uint256 totalLpBalance,
        uint256 decimalDelta
    ) internal view returns (uint256) {
        uint256 lpBalance;
        uint256 amountAsUsdcToSwap = decimalDelta;
        uint256 swappedUsdc = 1;
        for (uint i=0; i<2; i++) {
            lpBalance = (totalLpBalance * amountAsUsdcToSwap * amount) / (reserveAsUsdc * swappedUsdc + reserveUsdc * amountAsUsdcToSwap);
            amountAsUsdcToSwap = (reserveAsUsdc * lpBalance) / totalLpBalance;
            swappedUsdc = onSwap(
                poolIdUsdcAsUsdc,
                IVault.SwapKind.GIVEN_IN,
                asUsdcToken,
                usdcToken,
                amountAsUsdcToSwap
            );
        }
        lpBalance = (totalLpBalance * amountAsUsdcToSwap * amount) / (reserveAsUsdc * swappedUsdc + reserveUsdc * amountAsUsdcToSwap);
        return lpBalance;
    }
}
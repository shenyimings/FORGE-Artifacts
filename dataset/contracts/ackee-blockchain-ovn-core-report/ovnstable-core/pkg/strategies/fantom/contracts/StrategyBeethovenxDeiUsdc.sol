// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./core/Strategy.sol";
import "./exchanges/BeethovenxExchange.sol";
import "./connectors/beethovenx/interfaces/IVault.sol";
import "./connectors/beethovenx/interfaces/IAsset.sol";
import "./connectors/beethovenx/BeethovenxMasterChef.sol";
import "./libraries/OvnMath.sol";

contract StrategyBeethovenxDeiUsdc is Strategy, BeethovenExchange {

    uint256 constant public BASIS_POINTS_FOR_SLIPPAGE = 4;

    IERC20 public usdcToken;
    IERC20 public bptDeiUsdcToken;
    IERC20 public beetsToken;
    IERC20 public deusToken;
    IERC20 public wFtmToken;

    uint256 public usdcTokenDenominator;
    uint256 public bptDeiUsdcTokenDenominator; // unused
    uint256 public beetsTokenDenominator; // unused
    uint256 public deusTokenDenominator; // unused
    uint256 public wFtmTokenDenominator; // unused

    IVault public beethovenxVault;
    BeethovenxMasterChef public beethovenxMasterChef;

    bytes32 public poolIdDeiUsdc;
    bytes32 public poolIdBeetsWFtm;
    bytes32 public poolIdDeusWFtm;
    bytes32 public poolIdWFtmUsdc;

    uint256 public pidDeiUsdc;

    IERC20 public deiToken;
    uint256 public deiTokenDenominator;



    // --- events

    event StrategyBalancerUpdatedTokens(
        address usdcToken,
        address bptDeiUsdcToken,
        address beetsToken,
        address deusToken,
        address wFtmToken,
        uint256 usdcTokenDenominator,
        uint256 deiTokenDenominator,
        address deiToken
    );

    event StrategyBalancerUpdatedParams(
        address beethovenxVault,
        address beethovenxMasterChef,
        bytes32 poolIdDeiUsdc,
        bytes32 poolIdBeetsWFtm,
        bytes32 poolIdDeusWFtm,
        bytes32 poolIdWFtmUsdc,
        uint256 pidDeiUsdc
    );


    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }


    // --- Setters

    function setTokens(
        address _usdcToken,
        address _bptDeiUsdcToken,
        address _beetsToken,
        address _deusToken,
        address _wFtmToken,
        address _deiToken
    ) external onlyAdmin {

        require(_usdcToken != address(0), "Zero address not allowed");
        require(_bptDeiUsdcToken != address(0), "Zero address not allowed");
        require(_beetsToken != address(0), "Zero address not allowed");
        require(_deusToken != address(0), "Zero address not allowed");
        require(_wFtmToken != address(0), "Zero address not allowed");

        usdcToken = IERC20(_usdcToken);
        bptDeiUsdcToken = IERC20(_bptDeiUsdcToken);
        beetsToken = IERC20(_beetsToken);
        deusToken = IERC20(_deusToken);
        wFtmToken = IERC20(_wFtmToken);
        deiToken = IERC20(_deiToken);

        usdcTokenDenominator = 10 ** IERC20Metadata(_usdcToken).decimals();
        deiTokenDenominator = 10 ** IERC20Metadata(_deiToken).decimals();

        emit StrategyBalancerUpdatedTokens(
            _usdcToken,
            _bptDeiUsdcToken,
            _beetsToken,
            _deusToken,
            _wFtmToken,
            usdcTokenDenominator,
            deiTokenDenominator,
            _deiToken
        );
    }

    function setParams(
        address _beethovenxVault,
        address _beethovenxMasterChef,
        bytes32 _poolIdDeiUsdc,
        bytes32 _poolIdBeetsWFtm,
        bytes32 _poolIdDeusWFtm,
        bytes32 _poolIdWFtmUsdc,
        uint256 _pidDeiUsdc
    ) external onlyAdmin {

        require(_beethovenxVault != address(0), "Zero address not allowed");
        require(_beethovenxMasterChef != address(0), "Zero address not allowed");
        require(_poolIdDeiUsdc != "", "Empty pool id not allowed");
        require(_poolIdBeetsWFtm != "", "Empty pool id not allowed");
        require(_poolIdDeusWFtm != "", "Empty pool id not allowed");
        require(_poolIdWFtmUsdc != "", "Empty pool id not allowed");

        setBeethovenxVault(_beethovenxVault);

        beethovenxVault = IVault(_beethovenxVault);
        beethovenxMasterChef = BeethovenxMasterChef(_beethovenxMasterChef);
        poolIdDeiUsdc = _poolIdDeiUsdc;
        poolIdBeetsWFtm = _poolIdBeetsWFtm;
        poolIdDeusWFtm = _poolIdDeusWFtm;
        poolIdWFtmUsdc = _poolIdWFtmUsdc;
        pidDeiUsdc = _pidDeiUsdc;

        emit StrategyBalancerUpdatedParams(
            _beethovenxVault,
            _beethovenxMasterChef,
            _poolIdDeiUsdc,
            _poolIdBeetsWFtm,
            _poolIdDeusWFtm,
            _poolIdWFtmUsdc,
            _pidDeiUsdc
        );
    }


    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(usdcToken), "Some token not compatible");

        usdcToken.approve(address(beethovenxVault), _amount);

        (IERC20[] memory tokens, , ) = beethovenxVault.getPoolTokens(poolIdDeiUsdc);

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

        beethovenxVault.joinPool(poolIdDeiUsdc, address(this), address(this), request);

        uint256 amountBptDeiUsdc = bptDeiUsdcToken.balanceOf(address(this));

        bptDeiUsdcToken.approve(address(beethovenxMasterChef), amountBptDeiUsdc);

        beethovenxMasterChef.deposit(pidDeiUsdc, amountBptDeiUsdc, address(this));
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        uint256 slippageAmount = _amount;
        _amount = OvnMath.addBasisPoints(_amount, BASIS_POINTS_FOR_SLIPPAGE);

        (IERC20[] memory tokens, uint256[] memory balances, ) = beethovenxVault.getPoolTokens(poolIdDeiUsdc);

        uint256 amountBptDeiUsdc = _getAmountLPTokensForWithdraw(
            _amount, balances[0], balances[1], bptDeiUsdcToken.totalSupply(), deiTokenDenominator/usdcTokenDenominator);
        
        beethovenxMasterChef.withdrawAndHarvest(pidDeiUsdc, amountBptDeiUsdc, address(this));

        amountBptDeiUsdc = bptDeiUsdcToken.balanceOf(address(this));

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
        bytes memory userData = abi.encode(exitKind, amountBptDeiUsdc, exitTokenIndex);

        IVault.ExitPoolRequest memory request = IVault.ExitPoolRequest(assets, minAmountsOut, userData, false);

        beethovenxVault.exitPool(poolIdDeiUsdc, address(this), payable(address(this)), request);

        return usdcToken.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        (uint256 amountBptDeiUsdc, ) = beethovenxMasterChef.userInfo(pidDeiUsdc, address(this));

        beethovenxMasterChef.withdrawAndHarvest(pidDeiUsdc, amountBptDeiUsdc, address(this));

        uint256 amountUsdc = _getBptDeiUsdcPrice(amountBptDeiUsdc);

        (IERC20[] memory tokens, , ) = beethovenxVault.getPoolTokens(poolIdDeiUsdc);

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
        bytes memory userData = abi.encode(exitKind, amountBptDeiUsdc, exitTokenIndex);

        IVault.ExitPoolRequest memory request = IVault.ExitPoolRequest(assets, minAmountsOut, userData, false);

        beethovenxVault.exitPool(poolIdDeiUsdc, address(this), payable(address(this)), request);

        return usdcToken.balanceOf(address(this));
    }

    function netAssetValue() external override view returns (uint256) {
        (uint256 amount, ) = beethovenxMasterChef.userInfo(pidDeiUsdc, address(this));
        if (amount == 0) {
            return 0;
        }
        return _getBptDeiUsdcPrice(amount);
    }

    function liquidationValue() external override view returns (uint256) {
        (uint256 amount, ) = beethovenxMasterChef.userInfo(pidDeiUsdc, address(this));
        if (amount == 0) {
            return 0;
        }
        return _getBptDeiUsdcPrice(amount);
    }

    function _getBptDeiUsdcPrice(uint256 balanceBptDeiUsdc) internal view returns (uint256) {
        uint256 totalSupply = bptDeiUsdcToken.totalSupply();

        uint256 totalBalanceUsdc;
        (IERC20[] memory tokens, uint256[] memory balances, ) = beethovenxVault.getPoolTokens(poolIdDeiUsdc);
        for (uint256 i; i < tokens.length; i++) {
            uint256 tokenBalance = balances[i] * balanceBptDeiUsdc / totalSupply;
            if (tokens[i] != usdcToken) {
                totalBalanceUsdc += onSwap(poolIdDeiUsdc, IVault.SwapKind.GIVEN_IN, tokens[i], usdcToken, tokenBalance);
            } else {
                totalBalanceUsdc += tokenBalance;
            }
        }

        return totalBalanceUsdc;
    }

    function _claimRewards(address _to) internal override returns (uint256) {

        beethovenxMasterChef.harvest(pidDeiUsdc, address(this));

        uint256 totalUsdc;

        uint256 beetsBalance = beetsToken.balanceOf(address(this));
        if (beetsBalance > 0) {
            uint256 beetsUsdc = batchSwap(poolIdBeetsWFtm, poolIdWFtmUsdc, IVault.SwapKind.GIVEN_IN, IAsset(address(beetsToken)),
                IAsset(address(wFtmToken)), IAsset(address(usdcToken)), address(this), payable(address(this)), beetsBalance);
            totalUsdc += beetsUsdc;
        }

        uint256 deusBalance = deusToken.balanceOf(address(this));
        if (deusBalance > 0) {
            uint256 deusUsdc = batchSwap(poolIdDeusWFtm, poolIdWFtmUsdc, IVault.SwapKind.GIVEN_IN, IAsset(address(deusToken)),
                IAsset(address(wFtmToken)), IAsset(address(usdcToken)), address(this), payable(address(this)), deusBalance);
            totalUsdc += deusUsdc;
        }

        usdcToken.transfer(_to, usdcToken.balanceOf(address(this)));

        return totalUsdc;
    }

    function _getAmountLPTokensForWithdraw(
        uint256 amount,
        uint256 reserveUsdc,
        uint256 reserveDai,
        uint256 totalLpBalance,
        uint256 decimalDelta
    ) internal view returns (uint256) {
        uint256 lpBalance;
        uint256 amountDaiToSwap = decimalDelta;
        uint256 swappedUsdc = 1;
        for (uint i=0; i<2; i++) {
            lpBalance = (totalLpBalance * amountDaiToSwap * amount) / (reserveDai * swappedUsdc + reserveUsdc * amountDaiToSwap);
            amountDaiToSwap = (reserveDai * lpBalance) / totalLpBalance;
            swappedUsdc = onSwap(
                poolIdDeiUsdc,
                IVault.SwapKind.GIVEN_IN,
                deiToken,
                usdcToken,
                amountDaiToSwap
            );
        }
        lpBalance = (totalLpBalance * amountDaiToSwap * amount) / (reserveDai * swappedUsdc + reserveUsdc * amountDaiToSwap);
        return lpBalance;
    }
}

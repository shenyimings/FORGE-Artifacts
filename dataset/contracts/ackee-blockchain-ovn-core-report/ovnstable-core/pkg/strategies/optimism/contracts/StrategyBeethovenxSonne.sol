// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";

import "@overnight-contracts/connectors/contracts/stuff/Beethovenx.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";
import "@overnight-contracts/connectors/contracts/stuff/Chainlink.sol";
import "@overnight-contracts/connectors/contracts/stuff/Velodrome.sol";

import "hardhat/console.sol";

contract StrategyBeethovenxSonne is Strategy {

    IERC20 public usdc;
    BptToken public bbaUsdc;
    BptToken public bbaUsdt;
    BptToken public bbaDai;
    BptToken public bpt;
    IERC20 public bptGauge;

    IVault public vault;
    bytes32 public aUsdcPoolId;
    bytes32 public stablePoolId;
    IGaugeBeethoven public gauge;

    IPriceFeed public oracleDai;
    IPriceFeed public oracleUsdt;
    IPriceFeed public oracleUsdc;

    IERC20 public op;
    IERC20 public sonne;
    IRouter public velodromeRouter;

    uint256 public swapSlippageBp;
    uint256 public allowedSlippageBp;

    // --- events
    event StrategyUpdatedParams();


    // --- structs

    struct StrategyParams {
        address usdc;
        address bbaUsdc;
        address bbaUsdt;
        address bbaDai;
        address bpt;
        address bptGauge;
        address vault;
        bytes32 aUsdcPoolId;
        bytes32 stablePoolId;
        address gauge;
        address oracleDai;
        address oracleUsdt;
        address oracleUsdc;
        address op;
        address sonne;
        address velodromeRouter;
    }


    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }


    // --- Setters

    function setParams(StrategyParams calldata params) external onlyAdmin {
        usdc = IERC20(params.usdc);
        bbaUsdc = BptToken(params.bbaUsdc);
        bbaUsdt = BptToken(params.bbaUsdt);
        bbaDai = BptToken(params.bbaDai);
        bpt = BptToken(params.bpt);
        bptGauge = IERC20(params.bptGauge);

        vault = IVault(params.vault);
        stablePoolId = params.stablePoolId;
        aUsdcPoolId = params.aUsdcPoolId;
        gauge = IGaugeBeethoven(params.gauge);

        oracleDai = IPriceFeed(params.oracleDai);
        oracleUsdt = IPriceFeed(params.oracleUsdt);
        oracleUsdc = IPriceFeed(params.oracleUsdc);

        op = IERC20(params.op);
        sonne = IERC20(params.sonne);
        velodromeRouter = IRouter(params.velodromeRouter);

        emit StrategyUpdatedParams();
    }


    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(usdc), "Some token not compatible");

        // How it work?
        // 1. Swap all USDC to bb-USDC
        // 2. Stake bb-USDC to stable pool
        // 3. Stake BPT tokens to gauge

        //1. Before put liquidity to Stable pool need to swap USDC to bb-aUSDC (linear pool token)
        uint256 usdcBalance = usdc.balanceOf(address(this));

        // 6e + 30e / 18e = 18e
        uint256 minAmountBbaUsdc = OvnMath.subBasisPoints(usdcBalance * 1e30 / bbaUsdc.getRate(), swapSlippageBP);

        BeethovenLibrary.swap(vault, aUsdcPoolId, IVault.SwapKind.GIVEN_IN, usdc, bbaUsdc, address(this), address(this), usdcBalance, minAmountBbaUsdc);

        (IERC20[] memory tokens, uint256[] memory balances, uint256 lastChangeBlock) = vault.getPoolTokens(stablePoolId);

        IAsset[] memory assets = new IAsset[](4);
        uint256[] memory maxAmountsIn = new uint256[](4);

        // Must be without BPT fantom token
        uint256[] memory amountsIn = new uint256[](3);

        for (uint256 i; i < tokens.length; i++) {
            assets[i] = IAsset(address(tokens[i]));
        }

        uint256 aUsdcAmount = bbaUsdc.balanceOf(address(this));

        // 3 - USDC index
        maxAmountsIn[3] = aUsdcAmount;

        // 2 - USDC index
        amountsIn[2] = aUsdcAmount;

        uint256 joinKind = 1;
        uint256 minimumBPT = 1;
        bytes memory userData = abi.encode(joinKind, amountsIn, minimumBPT);

        IVault.JoinPoolRequest memory request = IVault.JoinPoolRequest(assets, maxAmountsIn, userData, false);

        // 2. Put bb-aUSDC to Stable pool
        bbaUsdc.approve(address(vault), aUsdcAmount);
        vault.joinPool(stablePoolId, address(this), address(this), request);

        // 3. Put BPT tokens to Gauge
        uint256 bptAmount = bpt.balanceOf(address(this));
        bpt.approve(address(gauge), bptAmount);
        gauge.deposit(bptAmount);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdc), "Some token not compatible");

        return _unstakeUsdc(_calcAmountBPTbyUSDC(_amount));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdc), "Some token not compatible");

        uint256 gaugeAmount = gauge.balanceOf(address(this));
        return _unstakeUsdc(gaugeAmount);
    }


    function _unstakeUsdc(uint256 gaugeAmount) internal returns (uint256){

        // How it work?
        // 1. Unstake BPT tokens from Gauge
        // 2. Get all bb-USDC from stable pool
        // 3. Swap all bb-USDC to USDC by linear pool

        // 1. Unstake BPT from Gauge
        gauge.withdraw(gaugeAmount);

        uint256 bptAmount = bpt.balanceOf(address(this));

        IAsset[] memory assets = new IAsset[](4);
        uint256[] memory minAmountsOut = new uint256[](4);

        // index USDC
        uint256 exitTokenIndex = 2;

        (IERC20[] memory tokens,,) = vault.getPoolTokens(stablePoolId);

        for (uint256 i; i < tokens.length; i++) {
            assets[i] = IAsset(address(tokens[i]));
        }

        // EXACT_BPT_IN_FOR_ONE_TOKEN_OUT
        uint256 exitKind = 0;
        bytes memory userData = abi.encode(exitKind, bptAmount, exitTokenIndex);
        IVault.ExitPoolRequest memory request = IVault.ExitPoolRequest(assets, minAmountsOut, userData, false);

        // 2. Unstake from stable pool
        vault.exitPool(stablePoolId, address(this), payable(address(this)), request);

        // 3. Swap
        uint256 bbaUsdcBalance = bbaUsdc.balanceOf(address(this));

        // 18e + 18e - 30e = 6e (USDC)
        uint256 minAmountUsdc = OvnMath.subBasisPoints(bbaUsdcBalance * bbaUsdc.getRate() / 1e30, swapSlippageBP);
        BeethovenLibrary.swap(vault, aUsdcPoolId, IVault.SwapKind.GIVEN_IN, bbaUsdc, usdc, address(this), address(this), bbaUsdcBalance, minAmountUsdc);

        return usdc.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {
        return _total();
    }

    function liquidationValue() external view override returns (uint256) {
        return _total();
    }


    function _total() internal view returns (uint256){
        uint256 bptAmount = gauge.balanceOf(address(this));
        if (bptAmount == 0) {
            return usdc.balanceOf(address(this));
        }
        return _convertBptToUsdc(bptAmount);
    }

    function _convertBptToUsdc(uint256 bptAmount) internal view returns (uint256) {

        // total used tokens
        uint256 totalActualSupply = bpt.getActualSupply();

        uint256 totalBalanceUsdc = usdc.balanceOf(address(this));

        (IERC20[] memory tokens, uint256[] memory balances, uint256 lastChangeBlock) = vault.getPoolTokens(stablePoolId);

        // How it work?
        // 1. Calculating share (bb-USDC,bb-DAI,bb-USDT)
        // 2. Convert bb-* tokens to underlying tokens (DAI,USDC,USDT)
        // 3. Convert tokens (DAI,USDT) to USDC through chainlink oracle

        // Iterate thought liquidity tokens (bb-DAI,bb-USDC,bb-USDT) not main BPT (index 0)
        for (uint256 i = 1; i < tokens.length; i++) {

            address token = address(tokens[i]);

            // calculate share
            uint256 amountToken = balances[i] * bptAmount / totalActualSupply;

            if (token == address(bbaUsdc)) {
                // bpt token convert to underlying tokens by Rate
                // e18 + e18 - e30 = e6
                amountToken = amountToken * bbaUsdc.getRate() / 1e30;
                totalBalanceUsdc += amountToken;
            } else if (token == address(bbaUsdt)) {
                // bpt token convert to underlying tokens by Rate
                // e18 + e18 - e30 = e6
                amountToken = amountToken * bbaUsdt.getRate() / 1e30;
                totalBalanceUsdc += ChainlinkLibrary.convertTokenToToken(amountToken, 1e6, 1e6, uint256(oracleUsdt.latestAnswer()), uint256(oracleUsdc.latestAnswer()));
            } else if (token == address(bbaDai)) {
                // bpt token convert to underlying tokens by Rate
                // e18 + e18 - e18 = e18
                amountToken = amountToken * bbaDai.getRate() / 1e18;
                totalBalanceUsdc += ChainlinkLibrary.convertTokenToToken(amountToken, 1e18, 1e6, uint256(oracleDai.latestAnswer()), uint256(oracleUsdc.latestAnswer()));
            }
        }

        return totalBalanceUsdc;
    }


    function _calcAmountBPTbyUSDC(uint256 _amountUsdc) internal returns (uint256){

        // Add 0.1% for slippage
        _amountUsdc = OvnMath.addBasisPoints(_amountUsdc, 10);

        // 1) Swap USDC -> bb-aUSDC
        // 2) Swap bb-aUSDC -> stable BPT
        // 3) return amount stable BPT
        IVault.BatchSwapStep[] memory swaps = new IVault.BatchSwapStep[](2);
        swaps[0] = IVault.BatchSwapStep(aUsdcPoolId, 0, 1, _amountUsdc, new bytes(0));
        swaps[1] = IVault.BatchSwapStep(stablePoolId, 1, 2, 0, new bytes(0));

        IAsset[] memory assets = new IAsset[](3);
        assets[0] = IAsset(address(usdc));
        assets[1] = IAsset(address(bbaUsdc));
        assets[2] = IAsset(address(bpt));

        IVault.FundManagement memory fundManagement = IVault.FundManagement(address(this), false, payable(address(this)), false);

        return uint256(- vault.queryBatchSwap(IVault.SwapKind.GIVEN_IN, swaps, assets, fundManagement)[2]);
    }


    function _claimRewards(address _beneficiary) internal override returns (uint256) {

        if (gauge.balanceOf(address(this)) == 0) {
            return 0;
        }

        gauge.claim_rewards();

        uint256 totalUsdc;
        uint256 opBalance = op.balanceOf(address(this));
        uint256 sonneBalance = sonne.balanceOf(address(this));

        if (opBalance > 0) {

            uint256 opUsdc = VelodromeLibrary.singleSwap(
                velodromeRouter,
                address(op),
                address(usdc),
                false,
                opBalance,
                0,
                address(this)
            );

            totalUsdc += opUsdc;
        }

        if (sonneBalance > 0) {

            uint256 sonneUsdc = VelodromeLibrary.singleSwap(
                velodromeRouter,
                address(sonne),
                address(usdc),
                false,
                    sonneBalance,
                0,
                address(this)
            );

            totalUsdc += sonneUsdc;
        }


        if (totalUsdc > 0) {
            usdc.transfer(_beneficiary, totalUsdc);
        }

        return totalUsdc;
    }

}

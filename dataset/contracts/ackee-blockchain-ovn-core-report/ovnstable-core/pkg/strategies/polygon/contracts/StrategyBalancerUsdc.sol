// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/connectors/contracts/stuff/Balancer.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";
import "@overnight-contracts/connectors/contracts/stuff/Chainlink.sol";


contract StrategyBalancerUsdc is Strategy {

    // --- params

    IERC20 public usdc;
    IERC20 public bal;

    IBptToken public bbamUsdc;
    IBptToken public bbamUsdt;
    IBptToken public bbamDai;
    IBptToken public bpt;

    IVault public vault;
    IGauge public gauge;
    
    bytes32 public bbamUsdcPoolId;
    bytes32 public bbamUsdPoolId;
    bytes32 public balPoolId;

    IPriceFeed public oracleUsdc;
    IPriceFeed public oracleUsdt;
    IPriceFeed public oracleDai;

    uint256 public swapSlippageBp;
    uint256 public allowedSlippageBp;


    // --- events

    event StrategyUpdatedParams();


    // --- structs

    struct StrategyParams {
        address usdc;
        address bal;
        address bbamUsdc;
        address bbamUsdt;
        address bbamDai;
        address bpt;
        address vault;
        address gauge;
        bytes32 bbamUsdcPoolId;
        bytes32 bbamUsdPoolId;
        bytes32 balPoolId;
        address oracleUsdc;
        address oracleUsdt;
        address oracleDai;
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
        bal = IERC20(params.bal);

        bbamUsdc = IBptToken(params.bbamUsdc);
        bbamUsdt = IBptToken(params.bbamUsdt);
        bbamDai = IBptToken(params.bbamDai);
        bpt = IBptToken(params.bpt);

        vault = IVault(params.vault);
        gauge = IGauge(params.gauge);

        bbamUsdcPoolId = params.bbamUsdcPoolId;
        bbamUsdPoolId = params.bbamUsdPoolId;
        balPoolId = params.balPoolId;

        oracleUsdc = IPriceFeed(params.oracleUsdc);
        oracleUsdt = IPriceFeed(params.oracleUsdt);
        oracleDai = IPriceFeed(params.oracleDai);

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
        // 3. Stake bpt tokens to gauge

        // 1. Before put liquidity to Stable pool need to swap USDC to bb-aUSDC (linear pool token)
        uint256 usdcBalance = usdc.balanceOf(address(this));
        uint256 minAmountBbamUsdc = OvnMath.subBasisPoints(usdcBalance * 1e30 / bbamUsdc.getRate(), swapSlippageBP);
        BalancerLibrary.swap(
            vault,
            IVault.SwapKind.GIVEN_IN,
            address(usdc),
            address(bbamUsdc),
            bbamUsdcPoolId,
            usdcBalance,
            minAmountBbamUsdc,
            address(this),
            address(this)
        );

        (IERC20[] memory tokens,,) = vault.getPoolTokens(bbamUsdPoolId);

        IAsset[] memory assets = new IAsset[](4);
        uint256[] memory maxAmountsIn = new uint256[](4);

        // Must be without bpt fantom token
        uint256[] memory amountsIn = new uint256[](3);

        for (uint256 i; i < tokens.length; i++) {
            assets[i] = IAsset(address(tokens[i]));
        }

        uint256 bbamUsdcAmount = bbamUsdc.balanceOf(address(this));

        // 2 - USDC index
        maxAmountsIn[2] = bbamUsdcAmount;

        // 1 - USDC index
        amountsIn[1] = bbamUsdcAmount;

        uint256 joinKind = 1;
        uint256 minimumBPT = 1;
        bytes memory userData = abi.encode(joinKind, amountsIn, minimumBPT);

        IVault.JoinPoolRequest memory request = IVault.JoinPoolRequest(assets, maxAmountsIn, userData, false);

        // 2. Put bb-am-USDC to Stable pool
        bbamUsdc.approve(address(vault), bbamUsdcAmount);
        vault.joinPool(bbamUsdPoolId, address(this), address(this), request);

        // 3. Put bpt tokens to Gauge
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

        uint256 bptAmount = BalancerLibrary.queryBatchSwap(
            vault,
            IVault.SwapKind.GIVEN_IN,
            address(usdc),
            address(bbamUsdc),
            address(bpt),
            bbamUsdcPoolId,
            bbamUsdPoolId,
            OvnMath.addBasisPoints(_amount, swapSlippageBP),
            address(this),
            address(this)
        );

        return _unstakeUsdc(bptAmount);
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdc), "Some token not compatible");

        uint256 bptAmount = gauge.balanceOf(address(this));

        return _unstakeUsdc(bptAmount);
    }


    function _unstakeUsdc(uint256 bptAmount) internal returns (uint256){

        // How it work?
        // 1. Unstake bpt tokens from Gauge
        // 2. Get all bb-am-USDC from stable pool
        // 3. Swap all bb-am-USDC to USDC by linear pool

        // 1. Unstake bpt from Gauge
        gauge.withdraw(bptAmount);
        uint256 usdcAmount = _convertBptToUsdc(bptAmount);

        IAsset[] memory assets = new IAsset[](4);
        uint256[] memory minAmountsOut = new uint256[](4);

        (IERC20[] memory tokens,,) = vault.getPoolTokens(bbamUsdPoolId);

        for (uint256 i; i < tokens.length; i++) {
            assets[i] = IAsset(address(tokens[i]));
        }

        // EXACT_BPT_IN_FOR_ONE_TOKEN_OUT
        uint256 exitKind = 0;
        uint256 exitTokenIndex = 1;
        bytes memory userData = abi.encode(exitKind, bptAmount, exitTokenIndex);
        IVault.ExitPoolRequest memory request = IVault.ExitPoolRequest(assets, minAmountsOut, userData, false);

        // 2. Unstake from stable pool
        vault.exitPool(bbamUsdPoolId, address(this), payable(address(this)), request);

        // 3. Swap
        uint256 bbamUsdcBalance = bbamUsdc.balanceOf(address(this));
        uint256 minAmountUsdc = OvnMath.subBasisPoints(bbamUsdcBalance * bbamUsdc.getRate() / 1e30, swapSlippageBP);
        BalancerLibrary.swap(
            vault,
            IVault.SwapKind.GIVEN_IN,
            address(bbamUsdc),
            address(usdc),
            bbamUsdcPoolId,
            bbamUsdcBalance,
            minAmountUsdc,
            address(this),
            address(this)
        );

        return usdc.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {
        return _totalValue();
    }

    function liquidationValue() external view override returns (uint256) {
        return _totalValue();
    }

    function _totalValue() internal view returns (uint256){
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

        (IERC20[] memory tokens, uint256[] memory balances,) = vault.getPoolTokens(bbamUsdPoolId);

        // How it work?
        // 1. Calculating share (bb-am-USDC,bb-am-DAI,bb-am-USDT)
        // 2. Convert bb-* tokens to underlying tokens (DAI,USDC,USDT)
        // 3. Convert tokens (DAI,USDT) to USDC through Chainlink oracle

        // Iterate thought liquidity tokens (bb-am-DAI,bb-am-USDC,bb-am-USDT) not main bpt
        for (uint256 i = 0; i < tokens.length; i++) {

            address token = address(tokens[i]);

            // calculate share
            uint256 amountToken = balances[i] * bptAmount / totalActualSupply;

            if (token == address(bbamUsdc)) {
                // bpt token convert to underlying tokens by Rate
                // e18 + e18 - e30 = e6
                amountToken = amountToken * bbamUsdc.getRate() / 1e30;
                totalBalanceUsdc += amountToken;
            } else if (token == address(bbamUsdt)) {
                // bpt token convert to underlying tokens by Rate
                // e18 + e18 - e30 = e6
                amountToken = amountToken * bbamUsdt.getRate() / 1e30;
                totalBalanceUsdc += ChainlinkLibrary.convertTokenToToken(amountToken, 1e6, 1e6, uint256(oracleUsdt.latestAnswer()), uint256(oracleUsdc.latestAnswer()));
            } else if (token == address(bbamDai)) {
                // bpt token convert to underlying tokens by Rate
                // e18 + e18 - e18 = e18
                amountToken = amountToken * bbamDai.getRate() / 1e18;
                totalBalanceUsdc += ChainlinkLibrary.convertTokenToToken(amountToken, 1e18, 1e6, uint256(oracleDai.latestAnswer()), uint256(oracleUsdc.latestAnswer()));
            }

        }

        return totalBalanceUsdc;
    }

    function _claimRewards(address _beneficiary) internal override returns (uint256) {

        // claim rewards
        if (gauge.balanceOf(address(this)) > 0) {
            gauge.claim_rewards();
        }

        // sell rewards
        uint256 totalUsdc;

        uint256 balBalance = bal.balanceOf(address(this));
        if (balBalance > 0) {
            totalUsdc += BalancerLibrary.swap(
                vault,
                IVault.SwapKind.GIVEN_IN,
                address(bal),
                address(usdc),
                balPoolId,
                balBalance,
                0,
                address(this),
                address(this)
            );
        }

        if (totalUsdc > 0) {
            usdc.transfer(_beneficiary, totalUsdc);
        }

        return totalUsdc;
    }

}

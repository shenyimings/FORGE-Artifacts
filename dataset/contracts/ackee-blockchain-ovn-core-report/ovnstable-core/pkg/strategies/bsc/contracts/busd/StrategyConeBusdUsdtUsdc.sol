// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/connectors/contracts/stuff/Cone.sol";
import "@overnight-contracts/connectors/contracts/stuff/Unknown.sol";
import "@overnight-contracts/connectors/contracts/stuff/Synapse.sol";
import "@overnight-contracts/connectors/contracts/stuff/Chainlink.sol";

import "hardhat/console.sol";

contract StrategyConeBusdUsdtUsdc is Strategy {

    // --- structs

    struct StrategyParams {
        address busdToken;
        address usdtToken;
        address usdcToken;
        address wBnbToken;
        address coneToken;
        address coneRouter;
        address conePair;
        address coneGauge;
        address synapseStableSwapPool;
        address chainlinkBusd;
        address chainlinkUsdt;
        address chainlinkUsdc;
        address rewardWallet;
        uint256 rewardWalletPercent;
        address unkwnToken;
        address unkwnUserProxy;
        address unkwnLens;
        uint256 unkwnPercent;
    }

    // --- params

    IERC20 public busdToken;
    IERC20 public usdtToken;
    IERC20 public usdcToken;
    IERC20 public wBnbToken;
    IERC20 public coneToken;

    IConeRouter01 public coneRouter;
    IConePair public conePair;
    IGauge public coneGauge;

    ISwap public synapseStableSwapPool;

    IPriceFeed public chainlinkBusd;
    IPriceFeed public chainlinkUsdt;
    IPriceFeed public chainlinkUsdc;

    address public rewardWallet;
    uint256 public rewardWalletPercent;

    uint256 public busdTokenDenominator;
    uint256 public usdtTokenDenominator;
    uint256 public usdcTokenDenominator;

    IERC20 public unkwnToken;
    IUserProxy public unkwnUserProxy;
    IUnkwnLens public unkwnLens;
    uint256 public unkwnPercent;

    // --- events

    event StrategyUpdatedParams();

    // --- constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }

    // --- setters

    function setParams(StrategyParams calldata params) external onlyAdmin {

        busdToken = IERC20(params.busdToken);
        usdtToken = IERC20(params.usdtToken);
        usdcToken = IERC20(params.usdcToken);
        wBnbToken = IERC20(params.wBnbToken);
        coneToken = IERC20(params.coneToken);

        coneRouter = IConeRouter01(params.coneRouter);
        conePair = IConePair(params.conePair);
        coneGauge = IGauge(params.coneGauge);

        synapseStableSwapPool = ISwap(params.synapseStableSwapPool);

        chainlinkBusd = IPriceFeed(params.chainlinkBusd);
        chainlinkUsdt = IPriceFeed(params.chainlinkUsdt);
        chainlinkUsdc = IPriceFeed(params.chainlinkUsdc);

        rewardWallet = params.rewardWallet;
        rewardWalletPercent = params.rewardWalletPercent;

        busdTokenDenominator = 10 ** IERC20Metadata(params.busdToken).decimals();
        usdtTokenDenominator = 10 ** IERC20Metadata(params.usdtToken).decimals();
        usdcTokenDenominator = 10 ** IERC20Metadata(params.usdcToken).decimals();

        unkwnToken = IERC20(params.unkwnToken);
        unkwnUserProxy = IUserProxy(params.unkwnUserProxy);
        unkwnLens = IUnkwnLens(params.unkwnLens);
        unkwnPercent = params.unkwnPercent;

        emit StrategyUpdatedParams();
    }

    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(busdToken), "Some token not compatible");

        (uint256 reserveUsdt, uint256 reserveUsdc,) = conePair.getReserves();
        require(reserveUsdt > 10 ** 15 && reserveUsdc > 10 ** 15, 'Liquidity lpToken reserves too low');

        uint256 busdBalance = busdToken.balanceOf(address(this));
        (uint256 amountUsdtInBusd, uint256 amountUsdcInBusd) = SynapseLibrary.getAmounts(
            synapseStableSwapPool,
            address(usdtToken),
            address(usdcToken),
            address(busdToken),
            busdBalance,
            reserveUsdt,
            reserveUsdc,
            usdtTokenDenominator,
            usdcTokenDenominator,
            0
        );
//        console.log("amountUsdtInBusd: %s", amountUsdtInBusd);
//        console.log("amountUsdcInBusd: %s", amountUsdcInBusd);

        // swap busd to usdt
        SynapseLibrary.swap(
            synapseStableSwapPool,
            address(busdToken),
            address(usdtToken),
            amountUsdtInBusd
        );

        // swap busd to usdc
        SynapseLibrary.swap(
            synapseStableSwapPool,
            address(busdToken),
            address(usdcToken),
            amountUsdcInBusd
        );

        // add liquidity
        uint256 usdtBalance = usdtToken.balanceOf(address(this));
        uint256 usdcBalance = usdcToken.balanceOf(address(this));
        console.log("usdtBalance before: %s", usdtToken.balanceOf(address(this)));
        console.log("usdcBalance before: %s", usdcToken.balanceOf(address(this)));
        usdtToken.approve(address(coneRouter), usdtBalance);
        usdcToken.approve(address(coneRouter), usdcBalance);
        coneRouter.addLiquidity(
            address(usdtToken),
            address(usdcToken),
            true,
            usdtBalance,
            usdcBalance,
            usdtBalance * 99 / 100,
            usdcBalance * 99 / 100,
            address(this),
            block.timestamp
        );
        console.log("usdtBalance after: %s", usdtToken.balanceOf(address(this)));
        console.log("usdcBalance after: %s", usdcToken.balanceOf(address(this)));

        uint256 lpTokenBalance = conePair.balanceOf(address(this));
        uint256 lpTokenBalanceUnkwn = lpTokenBalance * unkwnPercent / 1e4;
        uint256 lpTokenBalanceGauge = lpTokenBalance - lpTokenBalanceUnkwn;

        // stake to unknown
        conePair.approve(address(unkwnUserProxy), lpTokenBalanceUnkwn);
        unkwnUserProxy.depositLpAndStake(address(conePair), lpTokenBalanceUnkwn);

        // stake to gauge
        conePair.approve(address(coneGauge), lpTokenBalanceGauge);
        // don't lock cone -> tokenId = 0
        coneGauge.deposit(lpTokenBalanceGauge, 0);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(busdToken), "Some token not compatible");

        (uint256 reserveUsdt, uint256 reserveUsdc,) = conePair.getReserves();
        require(reserveUsdt > 10 ** 15 && reserveUsdc > 10 ** 15, 'Liquidity lpToken reserves too low');

        // Fetch amount of LP currently staked
        uint256 lpTokenBalance = coneGauge.balanceOf(address(this));
        if (lpTokenBalance > 0) {
            // count amount to unstake
            uint256 totalLpBalance = conePair.totalSupply();
            console.log("_amount: %s", _amount);
            console.log("totalLpBalance: %s", totalLpBalance);
            console.log("reserveUsdt: %s", reserveUsdt);
            console.log("reserveUsdc: %s", reserveUsdc);
            uint256 lpTokensToWithdraw = SynapseLibrary.getAmountLpTokens(
                synapseStableSwapPool,
                address(usdtToken),
                address(usdcToken),
                address(busdToken),
                // add 0.1% to _amount for smooth withdraw
                _amount * 1001 / 1000,
                totalLpBalance,
                reserveUsdt,
                reserveUsdc,
                usdtTokenDenominator,
                usdcTokenDenominator,
                0
            );
            console.log("lpTokensToWithdraw: %s", lpTokensToWithdraw);

            if (lpTokensToWithdraw > lpTokenBalance) {
                lpTokensToWithdraw = lpTokenBalance;
            }

            // unstake from gauge
            coneGauge.withdraw(lpTokensToWithdraw);

            uint256 unstakedLPTokenBalance = conePair.balanceOf(address(this));
            uint256 amountOutUsdtMin = reserveUsdt * unstakedLPTokenBalance / totalLpBalance;
            uint256 amountOutUsdcMin = reserveUsdc * unstakedLPTokenBalance / totalLpBalance;

//            console.log("usdtBalance before: %s", usdtToken.balanceOf(address(this)));
//            console.log("usdcBalance before: %s", usdcToken.balanceOf(address(this)));
            // remove liquidity
            conePair.approve(address(coneRouter), unstakedLPTokenBalance);
            coneRouter.removeLiquidity(
                address(usdtToken),
                address(usdcToken),
                true,
                unstakedLPTokenBalance,
                amountOutUsdtMin * 99 / 100,
                amountOutUsdcMin * 99 / 100,
                address(this),
                block.timestamp
            );
//            console.log("usdtBalance after: %s", usdtToken.balanceOf(address(this)));
//            console.log("usdcBalance after: %s", usdcToken.balanceOf(address(this)));
        }

        // swap usdt to busd
        uint256 usdtBalance = usdtToken.balanceOf(address(this));
        if (usdtBalance > 0) {
            SynapseLibrary.swap(
                synapseStableSwapPool,
                address(usdtToken),
                address(busdToken),
                usdtBalance
            );
        }

        // swap usdc to busd
        uint256 usdcBalance = usdcToken.balanceOf(address(this));
        if (usdcBalance > 0) {
            SynapseLibrary.swap(
                synapseStableSwapPool,
                address(usdcToken),
                address(busdToken),
                usdcBalance
            );
        }
        console.log("busdBalance after: %s", busdToken.balanceOf(address(this)));

        return busdToken.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(busdToken), "Some token not compatible");

        (uint256 reserveUsdt, uint256 reserveUsdc,) = conePair.getReserves();
        require(reserveUsdt > 10 ** 15 && reserveUsdc > 10 ** 15, 'Liquidity lpToken reserves too low');

        // unstake from gauge
        uint256 lpTokenBalanceGauge = coneGauge.balanceOf(address(this));
        if (lpTokenBalanceGauge > 0) {
            coneGauge.withdrawAll();
        }

        // unstake from unknown
        address userProxyThis = unkwnLens.userProxyByAccount(address(this));
        address stakingAddress = unkwnLens.stakingRewardsByConePool(address(conePair));
        uint256 lpTokenBalanceUnkwn = IERC20(stakingAddress).balanceOf(userProxyThis);
        if (lpTokenBalanceUnkwn > 0) {
            unkwnUserProxy.unstakeLpAndWithdraw(address(conePair), lpTokenBalanceUnkwn);
        }

        uint256 unstakedLPTokenBalance = conePair.balanceOf(address(this));
        if (unstakedLPTokenBalance > 0) {
            uint256 totalLpBalance = conePair.totalSupply();
            uint256 amountOutUsdtMin = reserveUsdt * unstakedLPTokenBalance / totalLpBalance;
            uint256 amountOutUsdcMin = reserveUsdc * unstakedLPTokenBalance / totalLpBalance;

            // remove liquidity
            conePair.approve(address(coneRouter), unstakedLPTokenBalance);
            coneRouter.removeLiquidity(
                address(usdtToken),
                address(usdcToken),
                true,
                unstakedLPTokenBalance,
                amountOutUsdtMin * 99 / 100,
                amountOutUsdcMin * 99 / 100,
                address(this),
                block.timestamp
            );
        }

        // swap usdt to busd
        uint256 usdtBalance = usdtToken.balanceOf(address(this));
        if (usdtBalance > 0) {
            SynapseLibrary.swap(
                synapseStableSwapPool,
                address(usdtToken),
                address(busdToken),
                usdtBalance
            );
        }

        // swap usdc to busd
        uint256 usdcBalance = usdcToken.balanceOf(address(this));
        if (usdcBalance > 0) {
            SynapseLibrary.swap(
                synapseStableSwapPool,
                address(usdcToken),
                address(busdToken),
                usdcBalance
            );
        }

        return busdToken.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {
        return _totalValue(true);
    }

    function liquidationValue() external view override returns (uint256) {
        return _totalValue(false);
    }

    function _totalValue(bool nav) internal view returns (uint256) {
        uint256 busdBalance = busdToken.balanceOf(address(this));
        uint256 usdtBalance = usdtToken.balanceOf(address(this));
        uint256 usdcBalance = usdcToken.balanceOf(address(this));

        // Fetch amount of LP currently staked
        uint256 lpTokenBalance = coneGauge.balanceOf(address(this));
        address userProxyThis = unkwnLens.userProxyByAccount(address(this));
        address stakingAddress = unkwnLens.stakingRewardsByConePool(address(conePair));
        lpTokenBalance += IERC20(stakingAddress).balanceOf(userProxyThis);
        if (lpTokenBalance > 0) {
            uint256 totalLpBalance = conePair.totalSupply();
            (uint256 reserveUsdt, uint256 reserveUsdc,) = conePair.getReserves();
            usdtBalance += reserveUsdt * lpTokenBalance / totalLpBalance;
            usdcBalance += reserveUsdc * lpTokenBalance / totalLpBalance;
        }

        // usdt to busd
        uint256 busdBalanceFromUsdt;
        if (usdtBalance > 0) {
            if (nav) {
                uint256 priceBusd = uint256(chainlinkBusd.latestAnswer());
                uint256 priceUsdt = uint256(chainlinkUsdt.latestAnswer());
                busdBalanceFromUsdt = (usdtBalance * busdTokenDenominator * priceUsdt) / (usdtTokenDenominator * priceBusd);
            } else {
                busdBalanceFromUsdt = SynapseLibrary.calculateSwap(
                    synapseStableSwapPool,
                    address(usdtToken),
                    address(busdToken),
                    usdtBalance
                );
            }
        }

        // usdc to busd
        uint256 busdBalanceFromUsdc;
        if (usdcBalance > 0) {
            if (nav) {
                uint256 priceBusd = uint256(chainlinkBusd.latestAnswer());
                uint256 priceUsdc = uint256(chainlinkUsdc.latestAnswer());
                busdBalanceFromUsdc = (usdcBalance * busdTokenDenominator * priceUsdc) / (usdcTokenDenominator * priceBusd);
            } else {
                busdBalanceFromUsdc = SynapseLibrary.calculateSwap(
                    synapseStableSwapPool,
                    address(usdcToken),
                    address(busdToken),
                    usdcBalance
                );
            }
        }

        return busdBalance + busdBalanceFromUsdt + busdBalanceFromUsdc;
    }

    function _claimRewards(address _to) internal override returns (uint256) {

        // claim rewards gauge
        uint256 lpTokenBalanceGauge = coneGauge.balanceOf(address(this));
        if (lpTokenBalanceGauge > 0) {
            address[] memory tokens = new address[](1);
            tokens[0] = address(coneToken);
            coneGauge.getReward(address(this), tokens);
        }

        // claim rewards unknown
        address userProxyThis = unkwnLens.userProxyByAccount(address(this));
        address stakingAddress = unkwnLens.stakingRewardsByConePool(address(conePair));
        uint256 lpTokenBalanceUnkwn = IERC20(stakingAddress).balanceOf(userProxyThis);
        if (lpTokenBalanceUnkwn > 0) {
            unkwnUserProxy.claimStakingRewards();
        }

        // sell rewards
        uint256 totalBusd;

        uint256 coneBalance = coneToken.balanceOf(address(this));
        if (coneBalance > 0) {
            uint256 amountOutCone = ConeLibrary.getAmountsOut(
                coneRouter,
                address(coneToken),
                address(wBnbToken),
                address(busdToken),
                // TODO тут возможно надо поменять на true, но у меня в тестах с false выгоднее обмен раз в 10
                false,
                false,
                coneBalance
            );

            if (amountOutCone > 0) {
                uint256 coneBusd = ConeLibrary.swap(
                    coneRouter,
                    address(coneToken),
                    address(wBnbToken),
                    address(busdToken),
                    // TODO тут возможно надо поменять на true, но у меня в тестах с false выгоднее обмен раз в 10
                    false,
                    false,
                    coneBalance,
                    amountOutCone * 99 / 100,
                    address(this)
                );

                totalBusd += coneBusd;
            }
        }

        uint256 unkwnBalance = unkwnToken.balanceOf(address(this));
        if (unkwnBalance > 0) {
            uint256 amountOutUnkwn = ConeLibrary.getAmountsOut(
                coneRouter,
                address(unkwnToken),
                address(wBnbToken),
                address(busdToken),
                false,
                false,
                unkwnBalance
            );

            if (amountOutUnkwn > 0) {
                uint256 unkwnBusd = ConeLibrary.swap(
                    coneRouter,
                    address(unkwnToken),
                    address(wBnbToken),
                    address(busdToken),
                    false,
                    false,
                    unkwnBalance,
                    amountOutUnkwn * 99 / 100,
                    address(this)
                );

                totalBusd += unkwnBusd;
            }
        }

        if (totalBusd > 0) {
            uint256 rewardBalance = totalBusd * rewardWalletPercent / 1e4;
            uint256 toBalance = totalBusd - rewardBalance;
            busdToken.transfer(rewardWallet, rewardBalance);
            busdToken.transfer(_to, toBalance);
        }

        return totalBusd;
    }

}

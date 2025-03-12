// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/connectors/contracts/stuff/Cone.sol";
import "@overnight-contracts/connectors/contracts/stuff/Unknown.sol";
import "@overnight-contracts/connectors/contracts/stuff/Chainlink.sol";
import "@overnight-contracts/connectors/contracts/stuff/Annex.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";

contract StrategyUnknownBusdTusd is Strategy {

    // --- structs

    struct StrategyParams {
        address busdToken;
        address tusdToken;
        address wBnbToken;
        address coneToken;
        address coneRouter;
        address conePair;
        address chainlinkBusd;
        address chainlinkTusd;
        address rewardWallet;
        uint256 rewardWalletPercent;
        address unkwnToken;
        address unkwnUserProxy;
        address unkwnLens;
        uint256 stakeStep;
        address annexStablePool;
    }

    // --- params

    IERC20 public busdToken;
    IERC20 public tusdToken;
    IERC20 public wBnbToken;
    IERC20 public coneToken;

    IConeRouter01 public coneRouter;
    IConePair public conePair;

    IPriceFeed public chainlinkBusd;
    IPriceFeed public chainlinkTusd;

    address public rewardWallet;
    uint256 public rewardWalletPercent;

    uint256 public busdTokenDenominator;
    uint256 public tusdTokenDenominator;

    IERC20 public unkwnToken;
    IUserProxy public unkwnUserProxy;
    IUnkwnLens public unkwnLens;

    uint256 public stakeStep;

    address public annexStablePool;

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
        tusdToken = IERC20(params.tusdToken);
        wBnbToken = IERC20(params.wBnbToken);
        coneToken = IERC20(params.coneToken);

        coneRouter = IConeRouter01(params.coneRouter);
        conePair = IConePair(params.conePair);

        chainlinkBusd = IPriceFeed(params.chainlinkBusd);
        chainlinkTusd = IPriceFeed(params.chainlinkTusd);

        annexStablePool = params.annexStablePool;

        rewardWallet = params.rewardWallet;
        rewardWalletPercent = params.rewardWalletPercent;

        busdTokenDenominator = 10 ** IERC20Metadata(params.busdToken).decimals();
        tusdTokenDenominator = 10 ** IERC20Metadata(params.tusdToken).decimals();

        unkwnToken = IERC20(params.unkwnToken);
        unkwnUserProxy = IUserProxy(params.unkwnUserProxy);
        unkwnLens = IUnkwnLens(params.unkwnLens);

        stakeStep = params.stakeStep;

        emit StrategyUpdatedParams();
    }

    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(busdToken), "Some token not compatible");

        (uint256 reserveTusd, uint256 reserveBusd,) = conePair.getReserves();
        require(reserveTusd > 10 ** 15 && reserveBusd > 10 ** 15, 'Liquidity lpToken reserves too low');

        uint256 busdBalance = busdToken.balanceOf(address(this));
        uint256 tusdBalance = tusdToken.balanceOf(address(this));

        uint256 priceBusd = uint256(chainlinkBusd.latestAnswer());
        uint256 priceTusd = uint256(chainlinkTusd.latestAnswer());
        uint256 busdBalanceFromTusd = (tusdBalance * busdTokenDenominator * priceTusd) / (tusdTokenDenominator * priceBusd);

        uint256 amountBusdToSwap = _getAmountTusdInBusd(
            busdBalance - busdBalanceFromTusd,
            reserveBusd,
            reserveTusd,
            1
        );

        AnnexLibrary.swap(
            address(busdToken),
            address(tusdToken),
            amountBusdToSwap,
            amountBusdToSwap * 99 / 100,
            annexStablePool
        );

        (reserveTusd, reserveBusd,) = conePair.getReserves();

        busdBalance = busdToken.balanceOf(address(this));
        tusdBalance = tusdToken.balanceOf(address(this));

        uint256 amountTusdMin = busdBalance * reserveTusd / reserveBusd;
        if (amountTusdMin > tusdBalance) {
            amountTusdMin = tusdBalance;
        }
        uint256 amountBusdMin = tusdBalance * reserveBusd / reserveTusd;
        if (amountBusdMin > busdBalance) {
            amountBusdMin = busdBalance;
        }

        // add liquidity
        busdToken.approve(address(coneRouter), busdBalance);
        tusdToken.approve(address(coneRouter), tusdBalance);
        coneRouter.addLiquidity(
            address(busdToken),
            address(tusdToken),
            true,
            busdBalance,
            tusdBalance,
            amountBusdMin * 99 / 100,
            amountTusdMin * 99 / 100,
            address(this),
            block.timestamp
        );

        busdBalance = busdToken.balanceOf(address(this));
        tusdBalance = tusdToken.balanceOf(address(this));

        // stake to unknown
        uint256 lpTokenBalance = conePair.balanceOf(address(this));
        conePair.approve(address(unkwnUserProxy), lpTokenBalance);
        unkwnUserProxy.depositLpAndStake(address(conePair), lpTokenBalance);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(busdToken), "Some token not compatible");

        (uint256 reserveTusd, uint256 reserveBusd,) = conePair.getReserves();
        require(reserveTusd > 10 ** 15 && reserveBusd > 10 ** 15, 'Liquidity lpToken reserves too low');

        // Fetch amount of LP currently staked
        uint256 lpTokenBalance = UnknownLibrary.getUserLpBalance(unkwnLens, address(conePair), address(this));
        if (lpTokenBalance > 0) {
            // count amount to unstake
            uint256 totalLpBalance = conePair.totalSupply();
            uint256 lpTokensToWithdraw = _getAmountLpTokens(
            // add 4bp and 1e14 to _amount for smooth withdraw
                OvnMath.addBasisPoints(_amount, 4) + 1e14,
                totalLpBalance,
                reserveBusd,
                reserveTusd,
                1
            );

            if (lpTokensToWithdraw > lpTokenBalance) {
                lpTokensToWithdraw = lpTokenBalance;
            }

            // unstake from unknown
            unkwnUserProxy.unstakeLpAndWithdraw(address(conePair), lpTokensToWithdraw);

            uint256 unstakedLPTokenBalance = conePair.balanceOf(address(this));
            uint256 amountOutBusdMin = reserveBusd * unstakedLPTokenBalance / totalLpBalance;
            uint256 amountOutTusdMin = reserveTusd * unstakedLPTokenBalance / totalLpBalance;

            // remove liquidity
            conePair.approve(address(coneRouter), unstakedLPTokenBalance);
            coneRouter.removeLiquidity(
                address(busdToken),
                address(tusdToken),
                true,
                unstakedLPTokenBalance,
                amountOutBusdMin * 99 / 100,
                amountOutTusdMin * 99 / 100,
                address(this),
                block.timestamp
            );
        }

        // swap tusd to busd
        uint256 tusdBalance = tusdToken.balanceOf(address(this));
        if (tusdBalance > 0) {

            uint256 amountMin = AnnexLibrary.getAmountOut(
                address(tusdToken),
                address(busdToken),
                tusdBalance,
                annexStablePool
            );

            AnnexLibrary.swap(
                address(tusdToken),
                address(busdToken),
                tusdBalance,
                amountMin,
                annexStablePool
            );
        }

        return busdToken.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(busdToken), "Some token not compatible");

        (uint256 reserveTusd, uint256 reserveBusd,) = conePair.getReserves();
        require(reserveTusd > 10 ** 15 && reserveBusd > 10 ** 15, 'Liquidity lpToken reserves too low');

        // unstake from unknown
        uint256 lpTokenBalance = UnknownLibrary.getUserLpBalance(unkwnLens, address(conePair), address(this));
        if (lpTokenBalance > 0) {
            unkwnUserProxy.unstakeLpAndWithdraw(address(conePair), lpTokenBalance);
        }

        uint256 unstakedLPTokenBalance = conePair.balanceOf(address(this));
        if (unstakedLPTokenBalance > 0) {
            uint256 totalLpBalance = conePair.totalSupply();
            uint256 amountOutBusdMin = reserveBusd * unstakedLPTokenBalance / totalLpBalance;
            uint256 amountOutTusdMin = reserveTusd * unstakedLPTokenBalance / totalLpBalance;

            // remove liquidity
            conePair.approve(address(coneRouter), unstakedLPTokenBalance);
            coneRouter.removeLiquidity(
                address(busdToken),
                address(tusdToken),
                true,
                unstakedLPTokenBalance,
                amountOutBusdMin * 99 / 100,
                amountOutTusdMin * 99 / 100,
                address(this),
                block.timestamp
            );
        }

        // swap tusd to busd
        uint256 tusdBalance = tusdToken.balanceOf(address(this));
        if (tusdBalance > 0) {
            uint256 amountMin = AnnexLibrary.getAmountOut(
                address(tusdToken),
                address(busdToken),
                tusdBalance,
                annexStablePool
            );

            AnnexLibrary.swap(
                address(tusdToken),
                address(busdToken),
                tusdBalance,
                amountMin,
                annexStablePool
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
        uint256 tusdBalance = tusdToken.balanceOf(address(this));

        // Fetch amount of LP currently staked
        uint256 lpTokenBalance = UnknownLibrary.getUserLpBalance(unkwnLens, address(conePair), address(this));
        if (lpTokenBalance > 0) {
            uint256 totalLpBalance = conePair.totalSupply();
            (uint256 reserveTusd, uint256 reserveBusd,) = conePair.getReserves();
            busdBalance += reserveBusd * lpTokenBalance / totalLpBalance;
            tusdBalance += reserveTusd * lpTokenBalance / totalLpBalance;
        }

        uint256 busdBalanceFromTusd;
        if (tusdBalance > 0) {
            if (nav) {
                uint256 priceBusd = uint256(chainlinkBusd.latestAnswer());
                uint256 priceTusd = uint256(chainlinkTusd.latestAnswer());
                busdBalanceFromTusd = (tusdBalance * busdTokenDenominator * priceTusd) / (tusdTokenDenominator * priceBusd);
            } else {
                busdBalanceFromTusd = AnnexLibrary.getAmountOut(
                    address(tusdToken),
                    address(busdToken),
                    tusdBalance,
                    annexStablePool
                );
            }
        }

        return busdBalance + busdBalanceFromTusd;
    }

    function _claimRewards(address _to) internal override returns (uint256) {

        // claim rewards unknown
        uint256 lpTokenBalance = UnknownLibrary.getUserLpBalance(unkwnLens, address(conePair), address(this));
        if (lpTokenBalance > 0) {
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

    function _getAmountTusdInBusd(
        uint256 amountBusdTotal,
        uint256 reserveBusd,
        uint256 reserveTusd,
        uint256 precision
    ) internal view returns (uint256 amountTusdInBusd) {
        amountTusdInBusd = (amountBusdTotal * reserveTusd) / (reserveBusd * tusdTokenDenominator / busdTokenDenominator + reserveTusd);
        for (uint i = 0; i < precision; i++) {
            uint256 amountTusd = AnnexLibrary.getAmountOut(
                address(busdToken),
                address(tusdToken),
                amountTusdInBusd,
                annexStablePool
            );
            amountTusdInBusd = (amountBusdTotal * reserveTusd) / (reserveBusd * amountTusd / amountTusdInBusd + reserveTusd);
        }
    }

    function _getAmountBusdInTusd(
        uint256 amountTusdTotal,
        uint256 reserveTusd,
        uint256 reserveBusd,
        uint256 precision
    ) internal view returns (uint256 amountBusdInTusd) {
        amountBusdInTusd = (amountTusdTotal * reserveBusd) / (reserveTusd * tusdTokenDenominator / busdTokenDenominator + reserveBusd);
        for (uint i = 0; i < precision; i++) {
            uint256 amountBusd = AnnexLibrary.getAmountOut(
                address(busdToken),
                address(tusdToken),
                amountBusdInTusd,
                annexStablePool
            );
            amountBusdInTusd = (amountTusdTotal * reserveBusd) / (reserveTusd * amountBusd / amountBusdInTusd + reserveBusd);
        }
    }

    function _getAmountLpTokens(
        uint256 amountBusdTotal,
        uint256 totalAmountLpTokens,
        uint256 reserveBusd,
        uint256 reserveTusd,
        uint256 precision
    ) internal view returns (uint256 amountLpTokens) {
        amountLpTokens = (totalAmountLpTokens * amountBusdTotal) / (reserveBusd + reserveTusd * busdTokenDenominator / tusdTokenDenominator);
        for (uint i = 0; i < precision; i++) {
            uint256 amountTusd = reserveTusd * amountLpTokens / totalAmountLpTokens;
            uint256 amountBusd = AnnexLibrary.getAmountOut(
                address(tusdToken),
                address(busdToken),
                amountTusd,
                annexStablePool
            );
            amountLpTokens = (totalAmountLpTokens * amountBusdTotal) / (reserveBusd + reserveTusd * amountBusd / amountTusd);
        }
    }

}

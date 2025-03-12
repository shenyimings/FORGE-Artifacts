// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

// solhint-disable-next-line
import {IERC20Permit} from "../../shared/IERC20Permit.sol";
import {AggregatorV2V3Interface} from "../../vendor/flux/interfaces/AggregatorV2V3Interface.sol";
import {IUniswapV2Pair} from "../../vendor/uniswap/v2-core/interfaces/IUniswapV2Pair.sol";
import {IKrStaking} from "../../staking/interfaces/IKrStaking.sol";
import {LibDecimals} from "../libs/LibDecimals.sol";
import {WadRay} from "../../libs/WadRay.sol";
import {Error} from "../../libs/Errors.sol";
import {IUniswapV2OracleCompat} from "../amm-oracle/IUniswapV2OracleCompat.sol";
import {KrAsset, CollateralAsset} from "../MinterTypes.sol";
import {MinterState, ms} from "../MinterStorage.sol";
import {irs} from "../InterestRateState.sol";

/* solhint-disable contract-name-camelcase */
/* solhint-disable var-name-mixedcase */

/**
 * @title Library for UI related views
 * @author Kresko
 */
library LibUI {
    using LibDecimals for uint256;
    using WadRay for uint256;

    struct CollateralAssetInfoUser {
        address assetAddress;
        address oracleAddress;
        address anchorAddress;
        uint256 amount;
        uint256 amountUSD;
        uint256 cFactor;
        uint256 liquidationIncentive;
        uint8 decimals;
        uint256 index;
        uint256 price;
        string symbol;
        string name;
    }

    struct CollateralAssetInfo {
        address assetAddress;
        address oracleAddress;
        address anchorAddress;
        uint256 price;
        uint256 value;
        uint256 liquidationIncentive;
        uint256 cFactor;
        uint8 decimals;
        string symbol;
        string name;
        bool marketOpen;
    }

    struct ProtocolParams {
        uint256 minDebtValue;
        uint256 minCollateralRatio;
        uint256 liquidationThreshold;
    }

    struct krAssetInfo {
        address oracleAddress;
        address assetAddress;
        address anchorAddress;
        uint256 price;
        uint256 ammPrice;
        uint256 priceRate;
        uint256 stabilityRate;
        uint256 value;
        uint256 openFee;
        uint256 closeFee;
        uint256 kFactor;
        string symbol;
        string name;
        bool marketOpen;
    }

    struct KreskoUser {
        krAssetInfoUser[] krAssets;
        CollateralAssetInfoUser[] collateralAssets;
        uint256 healthFactor;
        uint256 debtActualUSD;
        uint256 debtUSD;
        uint256 collateralActualUSD;
        uint256 collateralUSD;
        uint256 minCollateralUSD;
        uint256 borrowingPowerUSD;
    }

    struct PairData {
        uint8 decimals0;
        uint8 decimals1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 totalSupply;
    }

    struct GenericInfo {
        address assetAddress;
        uint256 kFactor;
        uint256 cFactor;
        uint256 price;
        bool isKrAsset;
        bool isCollateral;
        uint256 debtAmount;
        uint256 depositAmount;
        uint256 walletBalance;
    }

    struct Price {
        uint256 price;
        uint256 timestamp;
        address assetAddress;
        uint80 roundId;
        bool marketOpen;
    }

    struct Allowance {
        address owner;
        address spender;
        uint256 allowance;
    }

    struct Balance {
        address token;
        uint256 balance;
    }

    struct TokenMetadata {
        uint8 decimals;
        string symbol;
        string name;
        uint256 totalSupply;
    }

    struct StakingData {
        uint256 pid;
        address depositToken;
        uint256 totalDeposits;
        uint256 allocPoint;
        uint256 rewardPerBlocks;
        uint256 lastRewardBlock;
        uint256 depositAmount;
        address[] rewardTokens;
        uint256[] rewardAmounts;
    }

    struct krAssetInfoUser {
        address assetAddress;
        address oracleAddress;
        address anchorAddress;
        uint256 amount;
        uint256 amountScaled;
        uint256 priceRate;
        uint256 stabilityRate;
        uint256 amountUSD;
        uint256 index;
        uint256 kFactor;
        uint256 price;
        uint256 ammPrice;
        string symbol;
        string name;
        uint256 openFee;
        uint256 closeFee;
    }

    function getBalances(address[] memory _tokens, address account) internal view returns (Balance[] memory balances) {
        balances = new Balance[](_tokens.length);
        for (uint256 i; i < _tokens.length; i++) {
            balances[i] = Balance({token: address(_tokens[i]), balance: IERC20Permit(_tokens[i]).balanceOf(account)});
        }
    }

    function getAllowances(
        address[] memory _tokens,
        address owner,
        address spender
    ) internal view returns (Allowance[] memory allowances) {
        allowances = new Allowance[](_tokens.length);
        for (uint256 i; i < _tokens.length; i++) {
            allowances[i] = Allowance({
                allowance: IERC20Permit(_tokens[i]).allowance(owner, spender),
                spender: spender,
                owner: owner
            });
        }
    }

    function getStakingData(address _account, address _staking) internal view returns (StakingData[] memory result) {
        IKrStaking staking = IKrStaking(_staking);
        IKrStaking.Reward[] memory rewards = staking.allPendingRewards(_account);
        result = new StakingData[](rewards.length);

        for (uint256 i; i < rewards.length; i++) {
            IKrStaking.PoolInfo memory poolInfo = staking.poolInfo(rewards[i].pid);
            address depositTokenAddress = address(poolInfo.depositToken);
            result[i] = StakingData({
                pid: rewards[i].pid,
                totalDeposits: poolInfo.depositToken.balanceOf(_staking),
                allocPoint: poolInfo.allocPoint,
                depositToken: depositTokenAddress,
                depositAmount: staking.userInfo(rewards[i].pid, _account).amount,
                rewardTokens: rewards[i].tokens,
                rewardAmounts: rewards[i].amounts,
                rewardPerBlocks: staking.rewardPerBlockFor(depositTokenAddress),
                lastRewardBlock: poolInfo.lastRewardBlock
            });
        }
    }

    function borrowingPowerUSD(address _account) internal view returns (uint256) {
        uint256 minCollateral = ms().getAccountMinimumCollateralValueAtRatio(
            _account,
            ms().minimumCollateralizationRatio
        );
        uint256 collateral = ms().getAccountCollateralValue(_account);

        if (collateral < minCollateral) {
            return 0;
        } else {
            return collateral - minCollateral;
        }
    }

    function batchOracleValues(
        address[] memory _assets,
        address[] memory _priceFeeds,
        address[] memory _marketStatusFeeds
    ) internal view returns (Price[] memory result) {
        require(_marketStatusFeeds.length == _priceFeeds.length, Error.PRICEFEEDS_MUST_MATCH_STATUS_FEEDS);
        result = new Price[](_assets.length);
        for (uint256 i; i < _assets.length; i++) {
            result[i] = Price({
                price: uint256(AggregatorV2V3Interface(_priceFeeds[i]).latestAnswer()),
                timestamp: AggregatorV2V3Interface(_priceFeeds[i]).latestTimestamp(),
                assetAddress: _assets[i],
                roundId: uint80(AggregatorV2V3Interface(_priceFeeds[i]).latestRound()),
                marketOpen: AggregatorV2V3Interface(_marketStatusFeeds[i]).latestMarketOpen()
            });
        }
    }

    function krAssetInfos(address[] memory assetAddresses) internal view returns (krAssetInfo[] memory result) {
        result = new krAssetInfo[](assetAddresses.length);
        for (uint256 i; i < assetAddresses.length; i++) {
            address assetAddress = assetAddresses[i];
            KrAsset memory krAsset = ms().kreskoAssets[assetAddress];
            uint256 ammPrice;
            uint256 stabilityRate;
            uint256 priceRate;
            if (irs().srAssets[assetAddress].asset != address(0)) {
                ammPrice = IUniswapV2OracleCompat(ms().ammOracle).consultKrAsset(assetAddress, 1 ether);
                stabilityRate = irs().srAssets[assetAddress].calculateStabilityRate();
                priceRate = irs().srAssets[assetAddress].getPriceRate();
            }
            result[i] = krAssetInfo({
                value: ms().getKrAssetValue(assetAddress, 1 ether, false),
                oracleAddress: address(krAsset.oracle),
                anchorAddress: krAsset.anchor,
                assetAddress: assetAddress,
                closeFee: krAsset.closeFee,
                openFee: krAsset.openFee,
                kFactor: krAsset.kFactor,
                price: uint256(krAsset.oracle.latestAnswer()),
                stabilityRate: stabilityRate,
                priceRate: priceRate,
                ammPrice: ammPrice,
                marketOpen: krAsset.marketStatusOracle.latestMarketOpen(),
                symbol: IERC20Permit(assetAddress).symbol(),
                name: IERC20Permit(assetAddress).name()
            });
        }
    }

    function collateralAssetInfos(
        address[] memory assetAddresses
    ) internal view returns (CollateralAssetInfo[] memory result) {
        result = new CollateralAssetInfo[](assetAddresses.length);
        for (uint256 i; i < assetAddresses.length; i++) {
            address assetAddress = assetAddresses[i];
            CollateralAsset memory collateralAsset = ms().collateralAssets[assetAddress];
            uint8 decimals = IERC20Permit(assetAddress).decimals();

            (uint256 value, uint256 price) = ms().getCollateralValueAndOraclePrice(
                assetAddress,
                1 * 10 ** decimals,
                false
            );

            result[i] = CollateralAssetInfo({
                value: value,
                oracleAddress: address(collateralAsset.oracle),
                anchorAddress: collateralAsset.anchor,
                assetAddress: assetAddress,
                liquidationIncentive: collateralAsset.liquidationIncentive,
                cFactor: collateralAsset.factor,
                decimals: decimals,
                price: price,
                marketOpen: collateralAsset.marketStatusOracle.latestMarketOpen(),
                symbol: IERC20Permit(assetAddress).symbol(),
                name: IERC20Permit(assetAddress).name()
            });
        }
    }

    function collateralAssetInfoFor(
        address _account
    ) internal view returns (CollateralAssetInfoUser[] memory result, uint256 totalCollateralUSD) {
        address[] memory collateralAssetAddresses = ms().getDepositedCollateralAssets(_account);
        if (collateralAssetAddresses.length > 0) {
            result = new CollateralAssetInfoUser[](collateralAssetAddresses.length);
            for (uint256 i; i < collateralAssetAddresses.length; i++) {
                address assetAddress = collateralAssetAddresses[i];
                uint8 decimals = IERC20Permit(assetAddress).decimals();

                uint256 amount = ms().getCollateralDeposits(_account, assetAddress);

                (uint256 amountUSD, uint256 price) = ms().getCollateralValueAndOraclePrice(assetAddress, amount, true);

                totalCollateralUSD + amountUSD;
                result[i] = CollateralAssetInfoUser({
                    amount: amount,
                    amountUSD: amountUSD,
                    liquidationIncentive: ms().collateralAssets[assetAddress].liquidationIncentive,
                    anchorAddress: ms().collateralAssets[assetAddress].anchor,
                    oracleAddress: address(ms().collateralAssets[assetAddress].oracle),
                    assetAddress: assetAddress,
                    cFactor: ms().collateralAssets[assetAddress].factor,
                    decimals: decimals,
                    index: i,
                    price: price,
                    symbol: IERC20Permit(assetAddress).symbol(),
                    name: IERC20Permit(assetAddress).name()
                });
            }
        }
    }

    function krAssetInfoFor(
        address _account
    ) internal view returns (krAssetInfoUser[] memory result, uint256 totalDebtUSD) {
        address[] memory krAssetAddresses = ms().mintedKreskoAssets[_account];
        if (krAssetAddresses.length > 0) {
            result = new krAssetInfoUser[](krAssetAddresses.length);
            for (uint256 i; i < krAssetAddresses.length; i++) {
                address assetAddress = krAssetAddresses[i];
                KrAsset memory krAsset = ms().kreskoAssets[assetAddress];
                uint256 amount = ms().getKreskoAssetDebtPrincipal(_account, assetAddress);
                uint256 amountScaled = ms().getKreskoAssetDebtScaled(_account, assetAddress);

                uint256 amountUSD = ms().getKrAssetValue(assetAddress, amount, true);
                uint256 ammPrice;
                uint256 stabilityRate;
                uint256 priceRate;
                if (irs().srAssets[assetAddress].asset != address(0)) {
                    stabilityRate = irs().srAssets[assetAddress].calculateStabilityRate();
                    priceRate = irs().srAssets[assetAddress].getPriceRate();
                    ammPrice = IUniswapV2OracleCompat(ms().ammOracle).consultKrAsset(assetAddress, 1 ether);
                }
                totalDebtUSD + amountUSD;
                result[i] = krAssetInfoUser({
                    assetAddress: assetAddress,
                    oracleAddress: address(krAsset.oracle),
                    anchorAddress: krAsset.anchor,
                    openFee: krAsset.openFee,
                    closeFee: krAsset.closeFee,
                    amount: amount,
                    amountScaled: amountScaled,
                    amountUSD: amountUSD,
                    stabilityRate: stabilityRate,
                    priceRate: priceRate,
                    index: i,
                    kFactor: krAsset.kFactor,
                    price: uint256(krAsset.oracle.latestAnswer()),
                    ammPrice: ammPrice,
                    symbol: IERC20Permit(assetAddress).symbol(),
                    name: IERC20Permit(assetAddress).name()
                });
            }
        }
    }

    function healthFactorFor(address _account) internal view returns (uint256) {
        uint256 userDebt = ms().getAccountKrAssetValue(_account);
        uint256 userCollateral = ms().getAccountCollateralValue(_account);

        if (userDebt > 0) {
            return userCollateral.wadDiv(userDebt);
        } else {
            return 0;
        }
    }

    function kreskoUser(address _account) internal view returns (KreskoUser memory user) {
        (krAssetInfoUser[] memory krInfos, uint256 totalDebtUSD) = krAssetInfoFor(_account);
        (CollateralAssetInfoUser[] memory collateralInfos, uint256 totalCollateralUSD) = collateralAssetInfoFor(
            _account
        );

        if (krInfos.length > 0 || collateralInfos.length > 0) {
            user = KreskoUser({
                collateralAssets: collateralInfos,
                krAssets: krInfos,
                borrowingPowerUSD: borrowingPowerUSD(_account),
                healthFactor: healthFactorFor(_account),
                debtActualUSD: totalDebtUSD,
                debtUSD: ms().getAccountKrAssetValue(_account),
                collateralActualUSD: totalCollateralUSD,
                collateralUSD: ms().getAccountCollateralValue(_account),
                minCollateralUSD: ms().getAccountMinimumCollateralValueAtRatio(
                    _account,
                    ms().minimumCollateralizationRatio
                )
            });
        }
    }
}

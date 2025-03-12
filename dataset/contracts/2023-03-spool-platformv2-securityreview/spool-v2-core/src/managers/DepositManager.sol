// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@openzeppelin/token/ERC20/ERC20.sol";
import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/utils/math/Math.sol";
import "../interfaces/IAction.sol";
import "../interfaces/IAssetGroupRegistry.sol";
import "../interfaces/IDepositManager.sol";
import "../interfaces/IGuardManager.sol";
import "../interfaces/IMasterWallet.sol";
import "../interfaces/IRiskManager.sol";
import "../interfaces/ISmartVault.sol";
import "../interfaces/ISmartVaultManager.sol";
import "../interfaces/IStrategy.sol";
import "../interfaces/IStrategyRegistry.sol";
import "../interfaces/IUsdPriceFeedManager.sol";
import "../interfaces/Constants.sol";
import "../interfaces/RequestType.sol";
import "../access/SpoolAccessControllable.sol";
import "../libraries/ArrayMapping.sol";
import "../libraries/SpoolUtils.sol";
import "../libraries/uint128a2Lib.sol";

/**
 * @notice Used when deposit is not made in correct asset ratio.
 */
error IncorrectDepositRatio();

/**
 * @notice Used when deposit recipient is vault owner.
 */
error VaultOwnerNotAllowedToDeposit();

/**
 * @notice Contains parameters for distributeDeposit call.
 * @custom:member deposit Amounts deposited.
 * @custom:member exchangeRates Asset -> USD exchange rates.
 * @custom:member allocation Required allocation of value between different strategies.
 * @custom:member strategyRatios Required ratios between assets for each strategy.
 */
struct DepositQueryBag1 {
    uint256[] deposit;
    uint256[] exchangeRates;
    uint16a16 allocation;
    uint256[][] strategyRatios;
}

struct ClaimTokensLocalBag {
    bytes[] metadata;
    uint256 mintedSVTs;
    DepositMetadata data;
}

contract DepositManager is SpoolAccessControllable, IDepositManager {
    using SafeERC20 for IERC20;
    using uint16a16Lib for uint16a16;
    using uint128a2Lib for uint128a2;
    using ArrayMappingUint256 for mapping(uint256 => uint256);

    /**
     * @dev Precission multiplier for internal calculations.
     */
    uint256 constant PRECISION_MULTIPLIER = 10 ** 42;

    /**
     * @dev Relative tolerance for deposit ratio compared to ideal ratio.
     * Equals to 0.5%/
     */
    uint256 constant DEPOSIT_TOLERANCE = 50;

    /// @notice Strategy registry
    IStrategyRegistry private immutable _strategyRegistry;

    /// @notice Price feed manager
    IUsdPriceFeedManager private immutable _priceFeedManager;

    /// @notice Guard manager
    IGuardManager internal immutable _guardManager;

    /// @notice Action manager
    IActionManager internal immutable _actionManager;

    /**
     * @notice Exchange rates for vault, at given flush index
     * @dev smart vault => flush index => exchange rates
     */
    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) internal _flushExchangeRates;

    /**
     * @notice Amount of SSTs for vault at given flush index
     * @dev smart vault => flush index => i/2 => SSTs
     */
    mapping(address => mapping(uint256 => mapping(uint256 => uint128a2))) _flushSsts;

    /**
     * @notice Flushed deposits for vault, at given flush index
     * @dev smart vault => flush index => strategy => assets deposited
     */
    mapping(address => mapping(uint256 => mapping(address => mapping(uint256 => uint256)))) internal
        _vaultFlushedDeposits;

    /**
     * @dev smart vault => flush index => FlushShares{mintedVaultShares flushSvtSupply}
     */
    mapping(address => mapping(uint256 => FlushShares)) internal _flushShares;

    /**
     * @notice Vault deposits at given flush index
     * @dev smart vault => flush index => assets deposited
     */
    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) internal _vaultDeposits;

    constructor(
        IStrategyRegistry strategyRegistry_,
        IUsdPriceFeedManager priceFeedManager_,
        IGuardManager guardManager_,
        IActionManager actionManager_,
        ISpoolAccessControl accessControl_
    ) SpoolAccessControllable(accessControl_) {
        _guardManager = guardManager_;
        _actionManager = actionManager_;
        _strategyRegistry = strategyRegistry_;
        _priceFeedManager = priceFeedManager_;
    }

    function smartVaultDeposits(address smartVault, uint256 flushIdx, uint256 assetGroupLength)
        external
        view
        returns (uint256[] memory)
    {
        return _vaultDeposits[smartVault][flushIdx].toArray(assetGroupLength);
    }

    function claimSmartVaultTokens(
        address smartVault,
        uint256[] calldata nftIds,
        uint256[] calldata nftAmounts,
        address[] calldata tokens,
        address executor
    ) external returns (uint256) {
        _checkRole(ROLE_SMART_VAULT_MANAGER, msg.sender);

        // NOTE:
        // - here we are passing ids into the request context instead of amounts
        // - here we passing empty array as tokens
        _guardManager.runGuards(
            smartVault,
            RequestContext({
                receiver: executor,
                executor: executor,
                owner: executor,
                requestType: RequestType.BurnNFT,
                assets: nftIds,
                tokens: new address[](0)
            })
        );

        ClaimTokensLocalBag memory bag;
        ISmartVault vault = ISmartVault(smartVault);
        bag.metadata = vault.burnNFTs(executor, nftIds, nftAmounts);

        uint256 claimedVaultTokens = 0;
        for (uint256 i; i < nftIds.length; ++i) {
            if (nftIds[i] > MAXIMAL_DEPOSIT_ID) {
                revert InvalidDepositNftId(nftIds[i]);
            }

            // we can pass empty strategy array and empty DHW index array,
            // because vault should already be synced and mintedVaultShares values available
            bag.data = abi.decode(bag.metadata[i], (DepositMetadata));
            bag.mintedSVTs = _flushShares[smartVault][bag.data.flushIndex].mintedVaultShares;

            claimedVaultTokens +=
                getClaimedVaultTokensPreview(smartVault, bag.data, nftAmounts[i], bag.mintedSVTs, tokens);
        }

        // there will be some dust after all users claim SVTs
        vault.claimShares(executor, claimedVaultTokens);

        emit SmartVaultTokensClaimed(smartVault, executor, claimedVaultTokens, nftIds, nftAmounts);

        return claimedVaultTokens;
    }

    function flushSmartVault(
        address smartVault,
        uint256 flushIndex,
        address[] calldata strategies,
        uint16a16 allocation,
        address[] calldata tokens
    ) external returns (uint16a16) {
        _checkRole(ROLE_SMART_VAULT_MANAGER, msg.sender);

        if (_vaultDeposits[smartVault][flushIndex][0] == 0) {
            return uint16a16.wrap(0);
        }

        // handle deposits
        uint256[] memory exchangeRates = SpoolUtils.getExchangeRates(tokens, _priceFeedManager);
        _flushExchangeRates[smartVault][flushIndex].setValues(exchangeRates);

        uint256[][] memory distribution = distributeDeposit(
            DepositQueryBag1({
                deposit: _vaultDeposits[smartVault][flushIndex].toArray(tokens.length),
                exchangeRates: exchangeRates,
                allocation: allocation,
                strategyRatios: SpoolUtils.getStrategyRatiosAtLastDhw(strategies, _strategyRegistry)
            })
        );

        for (uint256 i; i < strategies.length; ++i) {
            _flushSsts[smartVault][flushIndex][i / 2] =
                _flushSsts[smartVault][flushIndex][i / 2].set(i % 2, IStrategy(strategies[i]).balanceOf(smartVault));

            if (distribution[i].length > 0) {
                _vaultFlushedDeposits[smartVault][flushIndex][strategies[i]].setValues(distribution[i]);
            }
        }
        _flushShares[smartVault][flushIndex].flushSvtSupply = uint128(ISmartVault(smartVault).totalSupply());

        return _strategyRegistry.addDeposits(strategies, distribution);
    }

    function syncDeposits(
        address smartVault,
        uint256[3] calldata bag,
        // uint256 flushIndex,
        // uint256 lastDhwSyncedTimestamp,
        // uint256 oldTotalSVTs,
        address[] calldata strategies,
        uint16a16[2] calldata dhwIndexes,
        address[] calldata assetGroup,
        SmartVaultFees calldata fees
    ) external returns (DepositSyncResult memory) {
        _checkRole(ROLE_SMART_VAULT_MANAGER, msg.sender);
        // mint SVTs based on USD value of claimed SSTs
        DepositSyncResult memory syncResult = syncDepositsSimulate(
            SimulateDepositParams(smartVault, bag, strategies, assetGroup, dhwIndexes[0], dhwIndexes[1], fees)
        );

        if (syncResult.mintedSVTs > 0) {
            _flushShares[smartVault][bag[0]].mintedVaultShares = uint128(syncResult.mintedSVTs);
            for (uint256 i; i < strategies.length; ++i) {
                if (syncResult.sstShares[i] > 0) {
                    IStrategy(strategies[i]).claimShares(smartVault, syncResult.sstShares[i]);
                }
            }
        }

        return syncResult;
    }

    function syncDepositsSimulate(SimulateDepositParams memory parameters)
        public
        view
        returns (DepositSyncResult memory)
    {
        DepositSyncResult memory result;
        {
            uint256[] memory dhwTimestamps =
                _strategyRegistry.dhwTimestamps(parameters.strategies, parameters.dhwIndexes);
            result = DepositSyncResult(0, parameters.bag[1], 0, new uint256[](parameters.strategies.length));

            // find last DHW timestamp of this flush index cycle
            for (uint256 i; i < parameters.strategies.length; ++i) {
                if (dhwTimestamps[i] > result.dhwTimestamp) {
                    result.dhwTimestamp = dhwTimestamps[i];
                }
            }

            // skip if there were no deposits made
            if (_vaultDeposits[parameters.smartVault][parameters.bag[0]][0] == 0) {
                return result;
            }
        }

        uint256[2] memory totalUsd;
        int256 totalFlushYieldUsd;
        // totalUsd[0]: totalDepositedUsd
        // totalUsd[1]: totalFlushUsd

        StrategyAtIndex[] memory strategyDhwState = _strategyRegistry.strategyAtIndexBatch(
            parameters.strategies, parameters.dhwIndexes, parameters.assetGroup.length
        );

        int256[] memory prevYields;

        if (parameters.fees.performanceFeePct > 0 && uint16a16.unwrap(parameters.dhwIndexesOld) > 0) {
            prevYields = _strategyRegistry.getDhwYield(parameters.strategies, parameters.dhwIndexesOld);
        }

        // claim SSTs from each strategy
        for (uint256 i; i < parameters.strategies.length; ++i) {
            StrategyAtIndex memory atDhw = strategyDhwState[i];
            if (atDhw.sharesMinted == 0) {
                continue;
            }

            uint256[2] memory depositedUsd;
            // depositedUsd[0]: vaultDepositedUsd
            // depositedUsd[1]: strategyDepositedUsd;
            depositedUsd[0] = _getVaultDepositsValue(
                parameters.smartVault,
                parameters.bag[0],
                parameters.strategies[i],
                atDhw.exchangeRates,
                parameters.assetGroup
            );
            depositedUsd[1] = _priceFeedManager.assetToUsdCustomPriceBulk(
                parameters.assetGroup, atDhw.assetsDeposited, atDhw.exchangeRates
            );

            result.sstShares[i] = atDhw.sharesMinted * depositedUsd[0] / depositedUsd[1];
            totalUsd[0] += result.sstShares[i] * atDhw.totalStrategyValue / atDhw.totalSSTs;

            uint256 flushSsts = _flushSsts[parameters.smartVault][parameters.bag[0]][i / 2].get(i % 2);
            uint256 stratFlushUsd = atDhw.totalStrategyValue * flushSsts / atDhw.totalSSTs;
            totalUsd[1] += stratFlushUsd;

            if (parameters.fees.performanceFeePct > 0 && prevYields.length > 0) {
                totalFlushYieldUsd += int256(stratFlushUsd)
                    - (
                        int256(stratFlushUsd) * YIELD_FULL_PERCENT_INT
                            / (YIELD_FULL_PERCENT_INT + atDhw.dhwYields - prevYields[i])
                    );
            }
        }

        if (totalUsd[1] == 0) {
            result.mintedSVTs = totalUsd[0] * INITIAL_SHARE_MULTIPLIER;
        } else {
            uint256 flushSvtSupply = _flushShares[parameters.smartVault][parameters.bag[0]].flushSvtSupply;
            uint256 performanceFeeMintedSvts;

            if (parameters.fees.performanceFeePct > 0 && totalFlushYieldUsd > 0) {
                uint256 totalFlushYieldFeeUsd =
                    uint256(totalFlushYieldUsd) * parameters.fees.performanceFeePct / FULL_PERCENT;
                performanceFeeMintedSvts =
                    flushSvtSupply * totalFlushYieldFeeUsd / (totalUsd[1] - totalFlushYieldFeeUsd);
                result.feeSVTs += performanceFeeMintedSvts;
            }

            result.mintedSVTs = (flushSvtSupply + performanceFeeMintedSvts) * totalUsd[0] / totalUsd[1];
        }

        if (parameters.fees.depositFeePct > 0 && result.mintedSVTs > 0) {
            uint256 depositFees = result.mintedSVTs * parameters.fees.depositFeePct / FULL_PERCENT;
            unchecked {
                result.feeSVTs += depositFees;
                result.mintedSVTs -= depositFees;
            }
        }

        if (parameters.fees.managementFeePct > 0) {
            // % of all SVTs minted until now, excluding the ones held by the vault owner
            result.feeSVTs += _calculateManagementFees(
                parameters.bag[1], result.dhwTimestamp, parameters.bag[2], parameters.fees.managementFeePct
            );
        }

        return result;
    }

    function _getVaultDepositsValue(
        address smartVault,
        uint256 flushIndex,
        address strategy,
        uint256[] memory exchangeRates,
        address[] memory assetGroup
    ) private view returns (uint256) {
        return _priceFeedManager.assetToUsdCustomPriceBulk(
            assetGroup,
            _vaultFlushedDeposits[smartVault][flushIndex][strategy].toArray(assetGroup.length),
            exchangeRates
        );
    }

    function depositAssets(DepositBag calldata bag, DepositExtras calldata bag2)
        external
        onlyRole(ROLE_SMART_VAULT_MANAGER, msg.sender)
        returns (uint256[] memory, uint256)
    {
        if (_accessControl.smartVaultOwner(bag.smartVault) == bag.receiver) {
            revert VaultOwnerNotAllowedToDeposit();
        }

        if (bag2.tokens.length != bag.assets.length) {
            revert InvalidAssetLengths();
        }

        // run guards and actions
        _guardManager.runGuards(
            bag.smartVault,
            RequestContext({
                receiver: bag.receiver,
                executor: bag2.depositor,
                owner: bag2.depositor,
                requestType: RequestType.Deposit,
                tokens: bag2.tokens,
                assets: bag.assets
            })
        );

        _actionManager.runActions(
            ActionContext({
                smartVault: bag.smartVault,
                recipient: bag.receiver,
                executor: bag2.depositor,
                owner: bag2.depositor,
                requestType: RequestType.Deposit,
                tokens: bag2.tokens,
                amounts: bag.assets
            })
        );

        // check if assets are in correct ratio
        checkDepositRatio(
            bag.assets,
            SpoolUtils.getExchangeRates(bag2.tokens, _priceFeedManager),
            bag2.allocations,
            SpoolUtils.getStrategyRatiosAtLastDhw(bag2.strategies, _strategyRegistry)
        );

        // transfer tokens from user to master wallet
        for (uint256 i; i < bag2.tokens.length; ++i) {
            _vaultDeposits[bag.smartVault][bag2.flushIndex][i] = bag.assets[i];
        }

        // mint deposit NFT
        DepositMetadata memory metadata = DepositMetadata(bag.assets, block.timestamp, bag2.flushIndex);
        uint256 depositId = ISmartVault(bag.smartVault).mintDepositNFT(bag.receiver, metadata);

        emit DepositInitiated(
            bag.smartVault, bag.receiver, depositId, bag2.flushIndex, bag.assets, bag2.depositor, bag.referral
            );

        return (_vaultDeposits[bag.smartVault][bag2.flushIndex].toArray(bag2.tokens.length), depositId);
    }

    /**
     * @notice Calculates fair distribution of deposit among strategies.
     * @param bag Parameter bag.
     * @return Distribution of deposits, with first index running over strategies and second index running over assets.
     */
    function distributeDeposit(DepositQueryBag1 memory bag) public pure returns (uint256[][] memory) {
        if (bag.deposit.length == 1) {
            return _distributeDepositSingleAsset(bag);
        } else {
            return _distributeDepositMultipleAssets(bag);
        }
    }

    /**
     * @notice Checks if deposit is made in correct ratio.
     * @dev Reverts with IncorrectDepositRatio if the check fails.
     * @param deposit Amounts deposited.
     * @param exchangeRates Asset -> USD exchange rates.
     * @param allocation Required allocation of value between different strategies.
     * @param strategyRatios Required ratios between assets for each strategy.
     */
    function checkDepositRatio(
        uint256[] memory deposit,
        uint256[] memory exchangeRates,
        uint16a16 allocation,
        uint256[][] memory strategyRatios
    ) public pure {
        if (deposit.length == 1) {
            return;
        }

        uint256[] memory idealDeposit = calculateDepositRatio(exchangeRates, allocation, strategyRatios);

        // loop over assets
        for (uint256 i = 1; i < deposit.length; ++i) {
            uint256 valueA = deposit[i] * idealDeposit[i - 1];
            uint256 valueB = deposit[i - 1] * idealDeposit[i];

            if ( // check if valueA is within DEPOSIT_TOLERANCE of valueB
                valueA < (valueB * (FULL_PERCENT - DEPOSIT_TOLERANCE) / FULL_PERCENT)
                    || valueA > (valueB * (FULL_PERCENT + DEPOSIT_TOLERANCE) / FULL_PERCENT)
            ) {
                revert IncorrectDepositRatio();
            }
        }
    }

    /**
     * @notice Calculates ideal deposit ratio for a smart vault.
     * @param exchangeRates Asset -> USD exchange rates.
     * @param allocation Required allocation of value between different strategies.
     * @param strategyRatios Required ratios between assets for each strategy.
     * @return Ideal deposit ratio.
     */
    function calculateDepositRatio(
        uint256[] memory exchangeRates,
        uint16a16 allocation,
        uint256[][] memory strategyRatios
    ) public pure returns (uint256[] memory) {
        if (exchangeRates.length == 1) {
            uint256[] memory ratio = new uint256[](1);
            ratio[0] = 1;

            return ratio;
        }

        return _calculateDepositRatioFromFlushFactors(calculateFlushFactors(exchangeRates, allocation, strategyRatios));
    }

    /**
     * @dev Calculate flush factors - intermediate result.
     * @param exchangeRates Asset -> USD exchange rates.
     * @param allocation Required allocation of value between different strategies.
     * @param strategyRatios Required ratios between assets for each strategy.
     * @return Flush factors, with first index running over strategies and second index running over assets.
     */
    function calculateFlushFactors(
        uint256[] memory exchangeRates,
        uint16a16 allocation,
        uint256[][] memory strategyRatios
    ) public pure returns (uint256[][] memory) {
        uint256[][] memory flushFactors = new uint256[][](strategyRatios.length);

        // loop over strategies
        for (uint256 i; i < strategyRatios.length; ++i) {
            flushFactors[i] = new uint256[](exchangeRates.length);

            uint256 normalization = 0;
            // loop over assets
            for (uint256 j = 0; j < exchangeRates.length; j++) {
                normalization += strategyRatios[i][j] * exchangeRates[j];
            }

            // loop over assets
            for (uint256 j = 0; j < exchangeRates.length; j++) {
                flushFactors[i][j] = allocation.get(i) * strategyRatios[i][j] * PRECISION_MULTIPLIER / normalization;
            }
        }

        return flushFactors;
    }

    /**
     * @notice Calculates the SVT balance that is available to be claimed
     */
    function getClaimedVaultTokensPreview(
        address smartVaultAddress,
        DepositMetadata memory data,
        uint256 nftShares,
        uint256 mintedSVTs,
        address[] calldata tokens
    ) public view returns (uint256) {
        uint256[] memory totalDepositedAssets;
        uint256[] memory exchangeRates;
        uint256 depositedUsd;
        uint256 totalDepositedUsd;
        totalDepositedAssets = _vaultDeposits[smartVaultAddress][data.flushIndex].toArray(data.assets.length);
        exchangeRates = _flushExchangeRates[smartVaultAddress][data.flushIndex].toArray(data.assets.length);

        if (mintedSVTs == 0) {
            mintedSVTs = _flushShares[smartVaultAddress][data.flushIndex].mintedVaultShares;
        }

        for (uint256 i; i < data.assets.length; ++i) {
            depositedUsd += _priceFeedManager.assetToUsdCustomPrice(tokens[i], data.assets[i], exchangeRates[i]);
            totalDepositedUsd +=
                _priceFeedManager.assetToUsdCustomPrice(tokens[i], totalDepositedAssets[i], exchangeRates[i]);
        }
        uint256 claimedVaultTokens = mintedSVTs * depositedUsd / totalDepositedUsd;

        return claimedVaultTokens * nftShares / NFT_MINTED_SHARES;
    }

    /**
     * @dev Calculated deposit ratio from flush factors.
     * @param flushFactors Flush factors.
     * @return Deposit ratio, with first index running over strategies and second index running over assets.
     */
    function _calculateDepositRatioFromFlushFactors(uint256[][] memory flushFactors)
        private
        pure
        returns (uint256[] memory)
    {
        uint256[] memory depositRatio = new uint256[](flushFactors[0].length);

        // loop over strategies
        for (uint256 i; i < flushFactors.length; ++i) {
            // loop over assets
            for (uint256 j = 0; j < flushFactors[i].length; j++) {
                depositRatio[j] += flushFactors[i][j];
            }
        }

        return depositRatio;
    }

    /**
     * @dev Calculates fair distribution of single asset among strategies.
     * @param bag Parameter bag.
     * @return Distribution of deposits, with first index running over strategies and second index running over assets.
     */
    function _distributeDepositSingleAsset(DepositQueryBag1 memory bag) private pure returns (uint256[][] memory) {
        uint256 distributed;
        uint256[][] memory distribution = new uint256[][](bag.strategyRatios.length);

        uint256 totalAllocation;
        for (uint256 i; i < bag.strategyRatios.length; ++i) {
            totalAllocation += bag.allocation.get(i);
        }

        // loop over strategies
        for (uint256 i; i < bag.strategyRatios.length; ++i) {
            distribution[i] = new uint256[](1);

            distribution[i][0] = bag.deposit[0] * bag.allocation.get(i) / totalAllocation;
            distributed += distribution[i][0];
        }

        // handle dust
        distribution[0][0] += bag.deposit[0] - distributed;

        return distribution;
    }

    /**
     * @dev Calculates fair distribution of multiple assets among strategies.
     * @param bag Parameter bag.
     * @return Distribution of deposits, with first index running over strategies and second index running over assets.
     */
    function _distributeDepositMultipleAssets(DepositQueryBag1 memory bag) private pure returns (uint256[][] memory) {
        uint256[][] memory flushFactors = calculateFlushFactors(bag.exchangeRates, bag.allocation, bag.strategyRatios);
        uint256[] memory idealDepositRatio = _calculateDepositRatioFromFlushFactors(flushFactors);

        uint256[] memory distributed = new uint256[](bag.deposit.length);
        uint256[][] memory distribution = new uint256[][](bag.strategyRatios.length);

        // loop over strategies
        for (uint256 i; i < bag.strategyRatios.length; ++i) {
            distribution[i] = new uint256[](bag.exchangeRates.length);

            // loop over assets
            for (uint256 j = 0; j < bag.exchangeRates.length; j++) {
                distribution[i][j] = bag.deposit[j] * flushFactors[i][j] / idealDepositRatio[j];
                distributed[j] += distribution[i][j];
            }
        }

        // handle dust
        for (uint256 j = 0; j < bag.exchangeRates.length; j++) {
            distribution[0][j] += bag.deposit[j] - distributed[j];
        }

        return distribution;
    }

    /**
     * @dev Calculated as percentage of assets under management, distributed throughout a year.
     * SVT amount being diluted should not include previously distributed management fees.
     * @param timeFrom time from which to collect fees
     * @param timeTo time to which to collect fees
     * @param totalSVTs SVT amount basis on which to apply fees
     * @param mgmtFeePct management fee percentage value
     */
    function _calculateManagementFees(uint256 timeFrom, uint256 timeTo, uint256 totalSVTs, uint256 mgmtFeePct)
        private
        pure
        returns (uint256)
    {
        uint256 timeDelta = timeTo - timeFrom;
        return totalSVTs * mgmtFeePct * timeDelta / SECONDS_IN_YEAR / FULL_PERCENT;
    }
}

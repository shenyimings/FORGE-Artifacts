// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@openzeppelin/token/ERC20/ERC20.sol";
import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/utils/math/Math.sol";
import "@openzeppelin-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "../interfaces/IAssetGroupRegistry.sol";
import "../interfaces/IMasterWallet.sol";
import "../interfaces/IStrategy.sol";
import "../interfaces/IStrategyRegistry.sol";
import "../interfaces/CommonErrors.sol";
import "../interfaces/Constants.sol";
import "../access/SpoolAccessControl.sol";
import "../access/SpoolAccessControllable.sol";

abstract contract Strategy is ERC20Upgradeable, SpoolAccessControllable, IStrategy {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    IAssetGroupRegistry internal immutable _assetGroupRegistry;

    /// @notice Name of the strategy
    string private _strategyName;

    /// @notice ID of the asset group used by the strategy.
    uint256 internal _assetGroupId;

    /// @notice Total value (in USD) of assets managed by the strategy.
    /// @dev Should be updated in DHW with deposits, withdrawals and yields.
    uint256 public totalUsdValue = 0;

    constructor(
        string memory strategyName_,
        IAssetGroupRegistry assetGroupRegistry_,
        ISpoolAccessControl accessControl_
    ) SpoolAccessControllable(accessControl_) {
        _strategyName = strategyName_;
        _assetGroupRegistry = assetGroupRegistry_;
    }

    function __Strategy_init(uint256 assetGroupId_) internal onlyInitializing {
        _assetGroupId = assetGroupId_;

        __ERC20_init("Strategy Share Token", "SST");
    }

    /* ========== EXTERNAL VIEW FUNCTIONS ========== */

    function assetGroupId() external view returns (uint256) {
        return _assetGroupId;
    }

    function assets() public view returns (address[] memory) {
        return _assetGroupRegistry.listAssetGroup(_assetGroupId);
    }

    function assetRatio() external view virtual returns (uint256[] memory);

    function strategyName() external view returns (string memory) {
        return _strategyName;
    }

    function beforeDepositCheck(uint256[] memory amounts, uint256[] calldata slippages) public view virtual;

    function beforeRedeemalCheck(uint256 ssts, uint256[] calldata slippages) public view virtual;

    /* ========== EXTERNAL MUTATIVE FUNCTIONS ========== */

    function doHardWork(StrategyDhwParameterBag calldata dhwParams) external returns (DhwInfo memory dhwInfo) {
        _checkRole(ROLE_STRATEGY_REGISTRY, msg.sender);

        // assetsToDeposit[0..token.length-1]: amount of asset i to deposit
        // assetsToDeposit[token.length]: is there anything to deposit
        uint256[] memory assetsToDeposit = new uint256[](dhwParams.assetGroup.length + 1);
        unchecked {
            for (uint256 i; i < dhwParams.assetGroup.length; ++i) {
                assetsToDeposit[i] = IERC20(dhwParams.assetGroup[i]).balanceOf(address(this));

                if (assetsToDeposit[i] > 0) {
                    ++assetsToDeposit[dhwParams.assetGroup.length];
                }
            }
        }

        beforeDepositCheck(assetsToDeposit, dhwParams.slippages);
        beforeRedeemalCheck(dhwParams.withdrawnShares, dhwParams.slippages);

        // usdWorth[0]: usd worth before deposit / withdrawal
        // usdWorth[1]: usd worth after deposit / withdrawal
        uint256[] memory usdWorth = new uint256[](2);

        // Compound and get USD value.
        dhwInfo.yieldPercentage = _getYieldPercentage(dhwParams.baseYield);
        dhwInfo.yieldPercentage += _compound(dhwParams.assetGroup, dhwParams.compoundSwapInfo, dhwParams.slippages);

        // collect fees, mint SVTs relative to the yield generated
        _collectPlatformFees(dhwInfo.yieldPercentage, dhwParams.platformFees);

        usdWorth[0] = _getUsdWorth(dhwParams.exchangeRates, dhwParams.priceFeedManager);

        uint256 matchedShares;
        uint256 depositShareEquivalent;
        uint256 mintedShares;
        uint256 withdrawnShares = dhwParams.withdrawnShares;

        // Calculate deposit share equivalent.
        if (assetsToDeposit[dhwParams.assetGroup.length] > 0) {
            uint256 valueToDeposit = dhwParams.priceFeedManager.assetToUsdCustomPriceBulk(
                dhwParams.assetGroup, assetsToDeposit, dhwParams.exchangeRates
            );

            unchecked {
                if (usdWorth[0] > 0) {
                    depositShareEquivalent = totalSupply() * valueToDeposit / usdWorth[0];
                } else {
                    depositShareEquivalent = INITIAL_SHARE_MULTIPLIER * valueToDeposit;
                }
            }

            // Match withdrawals and deposits by taking smaller value as matched shares.
            if (depositShareEquivalent < withdrawnShares) {
                matchedShares = depositShareEquivalent;
            } else {
                matchedShares = withdrawnShares;
            }
        }

        uint256[] memory withdrawnAssets = new uint256[](dhwParams.assetGroup.length);
        bool withdrawn;
        if (depositShareEquivalent > withdrawnShares) {
            // Deposit is needed.

            // - match if needed
            if (matchedShares > 0) {
                unchecked {
                    for (uint256 i; i < dhwParams.assetGroup.length; ++i) {
                        withdrawnAssets[i] = assetsToDeposit[i] * matchedShares / depositShareEquivalent;
                        assetsToDeposit[i] -= withdrawnAssets[i];
                    }
                }
                withdrawn = true;
            }

            // - swap assets
            _swapAssets(dhwParams.assetGroup, assetsToDeposit, dhwParams.swapInfo);
            for (uint256 i; i < dhwParams.assetGroup.length; ++i) {
                assetsToDeposit[i] = IERC20(dhwParams.assetGroup[i]).balanceOf(address(this)) - withdrawnAssets[i];
            }

            // - deposit assets into the protocol
            _depositToProtocol(dhwParams.assetGroup, assetsToDeposit, dhwParams.slippages);
            usdWorth[1] = _getUsdWorth(dhwParams.exchangeRates, dhwParams.priceFeedManager);

            // - mint SSTs
            uint256 usdWorthDeposited = usdWorth[1] - usdWorth[0];
            unchecked {
                if (usdWorth[0] > 0) {
                    mintedShares = usdWorthDeposited * totalSupply() / usdWorth[0];
                } else {
                    mintedShares = usdWorthDeposited * INITIAL_SHARE_MULTIPLIER;
                }
            }
            _mint(address(this), mintedShares);

            mintedShares += matchedShares;
        } else if (withdrawnShares > depositShareEquivalent) {
            // Withdrawal is needed.

            // - match if needed
            if (matchedShares > 0) {
                unchecked {
                    withdrawnShares -= matchedShares;
                    mintedShares = matchedShares;
                }
            }

            // - redeem shares from protocol
            _redeemFromProtocol(dhwParams.assetGroup, withdrawnShares, dhwParams.slippages);
            _burn(address(this), withdrawnShares);
            withdrawn = true;

            // - figure out how much was withdrawn
            usdWorth[1] = _getUsdWorth(dhwParams.exchangeRates, dhwParams.priceFeedManager);
            unchecked {
                for (uint256 i; i < dhwParams.assetGroup.length; ++i) {
                    withdrawnAssets[i] = IERC20(dhwParams.assetGroup[i]).balanceOf(address(this));
                }
            }
        } else {
            // Neither withdrawal nor deposit is needed.

            // - match if needed
            if (matchedShares > 0) {
                mintedShares = withdrawnShares;
                unchecked {
                    for (uint256 i; i < dhwParams.assetGroup.length; ++i) {
                        withdrawnAssets[i] = assetsToDeposit[i];
                    }
                }
                withdrawn = true;
            }

            usdWorth[1] = usdWorth[0];
        }

        // Transfer withdrawn assets to master wallet if needed.
        if (withdrawn) {
            unchecked {
                for (uint256 i; i < dhwParams.assetGroup.length; ++i) {
                    IERC20(dhwParams.assetGroup[i]).safeTransfer(dhwParams.masterWallet, withdrawnAssets[i]);
                }
            }
        }

        totalUsdValue = usdWorth[1];

        dhwInfo.sharesMinted = mintedShares;
        dhwInfo.assetsWithdrawn = withdrawnAssets;
        dhwInfo.valueAtDhw = usdWorth[1];
        dhwInfo.totalSstsAtDhw = totalSupply();
    }

    function redeemFast(
        uint256 shares,
        address masterWallet,
        address[] calldata assetGroup,
        uint256[] calldata exchangeRates,
        IUsdPriceFeedManager priceFeedManager,
        uint256[] calldata slippages
    ) external returns (uint256[] memory) {
        if (
            !_accessControl.hasRole(ROLE_SMART_VAULT_MANAGER, msg.sender)
                && !_accessControl.hasRole(ROLE_STRATEGY_REGISTRY, msg.sender)
        ) {
            revert NotFastRedeemer(msg.sender);
        }

        return
            _redeemShares(shares, address(this), masterWallet, assetGroup, exchangeRates, priceFeedManager, slippages);
    }

    function redeemShares(
        uint256 shares,
        address redeemer,
        address[] calldata assetGroup,
        uint256[] calldata exchangeRates,
        IUsdPriceFeedManager priceFeedManager,
        uint256[] calldata slippages
    ) external returns (uint256[] memory) {
        _checkRole(ROLE_STRATEGY_REGISTRY, msg.sender);

        return _redeemShares(shares, redeemer, redeemer, assetGroup, exchangeRates, priceFeedManager, slippages);
    }

    /// @dev is only called when reallocating
    function depositFast(
        address[] calldata assetGroup,
        uint256[] calldata exchangeRates,
        IUsdPriceFeedManager priceFeedManager,
        uint256[] calldata slippages,
        SwapInfo[] calldata swapInfo
    ) external onlyRole(ROLE_SMART_VAULT_MANAGER, msg.sender) returns (uint256) {
        // get amount of assets available to deposit
        uint256[] memory assetsToDeposit = new uint256[](assetGroup.length);
        for (uint256 i; i < assetGroup.length; ++i) {
            assetsToDeposit[i] = IERC20(assetGroup[i]).balanceOf(address(this));
        }

        // swap assets
        _swapAssets(assetGroup, assetsToDeposit, swapInfo);
        for (uint256 i; i < assetGroup.length; ++i) {
            assetsToDeposit[i] = IERC20(assetGroup[i]).balanceOf(address(this));
        }

        // deposit assets
        uint256 usdWorth0 = _getUsdWorth(exchangeRates, priceFeedManager);
        _depositToProtocol(assetGroup, assetsToDeposit, slippages);
        uint256 usdWorth1 = _getUsdWorth(exchangeRates, priceFeedManager);

        // mint SSTs
        uint256 usdWorthDeposited = usdWorth1 - usdWorth0;
        uint256 sstsToMint;
        if (usdWorth0 > 0) {
            sstsToMint = usdWorthDeposited * totalSupply() / usdWorth0;
        } else {
            sstsToMint = usdWorthDeposited * INITIAL_SHARE_MULTIPLIER;
        }
        _mint(address(this), sstsToMint);

        totalUsdValue = usdWorth1;

        return sstsToMint;
    }

    function claimShares(address smartVault, uint256 amount) external onlyRole(ROLE_SMART_VAULT_MANAGER, msg.sender) {
        _transfer(address(this), smartVault, amount);
    }

    function releaseShares(address smartVault, uint256 amount)
        external
        onlyRole(ROLE_SMART_VAULT_MANAGER, msg.sender)
    {
        _transfer(smartVault, address(this), amount);
    }

    function emergencyWithdraw(uint256[] calldata slippages, address recipient)
        external
        onlyRole(ROLE_STRATEGY_REGISTRY, msg.sender)
    {
        _emergencyWithdrawImpl(slippages, recipient);
    }

    /* ========== PRIVATE/INTERNAL FUNCTIONS ========== */

    function _redeemShares(
        uint256 shares,
        address shareOwner,
        address recipient,
        address[] calldata assetGroup,
        uint256[] calldata exchangeRates,
        IUsdPriceFeedManager priceFeedManager,
        uint256[] calldata slippages
    ) internal virtual returns (uint256[] memory) {
        // redeem shares from protocol
        uint256[] memory assetsWithdrawn = _redeemFromProtocolAndReturnAssets(assetGroup, shares, slippages);
        _burn(shareOwner, shares);

        totalUsdValue = _getUsdWorth(exchangeRates, priceFeedManager);

        // transfer assets to master wallet
        for (uint256 i; i < assetGroup.length; ++i) {
            IERC20(assetGroup[i]).safeTransfer(recipient, assetsWithdrawn[i]);
        }

        return assetsWithdrawn;
    }

    /**
     * @notice Calculate and mint platform performance fees based on the yield generated.
     * @param yieldPct Yield generated since previous DHW. Full percent is `YIELD_FULL_PERCENT`.
     * @param platformFees Platform fees info, containing information of the sice and recipient of the fees (SSTs).
     * @return sharesMinted Returns newly minted shares representing the platform performance fees.
     */
    function _collectPlatformFees(int256 yieldPct, PlatformFees calldata platformFees)
        internal
        virtual
        returns (uint256 sharesMinted)
    {
        if (yieldPct > 0) {
            uint256 uint256YieldPct = uint256(yieldPct);

            uint256 yieldPctUsersPlusOne = uint256YieldPct
                * (FULL_PERCENT - platformFees.ecosystemFeePct - platformFees.treasuryFeePct)
                + FULL_PERCENT * YIELD_FULL_PERCENT;
            uint256 totalSupplyTimesYieldPct = totalSupply() * uint256YieldPct;

            // mint new ecosystem fee SSTs
            uint256 newEcosystemFeeSsts = totalSupplyTimesYieldPct * platformFees.ecosystemFeePct / yieldPctUsersPlusOne;
            _mint(platformFees.ecosystemFeeReceiver, newEcosystemFeeSsts);

            // mint new treasury fee SSTs
            uint256 newTreasuryFeeSsts = totalSupplyTimesYieldPct * platformFees.treasuryFeePct / yieldPctUsersPlusOne;
            _mint(platformFees.treasuryFeeReceiver, newTreasuryFeeSsts);

            unchecked {
                sharesMinted = newEcosystemFeeSsts + newTreasuryFeeSsts;
            }
        }
    }

    function _redeemFromProtocolAndReturnAssets(address[] calldata tokens, uint256 ssts, uint256[] calldata slippages)
        internal
        virtual
        returns (uint256[] memory withdrawnAssets)
    {
        withdrawnAssets = new uint256[](tokens.length);
        for (uint256 i; i < tokens.length; ++i) {
            withdrawnAssets[i] = IERC20(tokens[i]).balanceOf(address(this));
        }

        _redeemFromProtocol(tokens, ssts, slippages);

        for (uint256 i; i < tokens.length; ++i) {
            withdrawnAssets[i] = IERC20(tokens[i]).balanceOf(address(this)) - withdrawnAssets[i];
        }
    }

    function _calculateYieldPercentage(uint256 previousValue, uint256 increaseValue)
        internal
        pure
        returns (int256 yieldPercentage)
    {
        if (previousValue > 0 && increaseValue > 0) {
            yieldPercentage = int256(increaseValue * YIELD_FULL_PERCENT / previousValue);
        }
    }

    function _resetAndApprove(IERC20 token, address spender, uint256 amount) internal {
        _resetAllowance(token, spender);
        token.safeApprove(spender, amount);
    }

    function _resetAllowance(IERC20 token, address spender) internal {
        if (token.allowance(address(this), spender) > 0) {
            token.safeApprove(spender, 0);
        }
    }

    function _compound(address[] calldata tokens, SwapInfo[] calldata compoundSwapInfo, uint256[] calldata slippages)
        internal
        virtual
        returns (int256 compoundYield);

    function _getYieldPercentage(int256 manualYield) internal virtual returns (int256);

    /**
     * @dev Swaps assets.
     * @param tokens Addresses of tokens to swap.
     * @param toSwap Available amounts to swap.
     * @param swapInfo Information on how to swap.
     */
    function _swapAssets(address[] memory tokens, uint256[] memory toSwap, SwapInfo[] calldata swapInfo)
        internal
        virtual;

    /**
     * @dev Deposits assets into the underlying protocol.
     * @param tokens Addresses of asset tokens.
     * @param amounts Amounts to deposit.
     * @param slippages Slippages to guard depositing.
     */
    function _depositToProtocol(address[] calldata tokens, uint256[] memory amounts, uint256[] calldata slippages)
        internal
        virtual;

    /**
     * @dev Redeems shares from the undelying protocol.
     * @param tokens Addresses of asset tokens.
     * @param ssts Amount of strategy tokens to redeem.
     * @param slippages Slippages to guard redeemal.
     */
    function _redeemFromProtocol(address[] calldata tokens, uint256 ssts, uint256[] calldata slippages)
        internal
        virtual;

    function _emergencyWithdrawImpl(uint256[] calldata slippages, address recipient) internal virtual;

    function _getUsdWorth(uint256[] memory exchangeRates, IUsdPriceFeedManager priceFeedManager)
        internal
        virtual
        returns (uint256);

    /* ========== MODIFIERS ========== */
}

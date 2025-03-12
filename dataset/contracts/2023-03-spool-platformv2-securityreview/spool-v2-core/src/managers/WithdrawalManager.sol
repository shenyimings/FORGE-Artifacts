// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IAction.sol";
import "../interfaces/IGuardManager.sol";
import "../interfaces/IMasterWallet.sol";
import "../interfaces/ISmartVault.sol";
import "../interfaces/ISmartVaultManager.sol";
import "../interfaces/IStrategy.sol";
import "../interfaces/IStrategyRegistry.sol";
import "../interfaces/IUsdPriceFeedManager.sol";
import "../interfaces/IWithdrawalManager.sol";
import "../interfaces/RequestType.sol";
import "../access/SpoolAccessControllable.sol";
import "../libraries/ArrayMapping.sol";
import "../libraries/uint128a2Lib.sol";

contract WithdrawalManager is SpoolAccessControllable, IWithdrawalManager {
    using SafeERC20 for IERC20;
    using uint128a2Lib for uint128a2;
    using ArrayMappingUint256 for mapping(uint256 => uint256);

    /**
     * @notice Withdrawn vault shares at given flush index
     * @dev smart vault => flush index => vault shares withdrawn
     */
    mapping(address => mapping(uint256 => uint256)) internal _withdrawnVaultShares;

    /**
     * @notice Withdrawn strategy shares for vault, at given flush index
     * @dev smart vault => flush index => idx / 2 => strategy shares withdrawn
     */
    mapping(address => mapping(uint256 => mapping(uint256 => uint128a2))) internal _withdrawnStrategyShares;

    /**
     * @notice Withdrawn assets for vault, at given flush index
     * @dev smart vault => flush index => asset index => assets withdrawn
     */
    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) internal _withdrawnAssets;

    /// @notice Strategy registry
    IStrategyRegistry private immutable _strategyRegistry;

    /// @notice Price feed manager
    IUsdPriceFeedManager private immutable _priceFeedManager;

    /// @notice Master wallet
    IMasterWallet private immutable _masterWallet;

    /// @notice Guard manager
    IGuardManager internal immutable _guardManager;

    /// @notice Action manager
    IActionManager internal immutable _actionManager;

    constructor(
        IStrategyRegistry strategyRegistry_,
        IUsdPriceFeedManager priceFeedManager_,
        IMasterWallet masterWallet_,
        IGuardManager guardManager_,
        IActionManager actionManager_,
        ISpoolAccessControl accessControl_
    ) SpoolAccessControllable(accessControl_) {
        _guardManager = guardManager_;
        _actionManager = actionManager_;
        _strategyRegistry = strategyRegistry_;
        _priceFeedManager = priceFeedManager_;
        _masterWallet = masterWallet_;
    }

    function flushSmartVault(address smartVault, uint256 flushIndex, address[] calldata strategies)
        external
        onlyRole(ROLE_SMART_VAULT_MANAGER, msg.sender)
        returns (uint16a16)
    {
        uint256 withdrawals = _withdrawnVaultShares[smartVault][flushIndex];

        if (withdrawals == 0) {
            return uint16a16.wrap(0);
        }

        uint256[] memory strategyWithdrawals = new uint256[](strategies.length);
        uint256 totalVaultShares = ISmartVault(smartVault).totalSupply();

        for (uint256 i; i < strategies.length; ++i) {
            uint256 strategyShares = IStrategy(strategies[i]).balanceOf(smartVault);
            strategyWithdrawals[i] = strategyShares * withdrawals / totalVaultShares;
        }

        ISmartVault(smartVault).burn(smartVault, withdrawals, strategies, strategyWithdrawals);

        for (uint256 i; i < strategyWithdrawals.length; ++i) {
            _withdrawnStrategyShares[smartVault][flushIndex][i / 2] =
                _withdrawnStrategyShares[smartVault][flushIndex][i / 2].set(i % 2, strategyWithdrawals[i]);
        }

        return _strategyRegistry.addWithdrawals(strategies, strategyWithdrawals);
    }

    function claimWithdrawal(WithdrawalClaimBag calldata bag)
        public
        onlyRole(ROLE_SMART_VAULT_MANAGER, msg.sender)
        returns (uint256[] memory, uint256)
    {
        uint256[] memory withdrawnAssets = new uint256[](bag.assetGroup.length);
        bytes[] memory metadata = ISmartVault(bag.smartVault).burnNFTs(bag.executor, bag.nftIds, bag.nftAmounts);

        for (uint256 i; i < bag.nftIds.length; ++i) {
            if (bag.nftIds[i] <= MAXIMAL_DEPOSIT_ID) {
                revert InvalidWithdrawalNftId(bag.nftIds[i]);
            }

            uint256[] memory withdrawnAssets_ = _calculateWithdrawal(
                bag.smartVault, abi.decode(metadata[i], (WithdrawalMetadata)), bag.assetGroup.length
            );
            for (uint256 j = 0; j < bag.assetGroup.length; j++) {
                withdrawnAssets[j] += withdrawnAssets_[j] * bag.nftAmounts[i] / NFT_MINTED_SHARES;
            }
        }

        _actionManager.runActions(
            ActionContext({
                smartVault: bag.smartVault,
                recipient: bag.receiver,
                executor: bag.executor,
                owner: bag.executor,
                requestType: RequestType.Withdrawal,
                tokens: bag.assetGroup,
                amounts: withdrawnAssets
            })
        );

        for (uint256 i; i < bag.assetGroup.length; ++i) {
            _masterWallet.transfer(IERC20(bag.assetGroup[i]), bag.receiver, withdrawnAssets[i]);
        }

        emit WithdrawalClaimed(
            bag.smartVault, bag.executor, bag.assetGroupId, bag.nftIds, bag.nftAmounts, withdrawnAssets
            );

        return (withdrawnAssets, bag.assetGroupId);
    }

    function syncWithdrawals(
        address smartVault,
        uint256 flushIndex,
        address[] calldata strategies,
        uint16a16 dhwIndexes_
    ) external onlyRole(ROLE_SMART_VAULT_MANAGER, msg.sender) {
        if (_withdrawnVaultShares[smartVault][flushIndex] == 0) {
            return;
        }

        uint256[] memory withdrawnShares = new uint256[](strategies.length);
        for (uint256 i; i < strategies.length; ++i) {
            withdrawnShares[i] = _withdrawnStrategyShares[smartVault][flushIndex][i / 2].get(i % 2);
        }

        uint256[] memory withdrawnAssets_ = _strategyRegistry.claimWithdrawals(strategies, dhwIndexes_, withdrawnShares);

        _withdrawnAssets[smartVault][flushIndex].setValues(withdrawnAssets_);
    }

    function redeem(RedeemBag calldata bag, RedeemExtras calldata bag2)
        external
        onlyRole(ROLE_SMART_VAULT_MANAGER, msg.sender)
        returns (uint256)
    {
        ISmartVault smartVault = ISmartVault(bag.smartVault);
        _validateRedeem(smartVault, bag2.redeemer, bag2.receiver, bag.shares);

        // add withdrawal to be flushed
        _withdrawnVaultShares[bag.smartVault][bag2.flushIndex] += bag.shares;

        // transfer vault shares back to smart vault
        smartVault.transferFromSpender(bag2.redeemer, bag.smartVault, bag.shares, bag2.redeemer);
        uint256 redeemId = smartVault.mintWithdrawalNFT(bag2.receiver, WithdrawalMetadata(bag.shares, bag2.flushIndex));
        emit RedeemInitiated(bag.smartVault, bag2.redeemer, redeemId, bag2.flushIndex, bag.shares, bag2.receiver);

        return redeemId;
    }

    function redeemFast(RedeemBag calldata bag, RedeemFastExtras calldata bag2)
        external
        onlyRole(ROLE_SMART_VAULT_MANAGER, msg.sender)
        returns (uint256[] memory)
    {
        ISmartVault smartVault = ISmartVault(bag.smartVault);
        _validateRedeem(smartVault, bag2.redeemer, bag2.redeemer, bag.shares);

        // figure out how much to redeem from each strategy
        uint256[] memory strategySharesToRedeem = new uint256[](bag2.strategies.length);
        {
            uint256 totalVaultShares = smartVault.totalSupply();
            for (uint256 i; i < bag2.strategies.length; ++i) {
                uint256 strategyShares = IStrategy(bag2.strategies[i]).balanceOf(bag.smartVault);

                strategySharesToRedeem[i] = strategyShares * bag.shares / totalVaultShares;
            }

            // redeem from strategies and burn
            smartVault.burn(bag2.redeemer, bag.shares, bag2.strategies, strategySharesToRedeem);
        }

        uint256[] memory assetsWithdrawn = _strategyRegistry.redeemFast(
            RedeemFastParameterBag({
                strategies: bag2.strategies,
                strategyShares: strategySharesToRedeem,
                assetGroup: bag2.assetGroup,
                withdrawalSlippages: bag2.withdrawalSlippages,
                exchangeRateSlippages: bag2.exchangeRateSlippages
            })
        );

        // transfer assets to the redeemer
        for (uint256 i; i < bag2.assetGroup.length; ++i) {
            _masterWallet.transfer(IERC20(bag2.assetGroup[i]), bag2.redeemer, assetsWithdrawn[i]);
        }

        emit FastRedeemInitiated(bag.smartVault, bag2.redeemer, bag.shares, bag.nftIds, bag.nftAmounts, assetsWithdrawn);

        return assetsWithdrawn;
    }

    function _validateRedeem(ISmartVault smartVault, address redeemer, address receiver, uint256 shares) private view {
        if (smartVault.balanceOf(redeemer) < shares) {
            revert InsufficientBalance(smartVault.balanceOf(redeemer), shares);
        }

        uint256[] memory assets = new uint256[](1);
        assets[0] = shares;
        address[] memory tokens = new address[](1);
        tokens[0] = address(smartVault);
        _guardManager.runGuards(
            address(smartVault),
            RequestContext({
                receiver: receiver,
                executor: redeemer,
                owner: redeemer,
                requestType: RequestType.Withdrawal,
                assets: assets,
                tokens: tokens
            })
        );
    }

    function _calculateWithdrawal(address smartVault, WithdrawalMetadata memory data, uint256 assetGroupLength)
        internal
        view
        returns (uint256[] memory)
    {
        uint256[] memory withdrawnAssets = new uint256[](assetGroupLength);

        // loop over all assets
        for (uint256 i; i < withdrawnAssets.length; ++i) {
            withdrawnAssets[i] = _withdrawnAssets[smartVault][data.flushIndex][i] * data.vaultShares
                / _withdrawnVaultShares[smartVault][data.flushIndex];
        }

        return withdrawnAssets;
    }
}

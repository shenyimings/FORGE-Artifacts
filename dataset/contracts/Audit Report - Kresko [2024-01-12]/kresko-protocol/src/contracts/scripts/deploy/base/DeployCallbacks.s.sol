// solhint-disable state-visibility, max-states-count, var-name-mixedcase, no-global-import, const-name-snakecase, no-empty-blocks, no-console

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {RawPrice} from "common/Types.sol";
import {VaultAsset} from "vault/VTypes.sol";
import {ScriptBase} from "kresko-lib/utils/ScriptBase.s.sol";
import {KreskoForgeUtils} from "scripts/utils/KreskoForgeUtils.s.sol";
import {IDeployState} from "./IDeployState.sol";
import {state} from "./DeployState.s.sol";
import {Help, Log} from "kresko-lib/utils/Libs.sol";

abstract contract DeployCallbacks is IDeployState, KreskoForgeUtils {
    function onConfigurationsCreated(
        State storage _ctx,
        CoreConfig memory _cfg,
        AssetCfg memory _assetCfg,
        UserCfg[] memory _userCfg
    ) internal virtual {}

    function onCoreContractsCreated(State storage _ctx) internal virtual {}

    function onContractsCreated(State storage _ctx) internal virtual {}

    function onKISSCreated(State storage _ctx, KISSInfo memory _onChainInfo) internal virtual {}

    function onKrAssetAdded(State storage _ctx, KrAssetInfo memory _onChainInfo) internal virtual {}

    function onVaultAssetAdded(State storage _ctx, string memory _symbol, VaultAsset memory _onChainInfo) internal virtual {}

    function onExtAssetAdded(State storage _ctx, ExtAssetInfo memory _onChainInfo) internal virtual {}

    function onAssetsComplete(State storage _ctx, IDeployState.AssetsOnChain memory _onChainInfo) internal virtual {}

    function onDeploymentComplete(State storage _ctx) internal virtual {}

    function onComplete(State storage _ctx) internal virtual {}
}

abstract contract BaseLogger is DeployCallbacks, ScriptBase {
    using Help for *;
    using Log for *;

    function enableLogger() internal {
        state().logEnabled = true;
    }

    function onConfigurationsCreated(
        State storage,
        CoreConfig memory coreCfg,
        AssetCfg memory assetCfg,
        UserCfg[] memory userCfg
    ) internal override {
        ("/* ------------------------------- Deploying -------------------------------- */").clg();
        Log.br();
        super.logCallers();
        Log.br();
        ("/* ------------------------------ Configuration ----------------------------- */").clg();
        Log.br();
        coreCfg.admin.clg("Admin");
        coreCfg.seqFeed.clg("Sequencer");
        coreCfg.council.clg("Council");
        coreCfg.treasury.clg("Treasury");
        coreCfg.minterMcr.pct("Minter MCR");
        coreCfg.minterLt.pct("Minter LT");
        coreCfg.scdpMcr.pct("SCDP MCR");
        coreCfg.scdpLt.pct("SCDP LT");
        coreCfg.staleTime.clg("Oracle Stale Price Time");
        coreCfg.oraclePrecision.clg("Oracle Price Precision");
        coreCfg.sdiPrecision.clg("SDI Price Precision");
        ("-------  Assets --------").clg();
        assetCfg.ext.length.clg("Total External Assets");
        assetCfg.kra.length.clg("Total Kresko Assets");
        assetCfg.vassets.length.clg("Total Vault Assets");
        ("-------  Users --------").clg();
        userCfg.length.clg("Total Test Users: ");
    }

    function onKISSCreated(State storage _ctx, KISSInfo memory) internal override {
        Log.br();
        ("/* ------------------------------ Contracts ----------------------------- */").clg();
        Log.br();
        address(_ctx.kresko).clg("Diamond");
        address(_ctx.vault).clg("Vault");
        address(_ctx.kiss).clg("KISS");
        address(_ctx.factory).clg("Deployment Factory");
    }

    function onKrAssetAdded(State storage _ctx, KrAssetInfo memory _info) internal override {
        RawPrice memory price = _ctx.kresko.getPushPrice(_info.addr);
        Log.br();
        ("/* ------------------------------ Kresko Asset ------------------------------ */").clg();
        _info.symbol.clg("Symbol");
        _info.addr.clg("Address");
        ("-------  Types --------").clg();
        _info.config.isMinterMintable.clg("Minter Mintable");
        _info.config.isMinterCollateral.clg("Minter Collateral");
        _info.config.isSwapMintable.clg("SCDP Swappable");
        _info.config.isSharedCollateral.clg("SCDP Depositable");
        ("-------  Oracle --------").clg();
        _info.config.ticker.blg2txt("Ticker");
        price.feed.clg("Feed");
        uint256(price.answer).dlg("Feed Price", 8);
        ([uint8(_info.config.oracles[0]), uint8(_info.config.oracles[1])]).clg("Oracle Types");
        ("-------  Config --------").clg();
        _info.config.maxDebtMinter.dlg("Minter Debt Limit", 18);
        _info.config.maxDebtSCDP.dlg("SCDP Debt Limit", 18);
        _info.config.kFactor.pct("kFactor");
        _info.config.factor.pct("cFactor");
        _info.config.openFee.pct("Minter Open Fee");
        _info.config.closeFee.pct("Minter Close Fee");
        _info.config.swapInFeeSCDP.pct("SCDP Swap In Fee");
        _info.config.swapOutFeeSCDP.pct("SCDP Swap Out Fee");
        _info.config.protocolFeeShareSCDP.pct("SCDP Protocol Fee");
        _info.config.liqIncentiveSCDP.pct("SCDP Liquidation Incentive");
    }

    function onExtAssetAdded(State storage _ctx, ExtAssetInfo memory _info) internal override {
        RawPrice memory price = _ctx.kresko.getPushPrice(_info.addr);
        Log.br();
        ("/* ----------------------------- External Asset ----------------------------- */").clg();
        _info.symbol.clg("Symbol");
        _info.addr.clg("Address");
        ("-------  Types --------").clg();
        _info.config.isMinterMintable.clg("Minter Mintable");
        _info.config.isMinterCollateral.clg("Minter Collateral");
        _info.config.isSwapMintable.clg("SCDP Swappable");
        _info.config.isSharedCollateral.clg("SCDP Depositable");
        ("-------  Oracle --------").clg();
        _info.config.ticker.blg2txt("Ticker");
        price.feed.clg("Feed");
        price.answer.dlg("Feed Price", 8);
        ([uint8(_info.config.oracles[0]), uint8(_info.config.oracles[1])]).clg("Oracle Types");
        ("-------  Config --------").clg();
        _info.config.kFactor.pct("kFactor");
        _info.config.factor.pct("cFactor");
        _info.config.liqIncentive.pct("Liquidation Incentive");
    }

    function onVaultAssetAdded(State storage _ctx, string memory _symbol, VaultAsset memory _info) internal override {
        address assetAddr = address(_info.token);
        Log.br();
        ("/* ------------------------------- Vault Asset ------------------------------ */").clg();
        _symbol.clg("Symbol");
        assetAddr.clg("Address");
        _info.decimals.clg("Decimals");
        ("-------  Oracle --------").clg();
        address(_info.feed).clg("Feed");
        _ctx.vault.assetPrice(assetAddr).dlg("Price", 8);
        _info.staleTime.clg("Stale Price Time");
        ("-------  Config --------").clg();
        _info.maxDeposits.dlg("Max Deposit Amount", _info.decimals);
        _info.depositFee.pct("Deposit Fee");
        _info.withdrawFee.pct("Withdraw Fee");
    }

    function onComplete(State storage _ctx) internal override {
        Log.br();
        Log.sr();
        Log.sr();
        ("*******************  FINISHED  *******************").clg();
        Log.sr();
        Log.sr();
        for (uint256 j; j < _ctx.userCfg.length; j++) {
            Log.br();
            Log.hr();
            j.clg("Test User");
            _ctx.userCfg[j].addr.clg("Address");
            Log.hr();
            emit Log.log_named_decimal_uint("Ether", _ctx.userCfg[j].addr.balance, 18);
            for (uint256 i; i < _ctx.assetsOnChain.ext.length; i++) {
                ExtAssetInfo memory asset = _ctx.assetsOnChain.ext[i];
                uint256 balance = asset.token.balanceOf(_ctx.userCfg[j].addr);
                balance.dlg(asset.symbol, asset.config.decimals);
                // emit Log.log_named_decimal_uint(asset.symbol, balance, asset.config.decimals);
            }
        }
        Log.hr();
    }
}

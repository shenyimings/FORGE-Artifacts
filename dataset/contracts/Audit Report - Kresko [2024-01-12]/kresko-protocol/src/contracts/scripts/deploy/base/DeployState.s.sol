// solhint-disable state-visibility, max-states-count, var-name-mixedcase, no-global-import, const-name-snakecase, no-empty-blocks, no-console
// SPDX-License-Identifier: MIT
pragma solidity <0.9.0;

import {Arrays} from "libs/Arrays.sol";
import {WETH9} from "kresko-lib/token/WETH9.sol";
import {IERC20} from "kresko-lib/token/IERC20.sol";

import {MockERC20} from "mocks/MockERC20.sol";
import {IKresko} from "periphery/IKresko.sol";
import {DeploymentFactory} from "factory/DeploymentFactory.sol";
import {Deployment} from "factory/IDeploymentFactory.sol";
import {Asset} from "common/Types.sol";
import {LibVm} from "kresko-lib/utils/Libs.sol";
import {VaultAsset} from "vault/VTypes.sol";
import {Vault} from "vault/Vault.sol";
import {BaseLogger} from "./DeployCallbacks.s.sol";
import {IDeployState} from "scripts/deploy/base/IDeployState.sol";

using Arrays for bytes32[];
using Arrays for address[];
using Arrays for string[];

function state() pure returns (IDeployState.State storage ctx_) {
    bytes32 slot = keccak256("devnet.deploy.ctx");
    assembly {
        ctx_.slot := slot
    }
}

/// @notice Handles callbacks that update the state and logs.
abstract contract DeployStateHandlers is BaseLogger {
    function afterAssetConfigs(AssetCfg memory _assetCfg) internal {
        $.saveAssetDeployConfig(_assetCfg);
    }

    function afterCoreConfig(CoreConfig memory _cfg) internal {
        require(_cfg.admin != address(0), "createCoreConfig: coreArgs should have some admin address set");
        super.onConfigurationsCreated($.saveCoreDeployConfig(_cfg), _cfg, state().assetCfg, state().userCfg);
    }

    function afterUserConfig(UserCfg[] memory _cfg) internal {
        $.saveUserDeployConfig(_cfg);
    }

    function beforeCreateCore(CoreConfig memory) internal {
        $.saveDeployer();
    }

    function afterCoreCreated(IKresko _kresko, DeploymentFactory _proxyFactory) internal {
        super.onCoreContractsCreated($.saveCoreDeployments(_kresko, _proxyFactory));
    }

    function afterVaultCreated(Vault _vault) internal {
        $.saveVaultDeployment(_vault);
    }

    function handleNewKrAsset(KrAssetDeployInfo memory _deployment) internal {
        $.saveToken(_deployment.addr, _deployment.symbol);
        $.saveToken(address(_deployment.anchorProxy.proxy), _deployment.anchorSymbol);
        $.saveProxy(_deployment.krAssetProxy, _deployment.symbol);
        $.saveProxy(_deployment.anchorProxy, _deployment.anchorSymbol);
    }

    function afterKrAssetsCreated(KrAssetDeployInfo[] memory _deployments) internal {
        require(_deployments.length > 0, "DevnetDeployContext: Should deploy some krAssets");
        for (uint256 i; i < _deployments.length; i++) {
            handleNewKrAsset(_deployments[i]);
        }

        super.onContractsCreated(state());
    }

    function afterKISSCreated(KISSInfo memory _kissInfo, address _vaultAddr) internal {
        $.saveKISSDeployment(_kissInfo, _vaultAddr);
        super.onKISSCreated(state(), _kissInfo);
    }

    function afterVaultAssetAdded(VaultAsset memory _onChainInfo) internal {
        (IDeployState.State storage _ctx, string memory symbol) = $.saveVaultAsset(_onChainInfo);
        super.onVaultAssetAdded(_ctx, symbol, _onChainInfo);
    }

    function afterVaultAssetsComplete() internal {}

    function afterKrAssetAdded(KrAssetInfo memory _onChainInfo) internal {
        super.onKrAssetAdded(state(), _onChainInfo);
    }

    function afterKISSAdded(KISSInfo memory _onChainInfo) internal {
        KrAssetInfo memory _kissAsKrAsset;
        _kissAsKrAsset.addr = _onChainInfo.addr;
        _kissAsKrAsset.symbol = "KISS";
        _kissAsKrAsset.config = _onChainInfo.config;
        _kissAsKrAsset.krAssetProxy = _onChainInfo.proxy;
        _kissAsKrAsset.feedAddr = _onChainInfo.vaultAddr;
        onKrAssetAdded(state(), _kissAsKrAsset);
    }

    function afterExtAssetAdded(ExtAssetInfo memory _onChainInfo) internal {
        super.onExtAssetAdded(state(), _onChainInfo);
    }

    function afterAssetsComplete(AssetsOnChain memory _onChainInfo) internal returns (AssetsOnChain memory result_) {
        result_ = $.saveAssets(_onChainInfo);
        super.onAssetsComplete(state(), result_);
    }

    function afterDeployment() internal {
        super.onDeploymentComplete(state());
    }

    function afterComplete() internal {
        super.onComplete(state());
    }
}

/// @dev IDeployState.State lives here for easy access
library $ {
    function saveDeployer() internal {
        state().deployer = LibVm.sender();
    }

    function saveCoreDeployments(
        IKresko _kresko,
        DeploymentFactory _proxyFactory
    ) internal returns (IDeployState.State storage ctx_) {
        state().kresko = _kresko;
        state().factory = _proxyFactory;
        return state();
    }

    function saveVaultDeployment(Vault _vault) internal {
        state().vault = _vault;
        saveToken(address(_vault), "vKISS");
        saveFeed(address(_vault), "vKISS");
    }

    function saveKISSDeployment(IDeployState.KISSInfo memory _kissInfo, address _vaultAddr) internal {
        state().kiss = _kissInfo.kiss;
        saveToken(address(_kissInfo.proxy.proxy), "KISS");
        saveProxy(_kissInfo.proxy, "KISS");
        saveFeed(_vaultAddr, "KISS");
    }

    function saveToken(address _token, string memory symbol) internal {
        state().getAddress[symbol] = _token;
        state().getToken[symbol] = IERC20(_token);
        state().getMockToken[symbol] = MockERC20(_token);
        state().allTokens.push(IERC20(_token));
        state().allSymbols.pushUnique(symbol);
    }

    function saveFeed(address _feed, string memory symbol) internal {
        state().getFeed[symbol] = _feed;
        state().allFeeds.push(_feed);
    }

    function saveProxy(Deployment memory _proxy, string memory symbol) internal {
        state().getDeploy[symbol] = _proxy;
        state().allProxies.push(_proxy);
    }

    function saveVaultAsset(
        VaultAsset memory _onChainInfo
    ) internal returns (IDeployState.State storage ctx_, string memory symbol_) {
        uint256 count = state().assetsOnChain.vaultAssetCount;
        string memory symbol = state().assetCfg.vaultSymbols[count];
        state().getVAsset[symbol] = _onChainInfo;
        state().assetsOnChain.vassets.push(_onChainInfo);
        state().assetsOnChain.vaultSymbols.pushUnique(symbol);
        state().assetsOnChain.vaultAssetCount = count + 1;

        return (state(), symbol);
    }

    function saveAssets(
        IDeployState.AssetsOnChain memory _results
    ) internal returns (IDeployState.AssetsOnChain memory results_) {
        for (uint256 i; i < _results.ext.length; i++) {
            saveAssetConfig(_results.ext[i].config, _results.ext[i].symbol);
            state().extAssetAt[i] = _results.ext[i];
            state().assetsOnChain.ext.push(_results.ext[i]);
        }
        for (uint256 i; i < _results.kra.length; i++) {
            saveAssetConfig(_results.kra[i].config, _results.kra[i].symbol);
            state().krAssetAt[i] = _results.kra[i];
            state().assetsOnChain.kra.push(_results.kra[i]);
        }

        state().assetsOnChain.kiss = _results.kiss;

        saveAssetConfig(_results.kiss.config, "KISS");
        saveAssetConfig(_results.kiss.config, "vKISS");

        state().assetsOnChain.extAssetCount = _results.ext.length;
        state().assetsOnChain.krAssetCount = _results.kra.length;
        state().weth = WETH9(payable(address(_results.ext[_results.wethIndex].token)));
        return state().assetsOnChain;
    }

    function saveAssetConfig(Asset memory _asset, string memory _symbol) internal {
        state().getAsset[_symbol] = _asset;
        state().allAssets.push(_asset);
        state().allTickers.pushUnique(_asset.ticker);
    }

    function saveCoreDeployConfig(IDeployState.CoreConfig memory _cfg) internal returns (IDeployState.State storage ctx_) {
        state().cfg = _cfg;
        return state();
    }

    function saveAssetDeployConfig(IDeployState.AssetCfg memory _cfg) internal returns (IDeployState.State storage ctx_) {
        for (uint256 i; i < _cfg.ext.length; i++) {
            saveToken(address(_cfg.ext[i].token), _cfg.ext[i].symbol);
            saveFeed(_cfg.ext[i].feeds[1], _cfg.ext[i].symbol);

            state().assetCfg.ext.push(_cfg.ext[i]);
        }
        for (uint256 i; i < _cfg.kra.length; i++) {
            saveFeed(_cfg.ext[i].feeds[1], _cfg.ext[i].symbol);
            state().assetCfg.kra.push(_cfg.kra[i]);
        }

        for (uint256 i; i < _cfg.vassets.length; i++) {
            state().getVFeed[_cfg.vaultSymbols[i]] = _cfg.vassets[i].feed;
            state().allFeeds.push(address(_cfg.vassets[i].feed));

            state().assetCfg.vassets.push(_cfg.vassets[i]);
            state().assetCfg.vaultSymbols.push(_cfg.vaultSymbols[i]);
        }
        state().assetCfg.wethIndex = _cfg.wethIndex;
        state().weth = WETH9(payable(address((_cfg.ext[_cfg.wethIndex].token))));
        return state();
    }

    function saveUserDeployConfig(IDeployState.UserCfg[] memory _cfg) internal returns (IDeployState.State storage ctx_) {
        for (uint256 i; i < _cfg.length; i++) {
            state().userCfg.push(_cfg[i]);
        }
        return state();
    }
}

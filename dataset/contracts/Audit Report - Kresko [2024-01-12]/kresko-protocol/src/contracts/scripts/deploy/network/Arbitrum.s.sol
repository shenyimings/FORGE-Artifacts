// solhint-disable state-visibility, max-states-count, var-name-mixedcase, no-global-import, const-name-snakecase, no-empty-blocks, no-console
// SPDX-License-Identifier: MIT
pragma solidity <0.9.0;

import {IERC20} from "kresko-lib/token/IERC20.sol";
import {ISCDPConfigFacet} from "scdp/interfaces/ISCDPConfigFacet.sol";
import {Addr, Tokens, ChainLink} from "kresko-lib/info/Arbitrum.sol";
import {DefaultDeployConfig} from "scripts/deploy/config/DefaultDeployConfig.s.sol";
import {SwapRouteSetter} from "scdp/STypes.sol";

/**
 * @dev Arbitrum deployment using defaults
 * @dev Implements the functions that are called by launch scripts
 */
abstract contract ArbitrumDeployment is DefaultDeployConfig {
    constructor(string memory _mnemonicId) DefaultDeployConfig(_mnemonicId) {}

    function createAssetConfig() internal override returns (AssetCfg memory assetCfg_) {
        WETH = Tokens.WETH;
        IERC20 WETH20 = IERC20(address(WETH));

        feeds_eth = [address(0), Addr.CL_ETH];
        feeds_btc = [address(0), Addr.CL_BTC];
        feeds_dai = [address(0), Addr.CL_DAI];
        feeds_eur = [address(0), Addr.CL_EUR];
        feeds_usdc = [address(0), Addr.CL_USDC];
        feeds_usdt = [address(0), Addr.CL_USDT];
        feeds_jpy = [address(0), Addr.CL_JPY];

        assetCfg_.wethIndex = 0;

        string memory symbol_DAI = Tokens.DAI.symbol();
        string memory symbol_USDC = Tokens.USDC.symbol();
        string memory symbol_USDT = Tokens.USDT.symbol();
        assetCfg_.ext = EXT_ASSET_CONFIG(
            [WETH20, Tokens.WBTC, Tokens.DAI, Tokens.USDC, Tokens.USDT],
            [WETH20.symbol(), Tokens.WBTC.symbol(), symbol_DAI, symbol_USDC, symbol_USDT],
            [feeds_eth, feeds_btc, feeds_dai, feeds_usdc, feeds_usdt]
        );
        assetCfg_.kra = KR_ASSET_CONFIG(
            [address(WETH), address(Tokens.WBTC), address(0), address(0)],
            [feeds_eth, feeds_btc, feeds_eur, feeds_jpy]
        );
        assetCfg_.vassets = VAULT_ASSET_CONFIG(
            [Tokens.DAI, Tokens.USDC, Tokens.USDT],
            [ChainLink.DAI, ChainLink.USDC, ChainLink.USDT]
        );

        string[] memory vAssetSymbols = new string[](3);
        vAssetSymbols[0] = symbol_DAI;
        vAssetSymbols[1] = symbol_USDC;
        vAssetSymbols[2] = symbol_USDT;
        assetCfg_.vaultSymbols = vAssetSymbols;

        super.afterAssetConfigs(assetCfg_);
    }

    function createCoreConfig(address _admin, address _treasury) internal override returns (CoreConfig memory cfg_) {
        cfg_ = CoreConfig({
            admin: _admin,
            seqFeed: Addr.CL_SEQ_UPTIME,
            staleTime: 86401,
            minterMcr: 150e2,
            minterLt: 140e2,
            scdpMcr: 200e2,
            scdpLt: 150e2,
            sdiPrecision: 8,
            oraclePrecision: 8,
            council: getMockSafe(_admin),
            treasury: _treasury
        });

        deployCfg = cfg_;

        super.afterCoreConfig(cfg_);
    }

    function configureSwap(address _kreskoAddr, AssetsOnChain memory _assetsOnChain) internal override {
        ISCDPConfigFacet facet = ISCDPConfigFacet(_kreskoAddr);
        address kissAddr = _assetsOnChain.kiss.addr;

        facet.setFeeAssetSCDP(kissAddr);

        // @todo Use assets only from _assetsOnChain
        SwapRouteSetter[] memory routing = new SwapRouteSetter[](9);
        routing[0] = SwapRouteSetter({assetIn: kissAddr, assetOut: krETH.addr, enabled: true});
        routing[1] = SwapRouteSetter({assetIn: kissAddr, assetOut: krBTC.addr, enabled: true});
        routing[2] = SwapRouteSetter({assetIn: kissAddr, assetOut: krEUR.addr, enabled: true});

        routing[3] = SwapRouteSetter({assetIn: krETH.addr, assetOut: krBTC.addr, enabled: true});
        routing[4] = SwapRouteSetter({assetIn: krETH.addr, assetOut: krJPY.addr, enabled: true});
        routing[5] = SwapRouteSetter({assetIn: krETH.addr, assetOut: krEUR.addr, enabled: true});

        routing[6] = SwapRouteSetter({assetIn: krBTC.addr, assetOut: krEUR.addr, enabled: true});
        routing[7] = SwapRouteSetter({assetIn: krBTC.addr, assetOut: krJPY.addr, enabled: true});

        routing[8] = SwapRouteSetter({assetIn: krEUR.addr, assetOut: krJPY.addr, enabled: true});

        facet.setSwapRoutesSCDP(routing);
        facet.setSingleSwapRouteSCDP(SwapRouteSetter({assetIn: krJPY.addr, assetOut: kissAddr, enabled: true})); //
        super.configureSwap(_kreskoAddr, _assetsOnChain);
    }

    function setupUsers(UserCfg[] memory _userCfg, AssetsOnChain memory _results) internal override {}
}

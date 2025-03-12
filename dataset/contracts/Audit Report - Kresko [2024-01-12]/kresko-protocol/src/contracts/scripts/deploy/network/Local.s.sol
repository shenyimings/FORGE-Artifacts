// solhint-disable state-visibility, max-states-count, var-name-mixedcase, no-global-import, const-name-snakecase, no-empty-blocks, no-console
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MockSequencerUptimeFeed} from "mocks/MockSequencerUptimeFeed.sol";
import {WETH9} from "kresko-lib/token/WETH9.sol";
import {IWETH9} from "kresko-lib/token/IWETH9.sol";
import {MockOracle} from "mocks/MockOracle.sol";
import {MockERC20} from "mocks/MockERC20.sol";
import {ISCDPConfigFacet} from "scdp/interfaces/ISCDPConfigFacet.sol";
import {IERC20} from "kresko-lib/token/IERC20.sol";
import {IERC20} from "kresko-lib/token/IERC20.sol";
import {WETH9} from "kresko-lib/token/WETH9.sol";
import {SwapRouteSetter} from "scdp/STypes.sol";
import {Help} from "kresko-lib/utils/Libs.sol";
import {DefaultDeployConfig} from "scripts/deploy/config/DefaultDeployConfig.s.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

using Help for string;

abstract contract LocalDeployment is StdCheats, DefaultDeployConfig {
    constructor(string memory _mnemonicId) DefaultDeployConfig(_mnemonicId) {}

    MockTokenInfo internal mockWBTC;
    MockTokenInfo internal mockDAI;
    MockTokenInfo internal mockUSDC;
    MockTokenInfo internal mockUSDT;
    MockOracle internal mockFeedETH;
    MockOracle internal mockFeedEUR;
    MockOracle internal mockFeedJPY;

    function createAssetConfig() internal override returns (AssetCfg memory assetCfg_) {
        WETH = IWETH9(address(new WETH9()));
        IERC20 WETH20 = IERC20(address(WETH));

        mockWBTC = super.deployMockTokenAndOracle(MockConfig("WBTC", price_btc, 8, 8, false));
        mockDAI = super.deployMockTokenAndOracle(MockConfig("DAI", price_dai, 18, 8, true));
        mockUSDC = super.deployMockTokenAndOracle(MockConfig("USDC", price_usdc, 18, 8, true));
        mockUSDT = super.deployMockTokenAndOracle(MockConfig("USDT", price_usdt, 6, 8, true));

        mockFeedETH = new MockOracle("ETH", price_eth, 8);
        mockFeedEUR = new MockOracle("EUR", price_eur, 8);
        mockFeedJPY = new MockOracle("JPY", price_jpy, 8);

        feeds_eth = [address(0), address(mockFeedETH)];
        feeds_eur = [address(0), address(mockFeedEUR)];
        feeds_jpy = [address(0), address(mockFeedJPY)];
        feeds_btc = [address(0), mockWBTC.feedAddr];
        feeds_dai = [address(0), mockDAI.feedAddr];
        feeds_usdc = [address(0), mockUSDC.feedAddr];
        feeds_usdt = [address(0), mockUSDT.feedAddr];

        assetCfg_.ext = EXT_ASSET_CONFIG(
            [WETH20, mockWBTC.asToken, mockDAI.asToken, mockUSDC.asToken, mockUSDT.asToken],
            ["WETH", mockWBTC.symbol, mockDAI.symbol, mockUSDC.symbol, mockUSDT.symbol],
            [feeds_eth, feeds_btc, feeds_dai, feeds_usdc, feeds_usdt]
        );
        assetCfg_.wethIndex = 0;

        assetCfg_.kra = KR_ASSET_CONFIG(
            [address(WETH), mockWBTC.addr, address(0), address(0)],
            [feeds_eth, feeds_btc, feeds_eur, feeds_jpy]
        );
        assetCfg_.vassets = VAULT_ASSET_CONFIG(
            [mockDAI.asToken, mockUSDC.asToken, mockUSDT.asToken],
            [mockDAI.feed, mockUSDC.feed, mockUSDT.feed]
        );
        string[] memory vAssetSymbols = new string[](3);
        vAssetSymbols[0] = mockDAI.symbol;
        vAssetSymbols[1] = mockUSDC.symbol;
        vAssetSymbols[2] = mockUSDT.symbol;
        assetCfg_.vaultSymbols = vAssetSymbols;

        super.afterAssetConfigs(assetCfg_);
    }

    function createCoreConfig(address _admin, address _treasury) internal override returns (CoreConfig memory cfg_) {
        cfg_ = CoreConfig({
            admin: _admin,
            seqFeed: address(new MockSequencerUptimeFeed()),
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

        facet.setSingleSwapRouteSCDP(SwapRouteSetter({assetIn: krJPY.addr, assetOut: kissAddr, enabled: true})); //
        facet.setSwapRoutesSCDP(routing);
        super.configureSwap(_kreskoAddr, _assetsOnChain);
    }

    function setupUsers(UserCfg[] memory _userCfg, AssetsOnChain memory _assetsOnChain) internal override {
        unchecked {
            for (uint256 i; i < _userCfg.length; i++) {
                if (_userCfg[i].addr != address(0)) {
                    UserCfg memory user = _userCfg[i];

                    for (uint256 j; j < user.bal.length; j++) {
                        if (user.bal[j] == 0) continue;

                        if (j == _assetsOnChain.wethIndex) {
                            broadcastWith(user.addr);
                            IWETH9(_assetsOnChain.ext[j].addr).deposit{value: user.bal[j]}();
                        } else {
                            MockERC20(_assetsOnChain.ext[j].addr).mint(user.addr, user.bal[j]);
                        }
                    }
                }
            }
        }

        super.afterComplete();
    }
}

// solhint-disable state-visibility, event-name-camelcase, max-states-count, var-name-mixedcase, no-global-import, const-name-snakecase, no-empty-blocks, no-console
// SPDX-License-Identifier: MIT
pragma solidity <0.9.0;

import {IAggregatorV3} from "kresko-lib/vendor/IAggregatorV3.sol";
import {IERC20} from "kresko-lib/token/IERC20.sol";
import {IWETH9} from "kresko-lib/token/IWETH9.sol";
import {VaultAsset} from "vault/VTypes.sol";
import {ScriptBase} from "kresko-lib/utils/ScriptBase.s.sol";
import {Help} from "kresko-lib/utils/Libs.sol";
import {DeployLogicBase} from "scripts/deploy/base/DeployLogic.s.sol";

/**
 * @dev Default asset and price configuration
 */
abstract contract DefaultDeployConfig is ScriptBase, DeployLogicBase {
    using Help for *;

    constructor(string memory _mnemonicId) ScriptBase(_mnemonicId) {}

    uint256 constant EXT_COUNT = 5;
    uint256 constant KR_COUNT = 4;
    uint256 constant VAULT_COUNT = 3;
    /* --------------------------------- assets --------------------------------- */
    // @todo remove explicit state
    IWETH9 internal WETH;
    IERC20 internal WBTC;
    IERC20 internal DAI;
    IERC20 internal USDC;
    IERC20 internal USDT;
    /* ------------------------------------ . ----------------------------------- */
    // @todo  remove explicit state

    KrAssetInfo internal krETH;
    KrAssetInfo internal krBTC;
    KrAssetInfo internal krJPY;
    KrAssetInfo internal krEUR;

    /* ------------------------------------ . ----------------------------------- */
    address[2] internal feeds_eth;
    address[2] internal feeds_btc;
    address[2] internal feeds_eur;
    address[2] internal feeds_dai;
    address[2] internal feeds_usdt;
    address[2] internal feeds_usdc;
    address[2] internal feeds_jpy;
    /* ------------------------------------ . ----------------------------------- */
    uint256 constant price_eth = 2000e8;
    uint256 constant price_btc = 27662e8;
    uint256 constant price_dai = 1e8;
    uint256 constant price_eur = 1.06e8;
    uint256 constant price_usdc = 1e8;
    uint256 constant price_usdt = 1e8;
    uint256 constant price_jpy = 0.0067e8;
    /* ------------------------------------ . ----------------------------------- */
    // @todo can probably delete these aswell
    string constant price_eth_rs = "ETH:1590:8";
    string constant price_btc_rs = "BTC:27662:8";
    string constant price_eur_rs = "EUR:1.06:8";
    string constant price_dai_rs = "DAI:1:8";
    string constant price_usdc_rs = "USDC:1:8";
    string constant price_usdt_rs = "USDT:1:8";
    string constant price_jpy_rs = "JPY:0.0067:8";

    /* -------------------------------------------------------------------------- */
    /*                                  Handlers                                  */
    /* -------------------------------------------------------------------------- */

    /// @notice ETH, BTC, DAI, USDC, USDT
    function EXT_ASSET_CONFIG(
        IERC20[EXT_COUNT] memory _tokens,
        string[EXT_COUNT] memory _sym,
        address[2][EXT_COUNT] memory _feeds
    ) internal view returns (ExtAssetCfg[] memory ext_) {
        ext_ = new ExtAssetCfg[](EXT_COUNT);
        ext_[0] = ExtAssetCfg(bytes32("ETH"), _sym[0], _tokens[0], _feeds[0], OT_RS_CL, ext_default, false);
        ext_[1] = ExtAssetCfg(bytes32("BTC"), _sym[1], _tokens[1], _feeds[1], OT_RS_CL, ext_default, false);
        ext_[2] = ExtAssetCfg(bytes32("DAI"), _sym[2], _tokens[2], _feeds[2], OT_RS_CL, ext_default, true);
        ext_[3] = ExtAssetCfg(bytes32("USDC"), _sym[3], _tokens[3], _feeds[3], OT_RS_CL, ext_default, true);
        ext_[4] = ExtAssetCfg(bytes32("USDT"), _sym[4], _tokens[4], _feeds[4], OT_RS_CL, ext_default, true);
    }

    /// @notice ETH, BTC, EUR, JPY
    function KR_ASSET_CONFIG(
        address[KR_COUNT] memory _ulying,
        address[2][KR_COUNT] memory _feeds
    ) internal view returns (KrAssetCfg[] memory kra_) {
        kra_ = new KrAssetCfg[](KR_COUNT);
        kra_[0] = KrAssetCfg("Kresko: Ether", "krETH", bytes32("ETH"), _ulying[0], _feeds[0], OT_RS_CL, kr_default, true);
        kra_[1] = KrAssetCfg("Kresko: Bitcoin", "krBTC", bytes32("BTC"), _ulying[1], _feeds[1], OT_RS_CL, kr_default, true);
        kra_[2] = KrAssetCfg("Kresko: Euro", "krEUR", bytes32("EUR"), _ulying[2], _feeds[2], OT_RS_CL, kr_default, true);
        kra_[3] = KrAssetCfg("Kresko: Yen", "krJPY", bytes32("JPY"), _ulying[3], _feeds[3], OT_RS_CL, kr_default, true);
    }

    /// @notice DAI, USDC, USDT
    function VAULT_ASSET_CONFIG(
        IERC20[VAULT_COUNT] memory _tokens,
        IAggregatorV3[VAULT_COUNT] memory _feeds
    ) internal pure returns (VaultAsset[] memory vault_) {
        vault_ = new VaultAsset[](3);
        vault_[0] = VaultAsset({
            token: _tokens[0],
            feed: _feeds[0],
            staleTime: 86401,
            decimals: 0,
            depositFee: 2,
            withdrawFee: 2,
            maxDeposits: type(uint248).max,
            enabled: true
        });
        vault_[1] = VaultAsset({
            token: _tokens[1],
            feed: _feeds[1],
            staleTime: 86401,
            decimals: 0,
            depositFee: 2,
            withdrawFee: 2,
            maxDeposits: type(uint248).max,
            enabled: true
        });
        vault_[2] = VaultAsset({
            token: _tokens[2],
            feed: _feeds[2],
            staleTime: 86401,
            decimals: 0,
            depositFee: 0,
            withdrawFee: 0,
            maxDeposits: type(uint248).max,
            enabled: true
        });
    }

    // @todo Remove explicit state for assets (and this helper step that sets them).
    function addAssets(
        AssetCfg memory _assetCfg,
        KrAssetDeployInfo[] memory _kraContracts,
        KISSInfo memory _kiss,
        address _kreskoAddr
    ) internal virtual override returns (AssetsOnChain memory results_) {
        results_ = super.addAssets(_assetCfg, _kraContracts, _kiss, _kreskoAddr);

        krETH = results_.kra[0];
        krBTC = results_.kra[1];
        krEUR = results_.kra[2];
        krJPY = results_.kra[3];

        WETH = IWETH9(results_.ext[0].addr);
        WBTC = results_.ext[1].token;
        DAI = results_.ext[2].token;
        USDC = results_.ext[3].token;
        USDT = results_.ext[4].token;
    }

    /* ---------------------------------- users --------------------------------- */
    uint256 internal constant USER_COUNT = 6;

    function createUserConfig(uint32[USER_COUNT] memory _idxs) internal returns (UserCfg[] memory userCfg_) {
        userCfg_ = new UserCfg[](USER_COUNT);

        uint256[EXT_COUNT][] memory bals = new uint256[EXT_COUNT][](USER_COUNT);

        bals[0] = [uint256(100 ether), 10e8, 10000e18, 10000e18, 10000e6]; // deployer
        bals[1] = [uint256(0), 0, 0, 0, 0]; // nothing
        bals[2] = [uint256(100 ether), 10e8, 1e24, 1e24, 1e12]; // a lot
        bals[3] = [uint256(0.05 ether), 0.01e8, 50e18, 10e18, 5e6]; // low
        bals[4] = [uint256(2 ether), 0.05e8, 3000e18, 1000e18, 800e6];
        bals[5] = [uint256(2 ether), 0.05e8, 3000e18, 1000e18, 800e6];

        return createUserConfig(_idxs.dyn(), bals);
    }

    function createUserConfig(
        uint32[] memory _idxs,
        uint256[EXT_COUNT][] memory _bals
    ) internal returns (UserCfg[] memory userCfg_) {
        require(_idxs.length == _bals.length, "createUserConfig: idxs and bals length mismatch");
        userCfg_ = new UserCfg[](_idxs.length);
        unchecked {
            for (uint256 i; i < _idxs.length; i++) {
                address userAddr = getAddr(_idxs[i]);
                vm.deal(userAddr, _bals[i][0] + 100 ether);
                userCfg_[i] = UserCfg(userAddr, _bals[i].dyn());
            }
        }

        super.afterUserConfig(userCfg_);
    }

    function configureSwap(address, AssetsOnChain memory) internal virtual override {
        super.afterDeployment();
    }

    function setupUsers(UserCfg[] memory _usersCfg, AssetsOnChain memory _assetsOnChain) internal virtual;
}

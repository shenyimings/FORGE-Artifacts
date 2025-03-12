pragma solidity 0.8.21;
import {FacetScript} from "kresko-lib/utils/Diamond.sol";
import {RedstoneScript} from "kresko-lib/utils/Redstone.sol";
import {CommonInitArgs} from "common/Types.sol";
import {MinterInitArgs} from "minter/MTypes.sol";
import {IKreskoForgeTypes} from "./IKreskoForgeTypes.sol";
import {FacetCut, Initializer, FacetCutAction} from "diamond/DSTypes.sol";
import {Diamond} from "diamond/Diamond.sol";
import {DiamondCutFacet} from "diamond/facets/DiamondCutFacet.sol";
import {DiamondStateFacet} from "diamond/facets/DiamondStateFacet.sol";
import {DiamondLoupeFacet} from "diamond/facets/DiamondLoupeFacet.sol";
import {ERC165Facet} from "diamond/facets/ERC165Facet.sol";

import {MinterMintFacet} from "minter/facets/MinterMintFacet.sol";
import {MinterBurnFacet} from "minter/facets/MinterBurnFacet.sol";
import {MinterDepositWithdrawFacet} from "minter/facets/MinterDepositWithdrawFacet.sol";
import {MinterAccountStateFacet} from "minter/facets/MinterAccountStateFacet.sol";
import {AuthorizationFacet} from "common/facets/AuthorizationFacet.sol";
import {CommonConfigurationFacet} from "common/facets/CommonConfigurationFacet.sol";
import {AssetConfigurationFacet} from "common/facets/AssetConfigurationFacet.sol";
import {CommonStateFacet} from "common/facets/CommonStateFacet.sol";
import {SafetyCouncilFacet} from "common/facets/SafetyCouncilFacet.sol";
import {AssetStateFacet} from "common/facets/AssetStateFacet.sol";
import {MinterStateFacet} from "minter/facets/MinterStateFacet.sol";
import {MinterLiquidationFacet} from "minter/facets/MinterLiquidationFacet.sol";
import {MinterConfigurationFacet} from "minter/facets/MinterConfigurationFacet.sol";

import {SCDPStateFacet} from "scdp/facets/SCDPStateFacet.sol";
import {SCDPFacet} from "scdp/facets/SCDPFacet.sol";
import {SCDPSwapFacet} from "scdp/facets/SCDPSwapFacet.sol";
import {SCDPConfigFacet} from "scdp/facets/SCDPConfigFacet.sol";
import {SDIFacet} from "scdp/facets/SDIFacet.sol";
import {SCDPInitArgs} from "scdp/STypes.sol";
import {IKresko} from "periphery/IKresko.sol";
import {KISS} from "kiss/KISS.sol";
import {Vault} from "vault/Vault.sol";
import {DiamondDeployer} from "scripts/utils/DiamondDeployer.sol";

abstract contract KreskoForgeBase is
    IKreskoForgeTypes,
    RedstoneScript("./utils/getRedstonePayload.js"),
    FacetScript("./utils/getFunctionSelectors.sh")
{
    uint256 internal constant FACET_COUNT = 22;
    uint256 internal constant INITIALIZER_COUNT = 3;
    address internal constant TEST_ADMIN = address(0xABABAB);
    address public constant TEST_TREASURY = address(0xFEE);

    CoreConfig internal deployCfg;
    IKresko internal kresko;
    KISS internal kiss;
    Vault internal vkiss;

    address[] internal councilUsers;

    modifier requiresKresko() {
        require(address(kresko) != address(0), "KreskoForgeBase: Deploy Kresko first");
        _;
    }

    function deployDiamond(CoreConfig memory _cfg) internal returns (IKresko kresko_) {
        FacetCut[] memory facets = new FacetCut[](FACET_COUNT);
        Initializer[] memory initializers = new Initializer[](FACET_COUNT);
        /* --------------------------------- Diamond -------------------------------- */
        diamondFacets(facets);
        /* --------------------------------- Common --------------------------------- */
        initializers[0] = commonFacets(_cfg, facets);
        /* --------------------------------- Minter --------------------------------- */
        initializers[1] = minterFacets(_cfg, facets);
        /* ---------------------------------- SCDP ---------------------------------- */
        initializers[2] = scdpFacets(_cfg, facets);
        (kresko_ = IKresko(address(new Diamond(_cfg.admin, facets, initializers))));
        __current_kresko = address(kresko_); // @note mandatory
    }

    function getCommonInitArgs(CoreConfig memory _cfg) internal pure returns (CommonInitArgs memory init_) {
        init_.admin = _cfg.admin;
        init_.council = _cfg.council;
        init_.treasury = _cfg.treasury;
        init_.minDebtValue = 10e8;
        init_.maxPriceDeviationPct = 0.05e4;
        init_.oracleDecimals = _cfg.oraclePrecision;
        init_.sequencerUptimeFeed = _cfg.seqFeed;
        init_.sequencerGracePeriodTime = 3600;
        init_.staleTime = _cfg.staleTime;
        init_.phase = 3;
    }

    function getMinterInitArgs(CoreConfig memory _cfg) internal pure returns (MinterInitArgs memory init_) {
        init_.minCollateralRatio = _cfg.minterMcr;
        init_.liquidationThreshold = _cfg.minterLt;
    }

    function getSCDPInitArgs(CoreConfig memory _cfg) internal pure returns (SCDPInitArgs memory init_) {
        init_.minCollateralRatio = _cfg.scdpMcr;
        init_.liquidationThreshold = _cfg.scdpLt;
        init_.sdiPricePrecision = _cfg.sdiPrecision;
    }

    function diamondFacets(FacetCut[] memory _facets) internal returns (Initializer memory) {
        _facets[0] = FacetCut({
            facetAddress: address(new DiamondCutFacet()),
            action: FacetCutAction.Add,
            functionSelectors: getSelectorsFromArtifact("DiamondCutFacet")
        });
        _facets[1] = FacetCut({
            facetAddress: address(new DiamondStateFacet()),
            action: FacetCutAction.Add,
            functionSelectors: getSelectorsFromArtifact("DiamondStateFacet")
        });
        _facets[2] = FacetCut({
            facetAddress: address(new DiamondLoupeFacet()),
            action: FacetCutAction.Add,
            functionSelectors: getSelectorsFromArtifact("DiamondLoupeFacet")
        });
        _facets[3] = FacetCut({
            facetAddress: address(new ERC165Facet()),
            action: FacetCutAction.Add,
            functionSelectors: getSelectorsFromArtifact("ERC165Facet")
        });

        return Initializer({initContract: address(0), initData: ""});
    }

    function commonFacets(CoreConfig memory _cfg, FacetCut[] memory _facets) internal returns (Initializer memory) {
        address configurationFacetAddress = address(new CommonConfigurationFacet());
        _facets[4] = FacetCut({
            facetAddress: configurationFacetAddress,
            action: FacetCutAction.Add,
            functionSelectors: getSelectorsFromArtifact("CommonConfigurationFacet")
        });
        _facets[5] = FacetCut({
            facetAddress: address(new AuthorizationFacet()),
            action: FacetCutAction.Add,
            functionSelectors: getSelectorsFromArtifact("AuthorizationFacet")
        });
        _facets[6] = FacetCut({
            facetAddress: address(new CommonStateFacet()),
            action: FacetCutAction.Add,
            functionSelectors: getSelectorsFromArtifact("CommonStateFacet")
        });
        _facets[7] = FacetCut({
            facetAddress: address(new AssetConfigurationFacet()),
            action: FacetCutAction.Add,
            functionSelectors: getSelectorsFromArtifact("AssetConfigurationFacet")
        });
        _facets[8] = FacetCut({
            facetAddress: address(new AssetStateFacet()),
            action: FacetCutAction.Add,
            functionSelectors: getSelectorsFromArtifact("AssetStateFacet")
        });
        _facets[9] = FacetCut({
            facetAddress: address(new SafetyCouncilFacet()),
            action: FacetCutAction.Add,
            functionSelectors: getSelectorsFromArtifact("SafetyCouncilFacet")
        });

        return
            Initializer(
                configurationFacetAddress,
                abi.encodeWithSelector(CommonConfigurationFacet.initializeCommon.selector, getCommonInitArgs(_cfg))
            );
    }

    function minterFacets(CoreConfig memory _cfg, FacetCut[] memory _facets) internal returns (Initializer memory) {
        address configurationFacetAddress = address(new MinterConfigurationFacet());
        _facets[10] = FacetCut({
            facetAddress: configurationFacetAddress,
            action: FacetCutAction.Add,
            functionSelectors: getSelectorsFromArtifact("MinterConfigurationFacet")
        });
        _facets[11] = FacetCut({
            facetAddress: address(new MinterMintFacet()),
            action: FacetCutAction.Add,
            functionSelectors: getSelectorsFromArtifact("MinterMintFacet")
        });
        _facets[12] = FacetCut({
            facetAddress: address(new MinterBurnFacet()),
            action: FacetCutAction.Add,
            functionSelectors: getSelectorsFromArtifact("MinterBurnFacet")
        });
        _facets[13] = FacetCut({
            facetAddress: address(new MinterStateFacet()),
            action: FacetCutAction.Add,
            functionSelectors: getSelectorsFromArtifact("MinterStateFacet")
        });
        _facets[14] = FacetCut({
            facetAddress: address(new MinterDepositWithdrawFacet()),
            action: FacetCutAction.Add,
            functionSelectors: getSelectorsFromArtifact("MinterDepositWithdrawFacet")
        });
        _facets[15] = FacetCut({
            facetAddress: address(new MinterAccountStateFacet()),
            action: FacetCutAction.Add,
            functionSelectors: getSelectorsFromArtifact("MinterAccountStateFacet")
        });
        _facets[16] = FacetCut({
            facetAddress: address(new MinterLiquidationFacet()),
            action: FacetCutAction.Add,
            functionSelectors: getSelectorsFromArtifact("MinterLiquidationFacet")
        });

        return
            Initializer(
                configurationFacetAddress,
                abi.encodeWithSelector(MinterConfigurationFacet.initializeMinter.selector, getMinterInitArgs(_cfg))
            );
    }

    function scdpFacets(CoreConfig memory _cfg, FacetCut[] memory _facets) internal returns (Initializer memory) {
        address configurationFacetAddress = address(new SCDPConfigFacet());

        _facets[17] = FacetCut({
            facetAddress: address(new SCDPFacet()),
            action: FacetCutAction.Add,
            functionSelectors: getSelectorsFromArtifact("SCDPFacet")
        });
        _facets[18] = FacetCut({
            facetAddress: address(new SCDPStateFacet()),
            action: FacetCutAction.Add,
            functionSelectors: getSelectorsFromArtifact("SCDPStateFacet")
        });
        _facets[19] = FacetCut({
            facetAddress: configurationFacetAddress,
            action: FacetCutAction.Add,
            functionSelectors: getSelectorsFromArtifact("SCDPConfigFacet")
        });
        _facets[20] = FacetCut({
            facetAddress: address(new SCDPSwapFacet()),
            action: FacetCutAction.Add,
            functionSelectors: getSelectorsFromArtifact("SCDPSwapFacet")
        });
        _facets[21] = FacetCut({
            facetAddress: address(new SDIFacet()),
            action: FacetCutAction.Add,
            functionSelectors: getSelectorsFromArtifact("SDIFacet")
        });
        return
            Initializer(
                configurationFacetAddress,
                abi.encodeWithSelector(SCDPConfigFacet.initializeSCDP.selector, getSCDPInitArgs(_cfg))
            );
    }

    function deployDiamondOneTx(CoreConfig memory _cfg) internal returns (IKresko kresko_) {
        string[] memory cmd = new string[](2);
        cmd[0] = "./utils/getBytecodes.sh";
        cmd[1] = "./src/contracts/core/**/facets/*Facet.sol";

        (bytes[] memory creationCodes, bytes4[][] memory selectors) = abi.decode(vm.ffi(cmd), (bytes[], bytes4[][]));
        (uint256[] memory initializers, bytes[] memory calldatas) = getInitializers(selectors, _cfg);
        __current_kresko = address(new DiamondDeployer().create(_cfg.admin, creationCodes, selectors, initializers, calldatas));
        kresko_ = IKresko(__current_kresko);
    }

    function getInitializers(
        bytes4[][] memory selectors,
        CoreConfig memory _cfg
    ) internal pure returns (uint256[] memory initializers, bytes[] memory datas) {
        initializers = new uint256[](INITIALIZER_COUNT);
        datas = new bytes[](INITIALIZER_COUNT);
        bytes4[3] memory initSelectors = [
            CommonConfigurationFacet.initializeCommon.selector,
            MinterConfigurationFacet.initializeMinter.selector,
            SCDPConfigFacet.initializeSCDP.selector
        ];
        bytes[3] memory initDatas = [
            abi.encodeWithSelector(initSelectors[0], getCommonInitArgs(_cfg)),
            abi.encodeWithSelector(initSelectors[1], getMinterInitArgs(_cfg)),
            abi.encodeWithSelector(initSelectors[2], getSCDPInitArgs(_cfg))
        ];

        for (uint256 i; i < selectors.length; i++) {
            for (uint256 j; j < selectors[i].length; j++) {
                for (uint256 k; k < initSelectors.length; k++) {
                    if (selectors[i][j] == initSelectors[k]) {
                        initializers[k] = i;
                        datas[k] = initDatas[k];
                    }
                }
            }
        }
        require(initializers[INITIALIZER_COUNT - 1] != 0, "KreskoForgeBase: No initializers");
    }
}

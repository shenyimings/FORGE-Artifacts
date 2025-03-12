// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

// import "forge-std/Test.sol";
import "../lib/forge-std/src/Test.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../contracts/Controller.sol";
import "../contracts/adapters/CurveAdapter.sol";
import "../interfaces/pools/IConicPool.sol";
import "../interfaces/access/IGovernanceProxy.sol";
import "../contracts/ConicEthPool.sol";
import "../contracts/CurveHandler.sol";
import "../contracts/CurveRegistryCache.sol";
import "../contracts/ConicPool.sol";
import "../contracts/RewardManager.sol";
import "../contracts/ConvexHandler.sol";
import "../contracts/CurveRegistryCache.sol";
import "../contracts/tokenomics/InflationManager.sol";
import "../contracts/tokenomics/CNCLockerV2.sol";
import "../contracts/tokenomics/CNCToken.sol";
import "../contracts/tokenomics/LpTokenStaker.sol";
import "../contracts/tokenomics/CNCMintingRebalancingRewardsHandler.sol";
import "../contracts/oracles/GenericOracle.sol";
import "../contracts/oracles/CurveLPOracle.sol";
import "../contracts/oracles/ChainlinkOracle.sol";
import "../contracts/oracles/CrvUsdOracle.sol";
import "../contracts/testing/MockErc20.sol";
import "../interfaces/pools/IConicPool.sol";

library CurvePools {
    address internal constant TRI_POOL = 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7;
    address internal constant STETH_ETH_POOL = 0xDC24316b9AE028F1497c275EB9192a3Ea0f67022;
    address internal constant FRXETH_ETH_POOL = 0xa1F8A6807c402E4A15ef4EBa36528A3FED24E577;
    address internal constant CBETH_ETH_POOL = 0x5FAE7E604FC3e24fd43A72867ceBaC94c65b404A;
    address internal constant RETH_ETH_POOL = 0x0f3159811670c117c372428D4E69AC32325e4D0F;
    address internal constant FRAX_3CRV = 0xd632f22692FaC7611d2AA1C0D552930D43CAEd3B;
    address internal constant REN_BTC = 0x93054188d876f558f4a66B2EF1d97d16eDf0895B;
    address internal constant BBTC = 0x071c661B4DeefB59E2a3DdB20Db036821eeE8F4b;
    address internal constant MIM_3CRV = 0x5a6A4D54456819380173272A5E8E9B9904BdF41B;
    address internal constant CNC_ETH = 0x838af967537350D2C44ABB8c010E49E32673ab94;
    address internal constant FRAX_BP = 0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2;
    address internal constant GUSD_FRAX_BP = 0x4e43151b78b5fbb16298C1161fcbF7531d5F8D93;
    address internal constant EURT_3CRV = 0x9838eCcC42659FA8AA7daF2aD134b53984c9427b;
    address internal constant BUSD_FRAX_BP = 0x8fdb0bB9365a46B145Db80D0B1C5C5e979C84190;
    address internal constant SUSD_DAI_USDT_USDC = 0xA5407eAE9Ba41422680e2e00537571bcC53efBfD;
    address internal constant CRVUSD_USDT = 0x390f3595bCa2Df7d23783dFd126427CCeb997BF4;
    address internal constant CRVUSD_USDC = 0x4DEcE678ceceb27446b35C672dC7d61F30bAD69E;
    address internal constant CRVUSD_USDP = 0xCa978A0528116DDA3cbA9ACD3e68bc6191CA53D0;
    address internal constant CRVUSD_TUSD = 0x34D655069F4cAc1547E4C8cA284FfFF5ad4A8db0;
    address internal constant CRVUSD_FRAX = 0x0CD6f267b2086bea681E922E19D40512511BE538;
    address internal constant FRAX_USDP = 0xaE34574AC03A15cd58A92DC79De7B1A0800F1CE3;
}

library Tokens {
    address internal constant ETH = address(0);
    address internal constant WBTC = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    address internal constant DAI = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address internal constant TRI_CRV = address(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
    address internal constant WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address internal constant USDT = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    address internal constant CRV = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address internal constant USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address internal constant ST_ETH = address(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    address internal constant CVX = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address internal constant SETH = address(0x5e74C9036fb86BD7eCdcb084a0673EFc32eA31cb);
    address internal constant TRI_POOL_LP = address(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
    address internal constant STETH_ETH_LP = address(0x06325440D014e39736583c165C2963BA99fAf14E);
    address internal constant MIM_3CRV_LP = address(0x5a6A4D54456819380173272A5E8E9B9904BdF41B);
    address internal constant BBTC_LP = address(0x410e3E86ef427e30B9235497143881f717d93c2A);
    address internal constant MIM_UST_LP = address(0x55A8a39bc9694714E2874c1ce77aa1E599461E18);
    address internal constant FRAX_3CRV_LP = address(0xd632f22692FaC7611d2AA1C0D552930D43CAEd3B);
    address internal constant CNC = address(0x9aE380F0272E2162340a5bB646c354271c0F5cFC);
    address internal constant EURT_3CRV_LP = address(0x3b6831c0077a1e44ED0a21841C3bC4dC11bCE833);
    address internal constant FRAX = address(0x853d955aCEf822Db058eb8505911ED77F175b99e);
    address internal constant CRV_USD = address(0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E);
    address internal constant CBETH_ETH_LP = address(0x5b6C539b224014A09B3388e51CaAA8e354c959C8);
    address internal constant RETH_ETH_LP = address(0x6c38cE8984a890F5e46e6dF6117C26b3F1EcfC9C);
    address internal constant CBETH = address(0xBe9895146f7AF43049ca1c1AE358B0541Ea49704);
    address internal constant RETH = address(0xae78736Cd615f374D3085123A210448E74Fc6393);
    address internal constant CRVUSD = address(0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E);
}

library ConvexPid {
    uint256 internal constant TRI_POOL = 9;
    uint256 internal constant MIM_UST = 52;
    uint256 internal constant CVXCRV = 41;
    uint256 internal constant STETH_ETH_POOL = 25;
    uint256 internal constant FRAX_3CRV = 32;
    uint256 internal constant BBTC = 19;
    uint256 internal constant MIM_3CRV = 40;
    uint256 internal constant EURT_3CRV = 55;
}

library MainnetAddresses {
    address internal constant LP_TOKEN_STAKER = 0xeC037423A61B634BFc490dcc215236349999ca3d;
    address internal constant CNC = 0x9aE380F0272E2162340a5bB646c354271c0F5cFC;
    address internal constant MULTISIG = 0xB27DC5f8286f063F11491c8f349053cB37718bea;
    address internal constant CNC_MINTING_REWARDS_HANDLER =
        0x017F5f86dF6aA8D5B3c01E47E410D66f356A94A6;
    address internal constant EMERGENCY_MINTER = 0xd12843bB5f174c8B01b7Fc09DB7D40d4102ABaf6;
    address internal constant GOVERNANCE_PROXY = 0xCb7c67bDde9F7aF0667E8d82bb87F1432Bd1d902;
    address internal constant INFLATION_MANAGER = 0xf4A364d6B513158dC880d0e8DA6Ae65B9688FD7B;
    address internal constant CONTROLLER = 0x013A3Da6591d3427F164862793ab4e388F9B587e;
    address internal constant CNC_DISTRIBUTOR = 0x74eA6D777a4aEC782EBA0AcAE61142AAc69D3E2F;
    address internal constant CURVE_TRICRYPTO_FACTORY_HANDLER =
        0x9335BF643C455478F8BE40fA20B5164b90215B80;
    address internal constant CURVE_TRICRYPTO_FACTORY_HANDLER_2 =
        0x30a4249C42be05215b6063691949710592859697;
    address internal constant CONVEX_BOOSTER = 0xF403C135812408BFbE8713b5A23a04b3D48AAE31;
}

contract ConicTest is Test {
    using stdJson for string;
    using stdStorage for StdStorage;

    CNCToken public _cnc;

    bytes32 constant LOCKER_V2_MERKLE_ROOT =
        0x1fb27a93b1597fb63a71400761fa335d34875bc82ed5d1e2182cbb0a966049a7;

    address public bb8 = makeAddr("bb8"); // 0xE2Fca394F3a28F1717EFAB57339540306F303f6f
    address public r2 = makeAddr("r2"); // 0x2A71967CF1d84B413bb804418b54407822914D80
    address public c3po = makeAddr("c3po"); // 0x6763367385beC272a5BA2C1Fb3e7FCd36485e4FD

    uint256 internal mainnetFork;

    bool internal _isFork;

    function setUp() public virtual {
        string memory MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
        mainnetFork = vm.createFork(MAINNET_RPC_URL, 17_478_718);
    }

    function _setFork(uint256 forkId) internal {
        _isFork = true;
        vm.selectFork(forkId);
        vm.mockCall(
            MainnetAddresses.CURVE_TRICRYPTO_FACTORY_HANDLER,
            abi.encodeWithSignature("is_registered(address)"),
            abi.encode(false)
        );
        vm.mockCall(
            MainnetAddresses.CURVE_TRICRYPTO_FACTORY_HANDLER_2,
            abi.encodeWithSignature("is_registered(address)"),
            abi.encode(false)
        );
    }

    function _getCNCToken() internal returns (CNCToken) {
        if (_isFork) {
            return CNCToken(MainnetAddresses.CNC);
        }
        if (address(_cnc) == address(0)) {
            _cnc = new CNCToken();
        }
        return _cnc;
    }

    function _createRegistryCache() internal returns (ICurveRegistryCache) {
        ICurveRegistryCache registryCache = new CurveRegistryCache();
        if (_isFork) {
            registryCache.initPool(CurvePools.STETH_ETH_POOL);
            registryCache.initPool(CurvePools.FRAX_3CRV);
            registryCache.initPool(CurvePools.TRI_POOL);
            registryCache.initPool(CurvePools.REN_BTC);
            registryCache.initPool(CurvePools.MIM_3CRV);
            registryCache.initPool(CurvePools.FRAX_BP);
            registryCache.initPool(CurvePools.EURT_3CRV);
            registryCache.initPool(CurvePools.BUSD_FRAX_BP);
            registryCache.initPool(CurvePools.SUSD_DAI_USDT_USDC);
            registryCache.initPool(CurvePools.CNC_ETH);
            registryCache.initPool(CurvePools.RETH_ETH_POOL);
            registryCache.initPool(CurvePools.CBETH_ETH_POOL);
            registryCache.initPool(CurvePools.CRVUSD_USDT);
            registryCache.initPool(CurvePools.CRVUSD_USDC);
            registryCache.initPool(CurvePools.CRVUSD_USDP);
            registryCache.initPool(CurvePools.CRVUSD_TUSD);
            registryCache.initPool(CurvePools.CRVUSD_FRAX);
            registryCache.initPool(CurvePools.FRAX_USDP);
        }
        return registryCache;
    }

    function _createController(
        CNCToken cnc,
        ICurveRegistryCache registryCache
    ) internal returns (Controller) {
        Controller controller = new Controller(address(cnc), address(registryCache));
        return controller;
    }

    function _createAndInitializeController() internal returns (Controller) {
        CNCToken cnc = _getCNCToken();
        Controller controller = _createController(cnc, _createRegistryCache());
        controller.setCurveHandler(address(new CurveHandler(address(controller))));
        controller.setConvexHandler(address(new ConvexHandler(address(controller))));
        InflationManager inflationManager = _createInflationManager(controller);
        _createLpTokenStaker(inflationManager, cnc);
        CurveLPOracle curveLpOracle = _createCurveLpOracle(controller);
        GenericOracle genericOracle = _createGenericOracle(address(curveLpOracle));
        controller.setPriceOracle(address(genericOracle));
        controller.setDefaultPoolAdapter(address(_createCurveAdapter(controller)));

        // Adding crvUSD Custom oracle
        CrvUsdOracle crvUsdOracle = new CrvUsdOracle(address(genericOracle));
        genericOracle.setCustomOracle(Tokens.CRV_USD, address(crvUsdOracle));

        return controller;
    }

    function _createCurveLpOracle(Controller controller) internal returns (CurveLPOracle) {
        return new CurveLPOracle(address(controller));
    }

    function _createCurveAdapter(Controller controller) internal returns (IPoolAdapter) {
        return new CurveAdapter(controller);
    }

    function _createInflationManager(Controller controller) internal returns (InflationManager) {
        InflationManager inflationManager = new InflationManager(address(controller));
        controller.setInflationManager(address(inflationManager));
        return inflationManager;
    }

    function _createRebalancingRewardsHandler(
        Controller controller
    ) internal returns (CNCMintingRebalancingRewardsHandler) {
        CNCToken cnc = CNCToken(controller.cncToken());
        CNCMintingRebalancingRewardsHandler rebalancingRewardsHandler = new CNCMintingRebalancingRewardsHandler(
                controller,
                cnc,
                ICNCMintingRebalancingRewardsHandler(address(0))
            );

        if (_isFork) {
            vm.prank(MainnetAddresses.LP_TOKEN_STAKER);
        }
        cnc.addMinter(address(rebalancingRewardsHandler));
        controller.setAllowedMultipleDepositsWithdraws(address(rebalancingRewardsHandler), true);
        return rebalancingRewardsHandler;
    }

    function _createLpTokenStaker(
        InflationManager inflationManager,
        CNCToken cnc
    ) internal returns (LpTokenStaker) {
        IController controller = inflationManager.controller();
        LpTokenStaker lpTokenStaker = new LpTokenStaker(address(controller), cnc);
        if (_isFork) {
            vm.prank(MainnetAddresses.LP_TOKEN_STAKER);
        }
        cnc.addMinter(address(lpTokenStaker));
        controller.initialize(address(lpTokenStaker));
        return lpTokenStaker;
    }

    function _createLockerV2(Controller controller) internal returns (CNCLockerV2) {
        address crv = Tokens.CRV;
        address cvx = Tokens.CVX;
        if (!_isFork) {
            crv = address(new MockErc20(18));
            cvx = address(new MockErc20(18));
        }
        CNCLockerV2 locker = new CNCLockerV2(
            address(controller),
            controller.cncToken(),
            MainnetAddresses.MULTISIG,
            crv,
            cvx,
            LOCKER_V2_MERKLE_ROOT
        );
        return locker;
    }

    function _createGenericOracle(address curveLPOracle) internal returns (GenericOracle) {
        GenericOracle genericOracle = new GenericOracle();
        IOracle chainlinkOracle = new ChainlinkOracle();
        genericOracle.initialize(curveLPOracle, address(chainlinkOracle));
        return genericOracle;
    }

    function _createConicPool(
        Controller controller,
        CNCMintingRebalancingRewardsHandler rebalancingRewardsHandler,
        CNCLockerV2 locker,
        address underlying,
        string memory name,
        string memory symbol,
        bool isETH
    ) internal returns (IConicPool) {
        RewardManager rewardManager = new RewardManager(
            address(controller),
            underlying,
            address(locker)
        );
        IConicPool pool;
        if (isETH) {
            pool = new ConicEthPool(
                underlying,
                rewardManager,
                address(controller),
                name,
                symbol,
                Tokens.CVX,
                Tokens.CRV
            );
            payable(address(pool)).transfer(1 ether);
        } else {
            pool = new ConicPool(
                underlying,
                rewardManager,
                address(controller),
                name,
                symbol,
                Tokens.CVX,
                Tokens.CRV
            );
        }
        rewardManager.initialize(address(pool));
        controller.addPool(address(pool));
        controller.inflationManager().addPoolRebalancingRewardHandler(
            address(pool),
            address(rebalancingRewardsHandler)
        );
        controller.inflationManager().updatePoolWeights();
        return pool;
    }

    function setTokenBalance(address who, address token, uint256 amt) internal {
        bytes4 sel = IERC20(token).balanceOf.selector;
        stdstore.target(token).sig(sel).with_key(who).checked_write(amt);
    }

    function assertContains(address[] memory a, address b) internal {
        for (uint256 i; i < a.length; i++) {
            if (a[i] == b) {
                return;
            }
        }
        emit log("Error: a does not contain b [address[]]");
        emit log_named_array("      Left", a);
        emit log_named_address("     Right", b);
        fail();
    }

    function assertNotContains(address[] memory a, address b) internal {
        for (uint256 i; i < a.length; i++) {
            if (a[i] == b) {
                emit log("Error: a contains b [address[]]");
                emit log_named_array("      Left", a);
                emit log_named_address("     Right", b);
                fail();
            }
        }
    }
}

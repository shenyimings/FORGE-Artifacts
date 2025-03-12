// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../DataLoader.s.sol";
import "../AddressFetcher.s.sol";
import "../../contracts/yield/module/StargateYieldModule.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract StargateDeployer is DataLoader, AddressFetcher {
    StargateYieldModule public stargateYieldModuleImpl;
    StargateYieldModule public stargateYieldModule;

    function setStargateYieldModuleImpl() internal {
        stargateYieldModuleImpl = StargateYieldModule(payable(stargateModuleImplAddress));
    }

    function setStargateYieldModule() internal {
        stargateYieldModule = StargateYieldModule(payable(stargateModuleAddress));
    }

    function deployStargateYieldModuleImpl() internal virtual {
        stargateYieldModuleImpl = new StargateYieldModule();
    }

    function deployStargateYieldModule(address smartFarmooor, address dex) internal virtual {
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(stargateYieldModuleImpl),
            ""
        );
        stargateYieldModule = StargateYieldModule(payable(proxy));

        address[] memory rewards = new address[](1);
        rewards[0] = STG;
        StargateYieldModule.StargateParams memory params = StargateYieldModule
        .StargateParams(
            STARGATE_LP_STAKING,
            STARGATE_ROUTER,
            STARGATE_POOL,
            STARGATE_ROUTER_POOL_ID,
            STARGATE_REDEEM_FROM_CHAIN_ID,
            STARGATE_LP_STAKING_POOL_ID,
            STARGATE_LP_PROFIT_WITHDRAWL_THRESHOLD_IN_BASE_TOKEN
        );
        stargateYieldModule.initialize(
            smartFarmooor,
            MANAGER,
            BASE_TOKEN,
            STARGATE_EXECUTION_FEE,
            dex,
            rewards,
            params,
            STARGATE_YIELD_MODULE_NAME,
            WRAPPED_NATIVE_TOKEN
        );
    }

    function transferOwnershipStargateYieldModule(address transferTo) internal {
        stargateYieldModule.transferOwnership(transferTo);
    }

    function verifyStargateYieldModule(address owner, address smartFarmooor, address dex) internal {
        assertEq(
            address(stargateYieldModule) !=
            0x0000000000000000000000000000000000000000,
            true
        );
        assertEq(
            stargateYieldModule.getImplementation(),
            address(stargateYieldModuleImpl)
        );
        assertEq(stargateYieldModule.owner(), owner);
        assertEq(stargateYieldModule.manager(), MANAGER);
        assertEq(stargateYieldModule.smartFarmooor(), smartFarmooor);
        assertEq(stargateYieldModule.baseToken(), BASE_TOKEN);
        assertEq(stargateYieldModule.executionFee(), STARGATE_EXECUTION_FEE);
        assertEq(address(stargateYieldModule.dex()), dex);
        assertEq(stargateYieldModule.rewards(0), STG);
        assertEq(stargateYieldModule.name(), STARGATE_YIELD_MODULE_NAME);
        assertGt(
            IERC20(STG).allowance(address(stargateYieldModule), dex),
            type(uint256).max / 2
        );
        assertEq(
            address(stargateYieldModule.stargateRouter()),
            STARGATE_ROUTER
        );
        assertGt(
            IERC20(BASE_TOKEN).allowance(
                address(stargateYieldModule),
                STARGATE_ROUTER
            ),
            type(uint256).max / 2
        );
        assertEq(address(stargateYieldModule.lpStaking()), STARGATE_LP_STAKING);
        assertGt(
            IERC20(STARGATE_POOL).allowance(
                address(stargateYieldModule),
                STARGATE_LP_STAKING
            ),
            type(uint256).max / 2
        );
        assertEq(stargateYieldModule.pool(), STARGATE_POOL);
        assertEq(stargateYieldModule.routerPoolId(), STARGATE_ROUTER_POOL_ID);
        assertEq(
            stargateYieldModule.redeemFromChainId(),
            STARGATE_REDEEM_FROM_CHAIN_ID
        );
        assertEq(
            stargateYieldModule.lpStakingPoolId(),
            STARGATE_LP_STAKING_POOL_ID
        );
        assertEq(
            stargateYieldModule.lpProfitWithdrawalThreshold(),
            STARGATE_LP_PROFIT_WITHDRAWL_THRESHOLD_IN_BASE_TOKEN
        );
    }

    function printStargateStorage() internal view {
        console.log("\nStargate yield module storage");
        console.log("Implementation:     ", stargateYieldModule.getImplementation());
        console.log("Owner:              ", stargateYieldModule.owner());
        console.log("Manager:            ", stargateYieldModule.manager());
        console.log("Smart farmooor:     ", stargateYieldModule.smartFarmooor());
        console.log("Base token:         ", stargateYieldModule.baseToken());
        console.log("Execution fee:      ", stargateYieldModule.executionFee());
        console.log("Dex:                ", address(stargateYieldModule.dex()));
        console.log("Reward0:            ", stargateYieldModule.rewards(0));
        console.log("Name:               ", stargateYieldModule.name());
        console.log("Router:             ", stargateYieldModule.stargateRouter());
        console.log("LP staking:         ", stargateYieldModule.lpStaking());
        console.log("Pool:               ", stargateYieldModule.pool());
        console.log("Router pool id :    ", stargateYieldModule.routerPoolId());
        console.log("LP staking pool id: ", stargateYieldModule.lpStakingPoolId());
        console.log("Redeem chain id:    ", stargateYieldModule.redeemFromChainId());
        console.log("LP withdrawal thld: ", stargateYieldModule.lpProfitWithdrawalThreshold());
    }
}

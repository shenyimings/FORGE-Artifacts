// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../DataLoader.s.sol";
import "../AddressFetcher.s.sol";
import "../../contracts/yield/module/AaveYieldModule.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract AaveDeployer is DataLoader, AddressFetcher {
    AaveYieldModule public aaveYieldModuleImpl;
    AaveYieldModule public aaveYieldModule;

    function setAaveYieldModuleImpl() internal {
        aaveYieldModuleImpl = AaveYieldModule(payable(aaveModuleImplAddress));
    }

    function setAaveYieldModule() internal {
        aaveYieldModule = AaveYieldModule(payable(aaveModuleAddress));
    }

    function deployAaveYieldModuleImpl() internal {
        aaveYieldModuleImpl = new AaveYieldModule();
    }

    function deployAaveYieldModule(address smartFarmooor, address dex) internal {
        ERC1967Proxy proxy = new ERC1967Proxy(address(aaveYieldModuleImpl), "");
        aaveYieldModule = AaveYieldModule(payable(proxy));

        address[] memory rewards = new address[](1);
        rewards[0] = WAVAX;
        AaveYieldModule.AaveParams memory params = AaveYieldModule
        .AaveParams(
            AAVE_POOL,
            AAVE_POOL_DATA_PROVIDER,
            AAVE_REWARDS_CONTROLLER,
            AAVE_A_TOKEN
        );
        aaveYieldModule.initialize(
            smartFarmooor,
            MANAGER,
            BASE_TOKEN,
            AAVE_EXECUTION_FEE,
            dex,
            rewards,
            params,
            AAVE_YIELD_MODULE_NAME,
            WRAPPED_NATIVE_TOKEN
        );
    }

    function transferOwnershipAaveYieldModule(address transferTo) internal {
        aaveYieldModule.transferOwnership(transferTo);
    }

    function verifyAaveYieldModule(address owner, address smartFarmooor, address dex) internal {
        assertEq(
            address(aaveYieldModule) !=
            0x0000000000000000000000000000000000000000,
            true
        );
        assertEq(
            aaveYieldModule.getImplementation(),
            address(aaveYieldModuleImpl)
        );
        assertEq(aaveYieldModule.owner(), owner);
        assertEq(aaveYieldModule.manager(), MANAGER);
        assertEq(aaveYieldModule.smartFarmooor(), smartFarmooor);
        assertEq(aaveYieldModule.baseToken(), BASE_TOKEN);
        assertEq(aaveYieldModule.executionFee(), AAVE_EXECUTION_FEE);
        assertEq(address(aaveYieldModule.dex()), dex);
        assertEq(aaveYieldModule.rewards(0), WAVAX);
        assertEq(aaveYieldModule.name(), AAVE_YIELD_MODULE_NAME);
        assertGt(
            IERC20(WAVAX).allowance(address(aaveYieldModule), dex),
            type(uint256).max / 2
        );
        assertEq(address(aaveYieldModule.pool()), AAVE_POOL);
        assertGt(
            IERC20(BASE_TOKEN).allowance(address(aaveYieldModule), AAVE_POOL),
            type(uint256).max / 2
        );
        assertEq(aaveYieldModule.poolDataProvider(), AAVE_POOL_DATA_PROVIDER);
        assertEq(aaveYieldModule.rewardsController(), AAVE_REWARDS_CONTROLLER);
        assertEq(aaveYieldModule.aToken(), AAVE_A_TOKEN);
    }

    function printAaveStorage() internal view {
        console.log("\nAave yield module storage");
        console.log("Implementation:     ", aaveYieldModule.getImplementation());
        console.log("Owner:              ", aaveYieldModule.owner());
        console.log("Manager:            ", aaveYieldModule.manager());
        console.log("Smart farmooor:     ", aaveYieldModule.smartFarmooor());
        console.log("Base token:         ", aaveYieldModule.baseToken());
        console.log("Execution fee:      ", aaveYieldModule.executionFee());
        console.log("Dex:                ", address(aaveYieldModule.dex()));
        console.log("Reward0:            ", aaveYieldModule.rewards(0));
        console.log("Name:               ", aaveYieldModule.name());
        console.log("Pool:               ", address(aaveYieldModule.pool()));
        console.log("Pool data provider: ", aaveYieldModule.poolDataProvider());
        console.log("Reward controller:  ", aaveYieldModule.rewardsController());
        console.log("AToken:             ", aaveYieldModule.aToken());
    }
}

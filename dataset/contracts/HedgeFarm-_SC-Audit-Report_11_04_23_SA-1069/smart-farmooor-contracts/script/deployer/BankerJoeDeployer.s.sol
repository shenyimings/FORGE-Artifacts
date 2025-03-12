// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../DataLoader.s.sol";
import "../AddressFetcher.s.sol";
import "../../contracts/yield/module/CompoundV2Module.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract BankerJoeDeployer is DataLoader, AddressFetcher {
    CompoundV2Module public bankerJoeYieldModuleImpl;
    CompoundV2Module public bankerJoeYieldModule;

    function setBankerJoeYieldModuleImpl() internal {
        bankerJoeYieldModuleImpl = CompoundV2Module(payable(bankerJoeModuleImplAddress));
    }

    function setBankerJoeYieldModule() internal {
        bankerJoeYieldModule = CompoundV2Module(payable(bankerJoeModuleAddress));
    }

    function deployBankerJoeYieldModuleImpl() internal {
        bankerJoeYieldModuleImpl = new CompoundV2Module();
    }

    function deployBankerJoeYieldModule(address smartFarmooor, address dex) internal {
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(bankerJoeYieldModuleImpl),
            ""
        );
        bankerJoeYieldModule = CompoundV2Module(payable(proxy));

        address[] memory rewards = new address[](2);
        rewards[0] = JOE;
        rewards[1] = WAVAX;
        bankerJoeYieldModule.initialize(
            smartFarmooor,
            MANAGER,
            BASE_TOKEN,
            BANKER_JOE_EXECUTION_FEE,
            dex,
            rewards,
            BANKER_JOE_COMPTROLLER,
            BANKER_JOE_TOKEN,
            BANKERJOE_YIELD_MODULE_NAME,
            WRAPPED_NATIVE_TOKEN
        );
    }

    function transferOwnershipBankerJoeYieldModule(address transferTo) internal {
        bankerJoeYieldModule.transferOwnership(transferTo);
    }

    function verifyBankerJoeYieldModule(address owner, address smartFarmooor, address dex) internal {
        assertEq(
            address(bankerJoeYieldModule) !=
            0x0000000000000000000000000000000000000000,
            true
        );
        assertEq(
            bankerJoeYieldModule.getImplementation(),
            address(bankerJoeYieldModuleImpl)
        );
        assertEq(bankerJoeYieldModule.owner(), owner);
        assertEq(bankerJoeYieldModule.manager(), MANAGER);
        assertEq(bankerJoeYieldModule.smartFarmooor(), smartFarmooor);
        assertEq(bankerJoeYieldModule.baseToken(), BASE_TOKEN);
        assertEq(bankerJoeYieldModule.executionFee(), BANKER_JOE_EXECUTION_FEE);
        assertEq(address(bankerJoeYieldModule.dex()), dex);
        assertEq(bankerJoeYieldModule.rewards(0), JOE);
        assertGt(
            IERC20(JOE).allowance(address(bankerJoeYieldModule), dex),
            type(uint256).max / 2
        );
        assertEq(bankerJoeYieldModule.rewards(1), WAVAX);
        assertGt(
            IERC20(WAVAX).allowance(
                address(bankerJoeYieldModule),
                address(dex)
            ),
            type(uint256).max / 2
        );
        assertEq(bankerJoeYieldModule.name(), BANKERJOE_YIELD_MODULE_NAME);
        assertEq(
            address(bankerJoeYieldModule.comptroller()),
            BANKER_JOE_COMPTROLLER
        );
        assertEq(bankerJoeYieldModule.cToken(), BANKER_JOE_TOKEN);
        assertTrue(
            ComptrollerInterface(bankerJoeYieldModule.comptroller())
            .checkMembership(
                address(bankerJoeYieldModule),
                CTokenInterface(bankerJoeYieldModule.cToken())
            )
        );
        assertGt(
            IERC20(BASE_TOKEN).allowance(
                address(bankerJoeYieldModule),
                BANKER_JOE_TOKEN
            ),
            type(uint256).max / 2
        );
    }

    function printBankerJoeStorage() internal view {
        console.log("\nBanker Joe yield module storage");
        console.log("Implementation:     ", bankerJoeYieldModule.getImplementation());
        console.log("Owner:              ", bankerJoeYieldModule.owner());
        console.log("Manager:            ", bankerJoeYieldModule.manager());
        console.log("Smart farmooor:     ", bankerJoeYieldModule.smartFarmooor());
        console.log("Base token:         ", bankerJoeYieldModule.baseToken());
        console.log("Execution fee:      ", bankerJoeYieldModule.executionFee());
        console.log("Dex:                ", address(bankerJoeYieldModule.dex()));
        console.log("Reward0:            ", bankerJoeYieldModule.rewards(0));
        console.log("Reward1:            ", bankerJoeYieldModule.rewards(1));
        console.log("Name:               ", bankerJoeYieldModule.name());
        console.log("Comptroller:        ", address(bankerJoeYieldModule.comptroller()));
        console.log("CToken:             ", bankerJoeYieldModule.cToken());
    }
}

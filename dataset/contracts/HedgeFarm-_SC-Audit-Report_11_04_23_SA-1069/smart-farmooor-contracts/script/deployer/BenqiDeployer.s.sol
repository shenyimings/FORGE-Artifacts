// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../DataLoader.s.sol";
import "../AddressFetcher.s.sol";
import "../../contracts/yield/module/CompoundV2Module.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract BenqiDeployer is DataLoader, AddressFetcher {
    CompoundV2Module public benqiYieldModuleImpl;
    CompoundV2Module public benqiYieldModule;

    function setBenqiYieldModuleImpl() internal {
        benqiYieldModuleImpl = CompoundV2Module(payable(benqiModuleImplAddress));
    }

    function setBenqiYieldModule() internal {
        benqiYieldModule = CompoundV2Module(payable(benqiModuleAddress));
    }

    function deployBenqiYieldModuleImpl() internal {
        benqiYieldModuleImpl = new CompoundV2Module();
    }

    function deployBenqiYieldModule(address smartFarmooor, address dex) internal {
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(benqiYieldModuleImpl),
            ""
        );
        benqiYieldModule = CompoundV2Module(payable(proxy));

        address[] memory rewards = new address[](2);
        rewards[0] = QI;
        rewards[1] = WAVAX;
        benqiYieldModule.initialize(
            smartFarmooor,
            MANAGER,
            BASE_TOKEN,
            BENQI_EXECUTION_FEE,
            dex,
            rewards,
            BENQI_COMPTROLLER,
            BENQI_TOKEN,
            BENQI_YIELD_MODULE_NAME,
            WRAPPED_NATIVE_TOKEN);
    }

    function transferOwnershipBenqiYieldModule(address transferTo) internal {
        benqiYieldModule.transferOwnership(transferTo);
    }

    function verifyBenqiYieldModule(address owner, address smartFarmooor, address dex) internal {
        assertEq(
            address(benqiYieldModule) !=
            0x0000000000000000000000000000000000000000,
            true
        );
        assertEq(
            benqiYieldModule.getImplementation(),
            address(benqiYieldModuleImpl)
        );
        assertEq(benqiYieldModule.owner(), owner);
        assertEq(benqiYieldModule.manager(), MANAGER);
        assertEq(benqiYieldModule.smartFarmooor(), smartFarmooor);
        assertEq(benqiYieldModule.baseToken(), BASE_TOKEN);
        assertEq(benqiYieldModule.executionFee(), BENQI_EXECUTION_FEE);
        assertEq(address(benqiYieldModule.dex()), dex, "benqiYieldModule.dex() != dex");
        assertEq(benqiYieldModule.rewards(0), QI);
        assertEq(benqiYieldModule.name(), BENQI_YIELD_MODULE_NAME);
        // Max approval for QI token is type(uint96).max
        assertGt(
            IERC20(QI).allowance(address(benqiYieldModule), dex),
            type(uint96).max / 2
        );
        assertEq(benqiYieldModule.rewards(1), WAVAX);
        assertGt(
            IERC20(WAVAX).allowance(address(benqiYieldModule), dex),
            type(uint256).max / 2
        );
        assertEq(address(benqiYieldModule.comptroller()), BENQI_COMPTROLLER);
        assertEq(benqiYieldModule.cToken(), BENQI_TOKEN);
        assertTrue(
            ComptrollerInterface(benqiYieldModule.comptroller())
            .checkMembership(
                address(benqiYieldModule),
                CTokenInterface(benqiYieldModule.cToken())
            )
        );
        assertGt(
            IERC20(BASE_TOKEN).allowance(address(benqiYieldModule), BENQI_TOKEN),
            type(uint256).max / 2
        );
    }

    function printBenqiStorage() internal view {
        console.log("\nBenqi yield module storage");
        console.log("Implementation:     ", benqiYieldModule.getImplementation());
        console.log("Owner:              ", benqiYieldModule.owner());
        console.log("Manager:            ", benqiYieldModule.manager());
        console.log("Smart farmooor:     ", benqiYieldModule.smartFarmooor());
        console.log("Base token:         ", benqiYieldModule.baseToken());
        console.log("Execution fee:      ", benqiYieldModule.executionFee());
        console.log("Dex:                ", address(benqiYieldModule.dex()));
        console.log("Reward0:            ", benqiYieldModule.rewards(0));
        console.log("Reward1:            ", benqiYieldModule.rewards(1));
        console.log("Name:               ", benqiYieldModule.name());
        console.log("Comptroller:        ", address(benqiYieldModule.comptroller()));
        console.log("CToken:             ", benqiYieldModule.cToken());
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SmartFarmooorBasicTestHelperAvax.t.sol";

contract SmartFarmooorModulesTestAvax is SmartFarmooorBasicTestHelperAvax {
    using SafeERC20 for IERC20;

    function testShouldAddModulesWhenPaused() public {
        (IYieldModule newModule,) = smartFarmooor.yieldOptions(0);
        vm.startPrank(address(timelock));
        vm.expectRevert(bytes("Pausable: not paused"));
        smartFarmooor.addModule(newModule);

        uint initialNumberOfModule = smartFarmooor.numberOfModules();

        smartFarmooor.pause();
        smartFarmooor.addModule(newModule);

        assertEq(smartFarmooor.numberOfModules(), initialNumberOfModule + 1);
        vm.stopPrank();
    }

    function testShouldAddModulesWhenEmptyModules() public {
        (IYieldModule newModule,) = smartFarmooor.yieldOptions(0);

        depositHelper(ALICE, DEPOSIT_AMOUNT);
        vm.startPrank(address(timelock));
        vm.expectRevert(bytes("SmartFarmooor: module not empty"));
        smartFarmooor.addModule(newModule);

        uint initialNumberOfModule = smartFarmooor.numberOfModules();

        smartFarmooor.panic();
        smartFarmooor.addModule(newModule);
        assertEq(smartFarmooor.numberOfModules(), initialNumberOfModule + 1);

        vm.stopPrank();
    }

    function testShouldSetModuleAllocation() public {
        uint[] memory allocations = new uint[](smartFarmooor.numberOfModules());
        for (uint256 i = 0; i < smartFarmooor.numberOfModules(); i++) {
            (, uint allocation) = smartFarmooor.yieldOptions(i);
            allocations[i] = allocation;
        }

        allocations[0] = allocations[0] - 100;
        allocations[1] = allocations[1] + 100;
        vm.startPrank(address(timelock));
        smartFarmooor.pause();
        smartFarmooor.setModuleAllocation(allocations);
        smartFarmooor.unpause();
        vm.stopPrank();

        (, uint allocationModule1) = smartFarmooor.yieldOptions(0);
        (, uint allocationModule2) = smartFarmooor.yieldOptions(1);

        assertEq(allocationModule1, allocations[0]);
        assertEq(allocationModule2, allocations[1]);
    }

    function testShouldOnlySetCorrectAllocationSize() public {
        //add extra module
        testShouldAddModulesWhenEmptyModules();
        uint[] memory allocations = new uint[](smartFarmooor.numberOfModules() - 1);

        //array too small
        vm.prank(address(timelock));
        vm.expectRevert(bytes("SmartFarmooor: Allocation list size issue"));
        smartFarmooor.setModuleAllocation(allocations);

        //array too big
        allocations = new uint[](smartFarmooor.numberOfModules() + 1);
        vm.prank(address(timelock));
        vm.expectRevert(bytes("SmartFarmooor: Allocation list size issue"));
        smartFarmooor.setModuleAllocation(allocations);

        //correct size
        uint numberOfModules = smartFarmooor.numberOfModules();
        allocations = new uint[](numberOfModules);
        for (uint256 i = 0; i < numberOfModules; i++) {
            allocations[i] = smartFarmooor.MAX_BPS() / numberOfModules;
        }

        if (numberOfModules == 3)
            allocations[numberOfModules - 1]++;

        vm.prank(address(timelock));
        smartFarmooor.setModuleAllocation(allocations);

        for (uint256 i = 0; i < smartFarmooor.numberOfModules(); i++) {
            (, uint allocation) = smartFarmooor.yieldOptions(i);
            assertEq(allocation, allocations[i]);
        }
    }

    function testShouldOnlySetAllocationWhenEmpty() public {
        //add a second module so that we can compare old vs new allocation
        //and make sure we can set when empty
        testShouldDepositAccordingToAllocation();

        vm.startPrank(address(timelock));
        smartFarmooor.pause();
        uint[] memory allocations = new uint[](smartFarmooor.numberOfModules());
        for (uint256 i = 0; i < smartFarmooor.numberOfModules(); i++) {
            (, uint allocation) = smartFarmooor.yieldOptions(i);
            allocations[i] = allocation;
        }

        vm.expectRevert(bytes("SmartFarmooor: module not empty"));
        smartFarmooor.setModuleAllocation(allocations);

        //unpause for panic
        smartFarmooor.unpause();

        smartFarmooor.panic();
        smartFarmooor.setModuleAllocation(allocations);

        for (uint256 i = 0; i < smartFarmooor.numberOfModules(); i++) {
            (, uint allocation) = smartFarmooor.yieldOptions(i);
            assertEq(allocation, allocations[i]);
        }

        vm.stopPrank();
    }

    function testShouldDepositAccordingToAllocation() public {
        testShouldSetModuleAllocation();
        vm.prank(address(timelock));

        depositHelper(ALICE, DEPOSIT_AMOUNT);

        for (uint256 i = 0; i < smartFarmooor.numberOfModules(); i++) {
            (IYieldModule module, uint allocation) = smartFarmooor.yieldOptions(i);
            assertApproxEqAbs(module.getBalance(), DEPOSIT_AMOUNT * allocation / smartFarmooor.MAX_BPS(), smartFarmooor.numberOfModules() * PRECISION);
        }
    }

    function testShouldRemoveModuleThatExists() public {
        uint initialNumberOfModule = smartFarmooor.numberOfModules();

        vm.startPrank(address(timelock));
        smartFarmooor.pause();

        vm.expectRevert(bytes("SmartFarmooor : module does not exist"));
        smartFarmooor.removeModule(initialNumberOfModule);

        smartFarmooor.removeModule(initialNumberOfModule - 1);
        assertEq(smartFarmooor.numberOfModules(), initialNumberOfModule - 1);
        vm.stopPrank();
    }

    function testOnlyManagerShouldRemove() public {
        uint initialNumberOfModule = smartFarmooor.numberOfModules();

        vm.prank(ALICE);
        //with ALICE == 0xef211076b8d8b46797e09c9a374fb4cdc1df0916 and MAANGER ROLE = 0x241ecf16d79d0f8dbfb92cbc07fe17840425976cf0667f022fe9877caa831b08
        vm.expectRevert(bytes('AccessControl: account 0xef211076b8d8b46797e09c9a374fb4cdc1df0916 is missing role 0x241ecf16d79d0f8dbfb92cbc07fe17840425976cf0667f022fe9877caa831b08'));
        smartFarmooor.removeModule(0);

        assertEq(smartFarmooor.hasRole(smartFarmooor.MANAGER_ROLE(), address(timelock)), true);
        vm.startPrank(address(timelock));
        smartFarmooor.pause();

        smartFarmooor.removeModule(initialNumberOfModule - 1);
        assertEq(smartFarmooor.numberOfModules(), initialNumberOfModule - 1);
        vm.stopPrank();
    }

    function testShouldRemoveOnlyWhenPaused() public {
        uint initialNumberOfModule = smartFarmooor.numberOfModules();

        vm.startPrank(address(timelock));
        vm.expectRevert(bytes("Pausable: not paused"));
        smartFarmooor.removeModule(0);

        smartFarmooor.pause();

        smartFarmooor.removeModule(0);
        assertEq(smartFarmooor.numberOfModules(), initialNumberOfModule - 1);
        (IYieldModule first,) = smartFarmooor.yieldOptions(initialNumberOfModule - 1);
        assertEq(address(first), address(0));
        vm.stopPrank();
    }

    function testShouldRemoveOnlyWhenEmpty() public {
        uint initialNumberOfModule = smartFarmooor.numberOfModules();

        depositHelper(ALICE, DEPOSIT_AMOUNT);

        vm.startPrank(address(timelock));
        smartFarmooor.pause();
        vm.expectRevert(bytes("SmartFarmooor: module not empty"));
        smartFarmooor.removeModule(0);

        smartFarmooor.unpause();
        smartFarmooor.panic();
        smartFarmooor.removeModule(0);

        assertEq(smartFarmooor.numberOfModules(), initialNumberOfModule - 1);
    }

    function testShouldDeleteOldDataWhenRemoved() public {
        vm.startPrank(address(timelock));
        smartFarmooor.pause();

        // Remove all module
        uint initialNumberOfModule = smartFarmooor.numberOfModules();
        for (uint256 i = 0; i < initialNumberOfModule; i++) {
            smartFarmooor.removeModule(initialNumberOfModule - 1 - i);
        }
        assertEq(smartFarmooor.numberOfModules(), 0);

        for (uint256 i = 0; i < initialNumberOfModule; i++) {
            (IYieldModule module, uint allocation) = smartFarmooor.yieldOptions(i);
            assertEq(address(module), address(0));
            assertEq(allocation, 0);
        }

        vm.stopPrank();
    }

    function testShouldRemoveMiddleModule() public {
        vm.startPrank(address(timelock));
        smartFarmooor.pause();

        // Remove all module expect one
        uint initialNumberOfModule = smartFarmooor.numberOfModules();
        for (uint256 i = 0; i < initialNumberOfModule - 1; i++) {
            smartFarmooor.removeModule(initialNumberOfModule - 1 - i);
        }

        //add benqi again : 1 benqi, 2 benqi
        smartFarmooor.addModule(_deployExtraBenqiModule());
        CompoundV2Module thirdBenqiModule = _deployExtraBenqiModule();
        smartFarmooor.addModule(thirdBenqiModule);

        uint[] memory allocations = new uint[](smartFarmooor.numberOfModules());

        allocations[0] = uint(smartFarmooor.MAX_BPS() / 2);
        allocations[1] = uint(smartFarmooor.MAX_BPS() / 4);
        allocations[2] = uint(smartFarmooor.MAX_BPS() / 4);

        smartFarmooor.setModuleAllocation(allocations);

        smartFarmooor.unpause();
        vm.stopPrank();

        depositHelper(ALICE, DEPOSIT_AMOUNT);

        vm.startPrank(address(timelock));
        _moveBlock(10000);
        smartFarmooor.harvest();

        assertEq(smartFarmooor.numberOfModules(), 3);

        _moveBlock(1);

        smartFarmooor.panic();
        smartFarmooor.removeModule(1);

        (IYieldModule second,) = smartFarmooor.yieldOptions(1);
        (IYieldModule third,) = smartFarmooor.yieldOptions(2);

        //third is no second since we removed middle module
        assertEq(address(second), address(thirdBenqiModule));
        assertEq(address(third), address(0));

        allocations = new uint[](smartFarmooor.numberOfModules());
        allocations[0] = uint(smartFarmooor.MAX_BPS() / 2);
        allocations[1] = uint(smartFarmooor.MAX_BPS() / 2);

        smartFarmooor.setModuleAllocation(allocations);
        smartFarmooor.finishPanic();

        vm.stopPrank();

        assertEq(smartFarmooor.numberOfModules(), 2);
    }

    function testTotalAllocationShouldAlwaysBeMaxBps() public {
        testShouldAddModulesWhenEmptyModules();

        vm.startPrank(address(timelock));
        uint numberOfModules = smartFarmooor.numberOfModules();

        uint[] memory allocations = new uint[](numberOfModules);
        for (uint256 i = 0; i < numberOfModules; i++) {
            allocations[i] = smartFarmooor.MAX_BPS() * 2 / numberOfModules;
        }

        vm.expectRevert(bytes("SmartFarmooor: total allocation is wrong"));
        smartFarmooor.setModuleAllocation(allocations);

        numberOfModules = smartFarmooor.numberOfModules();
        allocations = new uint[](numberOfModules);
        for (uint256 i = 0; i < numberOfModules; i++) {
            allocations[i] = smartFarmooor.MAX_BPS() / numberOfModules;
        }

        if (numberOfModules == 3)
            allocations[numberOfModules - 1]++;

        smartFarmooor.setModuleAllocation(allocations);

        for (uint256 i = 0; i < numberOfModules; i++) {
            (, uint allocation) = smartFarmooor.yieldOptions(i);
            if (numberOfModules == 3 && i == 2)
                assertEq(allocation, (smartFarmooor.MAX_BPS() / numberOfModules) + 1);
            else
                assertEq(allocation, smartFarmooor.MAX_BPS() / numberOfModules);
        }

        vm.stopPrank();
    }

    function testModuleMinAllocationShouldBe10Percent() public {
        //add benqi again : 1 benqi, 2 benqi
        assertEq(smartFarmooor.hasRole(smartFarmooor.MANAGER_ROLE(), address(timelock)), true);
        vm.startPrank(address(timelock));
        smartFarmooor.pause();

        uint numberOfModules = smartFarmooor.numberOfModules();
        uint[] memory allocations = new uint[](numberOfModules);
        for (uint256 i = 0; i < numberOfModules; i++) {
            (, uint allocation) = smartFarmooor.yieldOptions(i);
            allocations[i] = 80;
        }

        vm.expectRevert("SmartFarmooor: Min allocation too low");
        smartFarmooor.setModuleAllocation(allocations);


        //get down to 2 modules active
        uint i = numberOfModules - 1;
        if (numberOfModules > 2) {
            while (smartFarmooor.numberOfModules() != 2) {
                smartFarmooor.removeModule(i);
                i--;
            }
        }

        allocations = new uint[](smartFarmooor.numberOfModules());
        allocations[0] = 100;
        allocations[1] = smartFarmooor.MAX_BPS() - allocations[0];


        smartFarmooor.setModuleAllocation(allocations);

        (, uint allocationModule1) = smartFarmooor.yieldOptions(0);
        (, uint allocationModule2) = smartFarmooor.yieldOptions(1);


        assertEq(allocationModule1, 100);
        assertEq(allocationModule2, smartFarmooor.MAX_BPS() - allocations[0]);

        vm.stopPrank();
    }

    function _deployExtraBenqiModule() internal returns (CompoundV2Module) {
        address[] memory rewards = new address[](2);
        rewards[0] = QI;
        rewards[1] = WAVAX;
        CompoundV2Module benqiYieldModuleImpl = new CompoundV2Module();
        ERC1967Proxy proxy = new ERC1967Proxy(address(benqiYieldModuleImpl), "");
        CompoundV2Module benqiYieldModule2 = CompoundV2Module(payable(proxy));
        benqiYieldModule2.initialize(
            address(smartFarmooor),
            MANAGER,
            BASE_TOKEN,
            BENQI_EXECUTION_FEE,
            address(dex),
            rewards,
            BENQI_COMPTROLLER,
            BENQI_TOKEN,
            BENQI_YIELD_MODULE_NAME,
            WRAPPED_NATIVE_TOKEN
        );
        return benqiYieldModule2;
    }
}

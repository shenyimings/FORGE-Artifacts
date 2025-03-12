// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../../../script/Deployer.s.sol";
import "../../../helper/TestHelper.sol";

contract BaseModuleBaseTest is Deployer, TestHelper {
    // NOTE: because the contract BaseModule is abstract we test it with the contract BenqiYieldModule

    BaseModule public baseModule;
    address[] rewards = [QI, BTCB];

    function setUp() public {
        loadTestData();

        smartFarmooor = SmartFarmooor(payable(address(0x100)));
        dex = TraderJoeDexModule(address(0x101));

        deployBenqiYieldModuleImpl();
        deployBenqiYieldModule(address(smartFarmooor), address(dex));

        transferOwnershipBenqiYieldModule(OWNER);

        baseModule = benqiYieldModule;
    }

    function testInitIsCorrect() public {
        verifyBenqiYieldModule(OWNER, address(smartFarmooor), address(dex));
    }

    /** helper **/

    function _verifyAllowance() internal {
        assertEq(IERC20(baseModule.rewards(0)).allowance(address(baseModule), address(dex)), type(uint96).max);
        assertEq(IERC20(baseModule.rewards(1)).allowance(address(baseModule), address(dex)), type(uint256).max);
    }

    function _transferOwnershipToTimelock() internal {
        deployTimelock();
        vm.startPrank(OWNER);
        transferOwnershipBenqiYieldModule(address(timelock));
        vm.stopPrank();
    }
}

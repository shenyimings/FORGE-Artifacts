// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../DataLoader.s.sol";
import "../AddressFetcher.s.sol";
import "../../contracts/yield/interface/ISmartFarmooor.sol";
import "../../contracts/yield/interface/IYieldModule.sol";
import "../../contracts/yield/SmartFarmooor.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract SmartFarmooorDeployer is DataLoader, AddressFetcher {
    SmartFarmooor public smartFarmooorImpl;
    SmartFarmooor public smartFarmooor;
    uint256[] moduleAllocations;

    function setSmartFarmooorImpl() internal {
        smartFarmooorImpl = SmartFarmooor(payable(smartFarmooorImplAddress));
    }

    function setSmartFarmooor() internal {
        smartFarmooor = SmartFarmooor(payable(smartFarmooorAddress));
    }

    function deploySmartFarmooorImpl() internal {
        smartFarmooorImpl = new SmartFarmooor();
    }

    function deploySmartFarmooor(address timelock, address[] memory privateAccessAccounts) internal {
        ERC1967Proxy proxy = new ERC1967Proxy(address(smartFarmooorImpl), "");
        smartFarmooor = SmartFarmooor(payable(proxy));
        smartFarmooor.initialize(
            SM_NAME,
            SM_SYMBOL,
            SM_FEE_MANAGER,
            BASE_TOKEN,
            SM_MIN_HARVEST_THRESHOLD_IN_BASE_TOKEN,
            SM_PERFORMANCE_FEE,
            SM_CAP,
            MANAGER,
            timelock,
            SM_MIN_AMOUNT,
            privateAccessAccounts
        );
        smartFarmooor.pause();
    }

    function verifySmartFarmooor(address timelock) internal {
        assertEq(
            address(smartFarmooor) != 0x0000000000000000000000000000000000000000,
            true
        );
        assertEq(smartFarmooor.getImplementation(), address(smartFarmooorImpl));

        //ADMIN role granted to owner == timelock + can Panic
        assertEq(smartFarmooor.hasRole(smartFarmooor.DEFAULT_ADMIN_ROLE(), timelock), true);
        assertEq(smartFarmooor.hasRole(smartFarmooor.MANAGER_ROLE(), timelock), true);
        assertEq(smartFarmooor.hasRole(smartFarmooor.PANICOOOR_ROLE(), timelock), true);

        //MANAGER ROLE granted to Manager + can Panic
        assertEq(smartFarmooor.hasRole(smartFarmooor.MANAGER_ROLE(), MANAGER), true);
        assertEq(smartFarmooor.hasRole(smartFarmooor.PANICOOOR_ROLE(), MANAGER), true);

        //No roles for deployer
        assertEq(smartFarmooor.hasRole(smartFarmooor.MANAGER_ROLE(), DEPLOYER), false);
        assertEq(smartFarmooor.hasRole(smartFarmooor.DEFAULT_ADMIN_ROLE(), DEPLOYER), false);
        assertEq(smartFarmooor.hasRole(smartFarmooor.PANICOOOR_ROLE(), DEPLOYER), false);

        assertEq(smartFarmooor.name(), SM_NAME);
        assertEq(smartFarmooor.symbol(), SM_SYMBOL);
        assertEq(smartFarmooor.feeManager(), SM_FEE_MANAGER, "smartFarmooor.feeManager() != SM_FEE_MANAGER");
        assertEq(smartFarmooor.baseToken(), BASE_TOKEN);
        assertEq(
            smartFarmooor.minHarvestThreshold(),
            SM_MIN_HARVEST_THRESHOLD_IN_BASE_TOKEN
        );
        assertEq(smartFarmooor.performanceFee(), SM_PERFORMANCE_FEE);
        assertEq(smartFarmooor.cap(), SM_CAP);
        assertEq(smartFarmooor.minAmount(), SM_MIN_AMOUNT);

        //If private deployment then private accounts must be declared
        if(smartFarmooor.isPrivateAccess()) {
            assertGt(smartFarmooor.getRoleMemberCount(smartFarmooor.PRIVATE_ACCESS_ROLE()), 0);
        } else {
            assertEq(smartFarmooor.getRoleMemberCount(smartFarmooor.PRIVATE_ACCESS_ROLE()), 0);
        }

        assertEq(smartFarmooor.hasRole(smartFarmooor.DEFAULT_ADMIN_ROLE(), timelock), true, "timelock missing DEFAULT_ADMIN_ROLE");
        assertEq(smartFarmooor.hasRole(smartFarmooor.MANAGER_ROLE(), timelock), true, "timelock missing MANAGER_ROLE");
        assertEq(smartFarmooor.hasRole(smartFarmooor.MANAGER_ROLE(), MANAGER), true, "manager missing MANAGER_ROLE");
        assertEq(smartFarmooor.hasRole(smartFarmooor.PANICOOOR_ROLE(), timelock), true, "timelock missing PANICOOOR_ROLE");
        assertEq(smartFarmooor.hasRole(smartFarmooor.PANICOOOR_ROLE(), MANAGER), true, "manager missing PANICOOOR_ROLE");

        // TODO: verify allocation
    }

    function printSmartFarmooorStorage() internal view {
        console.log("\nSmart farmooor storage");
        console.log("Implementation:     ", smartFarmooor.getImplementation());
        console.log("Name:               ", smartFarmooor.name());
        console.log("Symbol:             ", smartFarmooor.symbol());
        console.log("Fee manager:        ", smartFarmooor.feeManager());
        console.log("Base token:         ", smartFarmooor.baseToken());
        console.log("Min harvest thld :  ", smartFarmooor.minHarvestThreshold());
        console.log("Performance fee:    ", smartFarmooor.performanceFee());
        console.log("Cap:                ", smartFarmooor.cap());
        console.log("Min amount:         ", smartFarmooor.minAmount());
    }

    /* add modules */

    function addStargateToSmartFarmooor(IYieldModule stargateModule) internal {
        smartFarmooor.addModule(stargateModule);
    }

    function addBenqiToSmartFarmooor(IYieldModule benqiModule) internal {
        smartFarmooor.addModule(benqiModule);
    }

    function addBankerJoeToSmartFarmooor(IYieldModule bankerJoeModule) internal {
        smartFarmooor.addModule(bankerJoeModule);
    }

    function addAaveToSmartFarmooor(IYieldModule aaveModule) internal {
        smartFarmooor.addModule(aaveModule);
    }

    /* add allocation */

    function setModuleAllocation() internal {
        if (STARGATE_ACTIVE) {
            moduleAllocations.push(STARGATE_ALLOCATION);
        }
        if (BENQI_ACTIVE) {
            moduleAllocations.push(BENQI_ALLOCATION);
        }
        if (BANKER_JOE_ACTIVE) {
            moduleAllocations.push(BANKER_JOE_ALLOCATION);
        }
        if (AAVE_ACTIVE) {
            moduleAllocations.push(AAVE_ALLOCATION);
        }

        smartFarmooor.setModuleAllocation(moduleAllocations);
    }

    /* renounce role */

    function renounceAllRoles(address user) internal {
        renounceAdminRole(user);
        renounceManagerRole(user);
        renounceManagerRole(user);
    }

    function renounceAdminRole(address isAdmin) internal {
        smartFarmooor.renounceRole(smartFarmooor.DEFAULT_ADMIN_ROLE(), isAdmin);
    }

    function renounceManagerRole(address isManager) internal {
        smartFarmooor.renounceRole(smartFarmooor.MANAGER_ROLE(), isManager);
    }

    function revokeManagerRole(address isManager) internal {
        smartFarmooor.revokeRole(smartFarmooor.MANAGER_ROLE(), isManager);
    }

    function revokePanicooorRole(address isPanicooor) internal {
        smartFarmooor.revokeRole(smartFarmooor.PANICOOOR_ROLE(), isPanicooor);
    }
}
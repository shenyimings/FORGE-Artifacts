// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "forge-std/Script.sol";
import { INayms, IDiamondCut } from "src/diamonds/nayms/INayms.sol";
import { Entity } from "src/diamonds/nayms/interfaces/FreeStructs.sol";
import { LibAdmin } from "src/diamonds/nayms/libs/LibAdmin.sol";
import { LibConstants } from "src/diamonds/nayms/libs/LibConstants.sol";
import { LibHelpers } from "src/diamonds/nayms/libs/LibHelpers.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";

contract CreateEntity is Script {
    MockERC20 public wbtc;

    function createAnEntity(address naymsDiamondAddress) public {
        INayms nayms = INayms(naymsDiamondAddress);

        wbtc = new MockERC20("Wrapped BTC", "WBTC", 18);

        Entity memory entity = Entity({
            assetId: LibHelpers._getIdForAddress(address(wbtc)),
            collateralRatio: LibConstants.BP_FACTOR,
            maxCapacity: 100 ether,
            utilizedCapacity: 0,
            simplePolicyEnabled: true
        });

        bytes32 eAlice = bytes32("0xaaaa1111");
        bytes32 aliceId = LibHelpers._getIdForAddress(address(msg.sender));
        bytes32 systemContext = LibAdmin._getSystemId();

        assert(nayms.isInGroup(aliceId, systemContext, LibConstants.GROUP_SYSTEM_ADMINS));

        vm.startPrank(msg.sender);

        nayms.addSupportedExternalToken(address(wbtc));
        nayms.createEntity(eAlice, aliceId, entity, "entity test hash");
    }
}

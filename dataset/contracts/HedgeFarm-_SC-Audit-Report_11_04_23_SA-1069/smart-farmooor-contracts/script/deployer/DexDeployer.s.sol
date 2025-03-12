// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../DataLoader.s.sol";
import "../../contracts/dex/TraderJoeDexModule.sol";

contract DexDeployer is DataLoader {
    TraderJoeDexModule public dex;

    function setDex() internal {
        dex = TraderJoeDexModule(payable(DEX));
    }

    function deployDex() internal {
        dex = new TraderJoeDexModule(TRADER_JOE_ROUTER, routes);
    }

    function transferOwnershipDex(address transferTo) internal {
        dex.transferOwnership(transferTo);
    }

    function verifyDex(address owner) internal {
        assertEq(
            address(dex) != 0x0000000000000000000000000000000000000000,
            true
        );
        assertEq(dex.owner(), owner);
        assertEq(address(dex.router()), TRADER_JOE_ROUTER);
        for (uint256 i = 0; i < routes.length; i++) {
            assertEq(
                dex.getRoute(routes[i][0], routes[i][routes[i].length - 1]),
                routes[i]
            );
            if (routes[i][0] == QI) {
                assertGt(
                    IERC20(routes[i][0]).allowance(
                        address(dex),
                        TRADER_JOE_ROUTER
                    ),
                    type(uint96).max / 2
                );
                continue;
            }
            assertGt(
                IERC20(routes[i][0]).allowance(address(dex), TRADER_JOE_ROUTER),
                type(uint256).max / 2
            );
        }
    }

    function printDexStorage() internal view {
        console.log("\nDex storage");
        console.log("Owner:              ", dex.owner());
        console.log("Router:             ", address(dex.router()));
        // TODO: if needed, find a clean way to pretty print the paths
    }
}
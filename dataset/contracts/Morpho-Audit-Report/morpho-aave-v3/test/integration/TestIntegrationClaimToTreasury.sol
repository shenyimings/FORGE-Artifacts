// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import {Config, ConfigLib} from "config/ConfigLib.sol";
import {PoolLib} from "src/libraries/PoolLib.sol";

import {Math} from "@morpho-utils/math/Math.sol";
import {WadRayMath} from "@morpho-utils/math/WadRayMath.sol";

import {ERC20 as OZERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "test/helpers/IntegrationTest.sol";

contract TestIntegrationClaimToTreasury is IntegrationTest {
    using ConfigLib for Config;
    using PoolLib for IPool;
    using Math for uint256;
    using WadRayMath for uint256;

    function testClaimToTreasuryShouldRevertIfTreasuryVaultIsZero(uint256[] calldata amounts) public {
        vm.expectRevert(Errors.AddressIsZero.selector);
        morpho.claimToTreasury(allUnderlyings, amounts);
    }

    function testShouldNotClaimToTreasuryIfMarketNotCreated(address treasuryVault, uint8 nbUnderlyings) public {
        treasuryVault = _boundAddressValid(treasuryVault);
        vm.assume(treasuryVault != address(morpho));

        address[] memory claimedUnderlyings = new address[](nbUnderlyings);
        uint256[] memory amounts = new uint256[](nbUnderlyings);

        for (uint256 i; i < amounts.length; ++i) {
            OZERC20 marketNotCreated = new OZERC20(
                string.concat("MarketNotCreated", Strings.toString(i)), string.concat("ma3-", Strings.toString(i))
            );
            amounts[i] = 1 ether;
            claimedUnderlyings[i] = address(marketNotCreated);
            deal(address(marketNotCreated), address(morpho), amounts[i]);
        }

        morpho.setTreasuryVault(treasuryVault);
        morpho.claimToTreasury(claimedUnderlyings, amounts);

        for (uint256 i; i < claimedUnderlyings.length; ++i) {
            assertEq(
                amounts[i],
                ERC20(claimedUnderlyings[i]).balanceOf(address(morpho)),
                string.concat("Incorrect contract balance:", Strings.toString(i))
            );
        }
    }

    function testClaimToTreasuryShouldRevertIfNotOwner(uint256[] calldata amounts, address caller) public {
        vm.assume(caller != address(this));
        vm.prank(caller);

        vm.expectRevert();
        morpho.claimToTreasury(allUnderlyings, amounts);
    }

    function testClaimToTreasuryShouldPassIfZeroUnderlyings(
        uint256[] calldata claimedAmounts,
        uint256[] calldata balanceAmounts
    ) public {
        address[] memory claimedUnderlyings;
        uint256[] memory beforeBalanceTreasury = new uint256[](allUnderlyings.length);
        address treasuryVault = address(1);
        vm.assume(claimedAmounts.length >= allUnderlyings.length);
        vm.assume(balanceAmounts.length >= allUnderlyings.length);
        morpho.setTreasuryVault(treasuryVault);

        for (uint256 i = 0; i < allUnderlyings.length; ++i) {
            deal(allUnderlyings[i], address(morpho), balanceAmounts[i]);
            beforeBalanceTreasury[i] = ERC20(allUnderlyings[i]).balanceOf(treasuryVault);
        }
        morpho.claimToTreasury(claimedUnderlyings, claimedAmounts);

        for (uint256 i = 0; i < allUnderlyings.length; ++i) {
            assertEq(
                balanceAmounts[i], ERC20(allUnderlyings[i]).balanceOf(address(morpho)), "Incorrect contract balance"
            );
            assertEq(
                beforeBalanceTreasury[i],
                ERC20(allUnderlyings[i]).balanceOf(treasuryVault),
                "Incorrect treasury balance"
            );
        }
    }

    function testClaimToTreasuryShouldPassIfAmountsClaimedEqualZero(uint256[] calldata balanceAmounts) public {
        uint256[] memory claimedAmounts = new uint256[](balanceAmounts.length);
        address[] memory claimedUnderlyings = allUnderlyings;
        address treasuryVault = address(1);
        vm.assume(balanceAmounts.length >= claimedUnderlyings.length);

        for (uint256 i = 0; i < claimedUnderlyings.length; ++i) {
            deal(claimedUnderlyings[i], address(morpho), balanceAmounts[i]);
        }

        morpho.setTreasuryVault(treasuryVault);
        morpho.claimToTreasury(claimedUnderlyings, claimedAmounts);

        for (uint256 i = 0; i < claimedUnderlyings.length; ++i) {
            assertEq(
                balanceAmounts[i], ERC20(claimedUnderlyings[i]).balanceOf(address(morpho)), "Incorrect contract balance"
            );
        }
    }

    function testClaimToTreasury(
        uint256[] memory balanceAmounts,
        uint256[] memory idleAmounts,
        uint256[] memory claimedAmounts
    ) public {
        address treasuryVault = address(1);
        address[] memory claimedUnderlyings = allUnderlyings;
        uint256[] memory beforeBalanceTreasury = new uint256[](claimedUnderlyings.length);

        vm.assume(claimedAmounts.length >= claimedUnderlyings.length);
        vm.assume(balanceAmounts.length >= idleAmounts.length);
        vm.assume(idleAmounts.length >= claimedUnderlyings.length);
        vm.assume(treasuryVault != address(0));

        for (uint256 i = 0; i < claimedUnderlyings.length; ++i) {
            balanceAmounts[i] =
                bound(balanceAmounts[i], 0, type(uint256).max - ERC20(claimedUnderlyings[i]).balanceOf(treasuryVault));
            idleAmounts[i] = bound(idleAmounts[i], 0, balanceAmounts[i]);
            morpho.market(claimedUnderlyings[i]).idleSupply = idleAmounts[i];
            morpho.market(claimedUnderlyings[i]).aToken = address(1);
            deal(claimedUnderlyings[i], address(morpho), balanceAmounts[i]);
        }

        morpho.setTreasuryVault(treasuryVault);

        for (uint256 i = 0; i < claimedUnderlyings.length; ++i) {
            if (claimedAmounts[i] > 0 && balanceAmounts[i] - morpho.market(claimedUnderlyings[i]).idleSupply > 0) {
                vm.expectEmit(true, true, true, true);
                emit Events.ReserveFeeClaimed(
                    claimedUnderlyings[i],
                    Math.min(claimedAmounts[i], balanceAmounts[i] - morpho.market(claimedUnderlyings[i]).idleSupply)
                );
            }
            beforeBalanceTreasury[i] = ERC20(claimedUnderlyings[i]).balanceOf(treasuryVault);
        }

        morpho.claimToTreasury(claimedUnderlyings, claimedAmounts);

        for (uint256 i = 0; i < claimedUnderlyings.length; ++i) {
            assertEq(
                ERC20(claimedUnderlyings[i]).balanceOf(address(morpho))
                    - morpho.market(claimedUnderlyings[i]).idleSupply,
                (balanceAmounts[i] - morpho.market(claimedUnderlyings[i]).idleSupply).zeroFloorSub(claimedAmounts[i]),
                "Expected contract balance != Real contract balance"
            );
            assertEq(
                ERC20(claimedUnderlyings[i]).balanceOf(treasuryVault) - beforeBalanceTreasury[i],
                Math.min(claimedAmounts[i], balanceAmounts[i] - morpho.market(claimedUnderlyings[i]).idleSupply),
                "Expected treasury balance != Real treasury balance"
            );
        }
    }
}

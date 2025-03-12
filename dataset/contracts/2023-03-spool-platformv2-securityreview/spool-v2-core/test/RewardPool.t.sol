// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {console} from "forge-std/console.sol";
import "forge-std/Test.sol";
import "../src/rewards/RewardManager.sol";
import "../src/access/SpoolAccessControl.sol";
import "./mocks/MockToken.sol";

contract RewardPoolTest is Test {
    IRewardPool paymentPool;
    MockToken token;

    // Total rewards 5000000000000000000 per user
    bytes32 treeRoot = 0x77e3bb058cf4f611bb9c8a2f5e920ff8b745f893c484b030b2c83106d5290dbe;
    address alice = 0x1111111111111111111111111111111111111111;

    function setUp() public {
        SpoolAccessControl accessControl = new SpoolAccessControl();
        accessControl.initialize();
        accessControl.grantRole(ROLE_REWARD_POOL_ADMIN, address(this));

        paymentPool = new RewardPool(accessControl, true);
        token = new MockToken("A", "A");
        assertEq(address(token), 0xF62849F9A0B5Bf2913b396098F7c7019b51A820a);

        deal(address(token), address(paymentPool), 4_000_000 ether, true);
    }

    function test_addRoot() public {
        paymentPool.addTreeRoot(treeRoot);
    }

    function test_updateRoot_success() public {
        bytes32 newRoot = 0x77e3bb058cf4f611bb9c8a2f5e920ff8b745f893c484b030b2c83106d0090000;
        paymentPool.addTreeRoot(treeRoot);
        paymentPool.updateTreeRoot(newRoot, 1);

        assertEq(paymentPool.roots(1), newRoot);
    }

    function test_updateRoot_revertInvalidCycle() public {
        paymentPool.addTreeRoot(treeRoot);
        vm.expectRevert(abi.encodeWithSelector(InvalidCycle.selector));
        paymentPool.updateTreeRoot(treeRoot, 10);
    }

    function test_updateRoot_revertMissingRole() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MissingRole.selector, ROLE_REWARD_POOL_ADMIN, alice));
        paymentPool.updateTreeRoot(treeRoot, 10);
    }

    function test_addRoot_revertMissingRole() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MissingRole.selector, ROLE_REWARD_POOL_ADMIN, alice));
        paymentPool.addTreeRoot(treeRoot);
    }

    function test_verifyProof_success() public {
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = 0x860a1203a2121819132e9257ef9629d47704f0d1c0903f71aa4b5c24a666f203;
        proof[1] = 0xd094e3ae2f9fc0a3ec98bfb30953f724c817df729ec1838a3d5b5d025b00fe4b;

        ClaimRequest memory data = ClaimRequest({
            smartVault: 0x0000000000000000000000000000000000000001,
            token: address(token),
            cycle: 1,
            rewardsTotal: 5000000000000000000,
            proof: proof
        });
        paymentPool.addTreeRoot(treeRoot);
        assertTrue(paymentPool.verify(data, alice));
    }

    function test_verifyProof_invalidProof() public {
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = 0x860a1203a2121819132e9257ef9629d47704f0d1c0903f71aa4b5c24a666f203;
        proof[1] = 0x6f461936149f77581a706ebc460f8e893f40e4d08034cf60bce252663c5d8ebc;

        ClaimRequest memory data = ClaimRequest({
            smartVault: 0x0000000000000000000000000000000000000001,
            token: address(token),
            cycle: 1,
            rewardsTotal: 5000000000000000000,
            proof: proof
        });
        paymentPool.addTreeRoot(treeRoot);
        assertFalse(paymentPool.verify(data, alice));
    }

    function test_verifyProof_invalidToken() public {
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = 0x860a1203a2121819132e9257ef9629d47704f0d1c0903f71aa4b5c24a666f203;
        proof[1] = 0xd094e3ae2f9fc0a3ec98bfb30953f724c817df729ec1838a3d5b5d025b00fe4b;

        ClaimRequest memory data = ClaimRequest({
            smartVault: 0x0000000000000000000000000000000000000001,
            token: 0x0000000000000000000000000000000000000001,
            cycle: 1,
            rewardsTotal: 5000000000000000000,
            proof: proof
        });
        paymentPool.addTreeRoot(treeRoot);
        assertFalse(paymentPool.verify(data, alice));
    }

    function test_verifyProof_invalidUser() public {
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = 0x860a1203a2121819132e9257ef9629d47704f0d1c0903f71aa4b5c24a666f203;
        proof[1] = 0xd094e3ae2f9fc0a3ec98bfb30953f724c817df729ec1838a3d5b5d025b00fe4b;

        ClaimRequest memory data = ClaimRequest({
            smartVault: 0x0000000000000000000000000000000000000001,
            token: address(token),
            cycle: 1,
            rewardsTotal: 5000000000000000000,
            proof: proof
        });
        paymentPool.addTreeRoot(treeRoot);
        assertFalse(paymentPool.verify(data, 0x1111111111111111111111111111111111111112));
    }

    function test_verifyProof_invalidAmount() public {
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = 0x860a1203a2121819132e9257ef9629d47704f0d1c0903f71aa4b5c24a666f203;
        proof[1] = 0xd094e3ae2f9fc0a3ec98bfb30953f724c817df729ec1838a3d5b5d025b00fe4b;

        ClaimRequest memory data = ClaimRequest({
            smartVault: 0x0000000000000000000000000000000000000001,
            token: address(token),
            cycle: 1,
            rewardsTotal: 5000000000000000001,
            proof: proof
        });
        paymentPool.addTreeRoot(treeRoot);
        assertFalse(paymentPool.verify(data, alice));
    }

    function test_verifyProof_invalidCycle() public {
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = 0x860a1203a2121819132e9257ef9629d47704f0d1c0903f71aa4b5c24a666f203;
        proof[1] = 0xd094e3ae2f9fc0a3ec98bfb30953f724c817df729ec1838a3d5b5d025b00fe4b;

        ClaimRequest memory data = ClaimRequest({
            smartVault: 0x0000000000000000000000000000000000000001,
            token: address(token),
            cycle: 1,
            rewardsTotal: 5000000000000000001,
            proof: proof
        });
        paymentPool.addTreeRoot(treeRoot);
        assertFalse(paymentPool.verify(data, alice));
    }

    function test_claim_success() public {
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = 0x860a1203a2121819132e9257ef9629d47704f0d1c0903f71aa4b5c24a666f203;
        proof[1] = 0xd094e3ae2f9fc0a3ec98bfb30953f724c817df729ec1838a3d5b5d025b00fe4b;

        ClaimRequest memory data = ClaimRequest({
            smartVault: 0x0000000000000000000000000000000000000001,
            token: address(token),
            cycle: 1,
            rewardsTotal: 5000000000000000000,
            proof: proof
        });
        paymentPool.addTreeRoot(treeRoot);

        ClaimRequest[] memory payload = new ClaimRequest[](1);
        payload[0] = data;
        vm.prank(alice);
        paymentPool.claim(payload);

        assertEq(token.balanceOf(alice), 5000000000000000000);
    }

    function test_claim_twoCycles() public {
        bytes32[] memory proof1 = new bytes32[](2);
        proof1[0] = 0x860a1203a2121819132e9257ef9629d47704f0d1c0903f71aa4b5c24a666f203;
        proof1[1] = 0xd094e3ae2f9fc0a3ec98bfb30953f724c817df729ec1838a3d5b5d025b00fe4b;

        // Increase rewards for 10000000000000000
        bytes32 treeRoot2 = 0x5043114118595679b087c86b1d82a95ea78bd2cfed74e18366f5f6ca305883ef;

        bytes32[] memory proof2 = new bytes32[](2);
        proof2[0] = 0xe4ebad09aa885751ceca8f7a8881f21b4c79f93a881e3136ccc418c67af42a99;
        proof2[1] = 0x3c6e72f54c1ddb52449f7824836dafbcac33f105ac74fbfa7ca44a5137a510fa;

        paymentPool.addTreeRoot(treeRoot);
        paymentPool.addTreeRoot(treeRoot2);

        ClaimRequest memory data1 = ClaimRequest({
            smartVault: 0x0000000000000000000000000000000000000001,
            token: address(token),
            cycle: 1,
            rewardsTotal: 5000000000000000000,
            proof: proof1
        });

        ClaimRequest memory data2 = ClaimRequest({
            smartVault: 0x0000000000000000000000000000000000000001,
            token: address(token),
            cycle: 2,
            rewardsTotal: 5010000000000000000,
            proof: proof2
        });

        ClaimRequest[] memory payload = new ClaimRequest[](1);
        payload[0] = data1;

        vm.prank(alice);
        paymentPool.claim(payload);
        assertEq(token.balanceOf(alice), 5000000000000000000);
        assertEq(paymentPool.rewardsClaimed(alice, data1.smartVault, address(token)), 5000000000000000000);

        payload[0] = data2;
        vm.prank(alice);
        paymentPool.claim(payload);
        assertEq(token.balanceOf(alice), 5010000000000000000);
        assertEq(paymentPool.rewardsClaimed(alice, data1.smartVault, address(token)), 5010000000000000000);
    }

    function test_claim_revertAlreadyClaimed() public {
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = 0x860a1203a2121819132e9257ef9629d47704f0d1c0903f71aa4b5c24a666f203;
        proof[1] = 0xd094e3ae2f9fc0a3ec98bfb30953f724c817df729ec1838a3d5b5d025b00fe4b;

        ClaimRequest memory data = ClaimRequest({
            smartVault: 0x0000000000000000000000000000000000000001,
            token: address(token),
            cycle: 1,
            rewardsTotal: 5000000000000000000,
            proof: proof
        });
        paymentPool.addTreeRoot(treeRoot);

        ClaimRequest[] memory payload = new ClaimRequest[](1);
        payload[0] = data;

        vm.startPrank(alice);
        paymentPool.claim(payload);
        vm.expectRevert(abi.encodeWithSelector(ProofAlreadyClaimed.selector, 0));
        paymentPool.claim(payload);
        vm.stopPrank();
    }

    function test_claim_revertInvalidProof() public {
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = 0x860a1203a2121819132e9257ef9629d47704f0d1c0903f71aa4b5c24a666f203;
        proof[1] = 0x6f461936149f77581a706ebc460f8e893f40e4d08034cf60bce252663c5d8ebe;

        ClaimRequest memory data = ClaimRequest({
            smartVault: 0x0000000000000000000000000000000000000001,
            token: address(token),
            cycle: 1,
            rewardsTotal: 5000000000000000000,
            proof: proof
        });
        paymentPool.addTreeRoot(treeRoot);

        ClaimRequest[] memory payload = new ClaimRequest[](1);
        payload[0] = data;

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(InvalidProof.selector, 0));
        paymentPool.claim(payload);
        vm.stopPrank();
    }
}

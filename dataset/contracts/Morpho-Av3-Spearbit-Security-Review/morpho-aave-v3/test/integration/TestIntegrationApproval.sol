// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IMorpho} from "src/interfaces/IMorpho.sol";

import {Errors} from "src/libraries/Errors.sol";

import {Morpho} from "src/Morpho.sol";

import {SigUtils} from "test/helpers/SigUtils.sol";
import "test/helpers/IntegrationTest.sol";

contract TestIntegrationApproval is IntegrationTest {
    uint256 internal constant OWNER_PK = 0xA11CE;
    uint256 internal constant MANAGER_PK = 0xB0B;

    address internal immutable DELEGATOR = vm.addr(OWNER_PK);
    address internal immutable MANAGER = vm.addr(MANAGER_PK);

    SigUtils internal sigUtils;

    function setUp() public override {
        super.setUp();

        sigUtils = new SigUtils(morpho.DOMAIN_SEPARATOR());
    }

    function testApproveManager(address delegator, address manager, bool isAllowed) public {
        vm.assume(delegator != address(proxyAdmin)); // TransparentUpgradeableProxy: admin cannot fallback to proxy target

        vm.prank(delegator);
        morpho.approveManager(manager, isAllowed);
        assertEq(morpho.isManaging(delegator, manager), isAllowed);
    }

    function testApproveManagerWithSig(uint128 deadline) public {
        vm.assume(deadline > block.timestamp);

        SigUtils.Authorization memory authorization = SigUtils.Authorization({
            delegator: DELEGATOR,
            manager: MANAGER,
            isAllowed: true,
            nonce: morpho.userNonce(DELEGATOR),
            deadline: block.timestamp + deadline
        });

        bytes32 digest = sigUtils.getTypedDataHash(authorization);

        Types.Signature memory sig;
        (sig.v, sig.r, sig.s) = vm.sign(OWNER_PK, digest);

        morpho.approveManagerWithSig(
            authorization.delegator,
            authorization.manager,
            authorization.isAllowed,
            authorization.nonce,
            authorization.deadline,
            sig
        );

        assertEq(morpho.isManaging(DELEGATOR, MANAGER), true);
        assertEq(morpho.userNonce(DELEGATOR), 1);
    }

    function testRevertExpiredApproveManagerWithSig(uint128 deadline) public {
        vm.assume(deadline <= block.timestamp);

        SigUtils.Authorization memory authorization = SigUtils.Authorization({
            delegator: DELEGATOR,
            manager: MANAGER,
            isAllowed: true,
            nonce: morpho.userNonce(DELEGATOR),
            deadline: deadline
        });

        bytes32 digest = sigUtils.getTypedDataHash(authorization);
        Types.Signature memory sig;
        (sig.v, sig.r, sig.s) = vm.sign(OWNER_PK, digest);

        vm.expectRevert(abi.encodeWithSelector(Errors.SignatureExpired.selector));
        morpho.approveManagerWithSig(
            authorization.delegator,
            authorization.manager,
            authorization.isAllowed,
            authorization.nonce,
            authorization.deadline,
            sig
        );
    }

    function testRevertInvalidSignatoryApproveManagerWithSig() public {
        SigUtils.Authorization memory authorization = SigUtils.Authorization({
            delegator: DELEGATOR,
            manager: MANAGER,
            isAllowed: true,
            nonce: morpho.userNonce(DELEGATOR),
            deadline: block.timestamp + 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(authorization);
        Types.Signature memory sig;
        (sig.v, sig.r, sig.s) = vm.sign(MANAGER_PK, digest); // manager signs delegator's approval.

        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidSignatory.selector));
        morpho.approveManagerWithSig(
            authorization.delegator,
            authorization.manager,
            authorization.isAllowed,
            authorization.nonce,
            authorization.deadline,
            sig
        );
    }

    function testRevertInvalidNonceApproveManagerWithSig(uint256 nonce) public {
        vm.assume(nonce != morpho.userNonce(DELEGATOR));

        SigUtils.Authorization memory authorization = SigUtils.Authorization({
            delegator: DELEGATOR,
            manager: MANAGER,
            isAllowed: true,
            nonce: nonce,
            deadline: block.timestamp + 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(authorization);
        Types.Signature memory sig;
        (sig.v, sig.r, sig.s) = vm.sign(OWNER_PK, digest);

        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidNonce.selector));
        morpho.approveManagerWithSig(
            authorization.delegator,
            authorization.manager,
            authorization.isAllowed,
            authorization.nonce,
            authorization.deadline,
            sig
        );
    }

    function testRevertSignatureReplayApproveManagerWithSig() public {
        SigUtils.Authorization memory authorization = SigUtils.Authorization({
            delegator: DELEGATOR,
            manager: MANAGER,
            isAllowed: true,
            nonce: morpho.userNonce(DELEGATOR),
            deadline: block.timestamp + 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(authorization);
        Types.Signature memory sig;
        (sig.v, sig.r, sig.s) = vm.sign(OWNER_PK, digest);

        morpho.approveManagerWithSig(
            authorization.delegator,
            authorization.manager,
            authorization.isAllowed,
            authorization.nonce,
            authorization.deadline,
            sig
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidNonce.selector));
        morpho.approveManagerWithSig(
            authorization.delegator,
            authorization.manager,
            authorization.isAllowed,
            authorization.nonce,
            authorization.deadline,
            sig
        );
    }
}

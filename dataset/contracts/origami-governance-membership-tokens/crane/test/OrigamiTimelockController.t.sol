// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.16;

import {OrigamiTimelockController} from "src/OrigamiTimelockController.sol";
import {IERC721Receiver} from "src/interfaces/utils/IERC721Receiver.sol";
import {IERC1155Receiver} from "src/interfaces/utils/IERC1155Receiver.sol";
import {ITimelockController} from "src/interfaces/ITimelockController.sol";
import {IERC165} from "@oz/utils/introspection/IERC165.sol";

import {Test} from "@std/Test.sol";

contract OrigamiTimelockControllerTest is Test {
    address public deployer = address(0xbeefea7e2);
    address public proposer = address(0x1);
    address public executor = address(0x2);
    address public canceller = address(0x3);

    address[] public proposers = new address[](1);
    address[] public executors = new address[](1);

    address[] public targets = new address[](1);
    uint256[] public values = new uint256[](1);
    bytes[] public calldatas = new bytes[](1);
    bytes32 public salt = keccak256(bytes("description"));

    bytes32 public opHash;

    OrigamiTimelockController public timelock;

    event Cancelled(bytes32 indexed id);
    event CallScheduled(
        bytes32 indexed id,
        uint256 indexed index,
        address target,
        uint256 value,
        bytes data,
        bytes32 predecessor,
        uint256 delay
    );
    event MinDelayChange(uint256 oldDelay, uint256 newDelay);

    function setUp() public {
        proposers[0] = proposer;
        executors[0] = executor;
        vm.prank(deployer);
        timelock = new OrigamiTimelockController(1 days, proposers, executors);

        targets[0] = address(timelock);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("updateDelay(uint256)", 2 days);

        opHash = timelock.hashOperationBatch(targets, values, calldatas, 0, salt);
    }

    function testSupportsInterface() public {
        assertEq(timelock.supportsInterface(type(IERC165).interfaceId), true);
        assertEq(timelock.supportsInterface(type(ITimelockController).interfaceId), true);
        assertEq(timelock.supportsInterface(type(IERC721Receiver).interfaceId), true);
        assertEq(timelock.supportsInterface(type(IERC1155Receiver).interfaceId), true);
    }

    function testHashOperation() public {
        assertEq(timelock.hashOperation(address(0), 0, "", 0, salt), keccak256(abi.encode(address(0), 0, "", 0, salt)));
    }

    function testIsOperation() public {
        vm.prank(proposer);
        vm.expectEmit(true, true, true, true, address(timelock));
        emit CallScheduled(opHash, 0, targets[0], values[0], calldatas[0], 0, 1 days);
        timelock.scheduleBatch(targets, values, calldatas, 0, salt, 1 days);

        assertEq(timelock.isOperation(0), false);
        assertEq(timelock.isOperation(opHash), true);
    }

    function testIsOperationPending() public {
        vm.prank(proposer);
        timelock.scheduleBatch(targets, values, calldatas, 0, salt, 1 days);

        assertEq(timelock.isOperationPending(0), false);
        assertEq(timelock.isOperationPending(opHash), true);
    }

    function testIsOperationReady() public {
        vm.prank(proposer);
        timelock.scheduleBatch(targets, values, calldatas, 0, salt, 1 days);

        assertEq(timelock.isOperationReady(0), false);
        assertEq(timelock.isOperationReady(opHash), false);

        vm.warp(block.timestamp + 1 days + 1);

        assertEq(timelock.isOperationReady(0), false);
        assertEq(timelock.isOperationReady(opHash), true);

        vm.prank(executor);
        timelock.executeBatch(targets, values, calldatas, 0, salt);
    }

    function testIsOperationDone() public {
        vm.prank(proposer);
        timelock.scheduleBatch(targets, values, calldatas, 0, salt, 1 days);

        vm.warp(block.timestamp + 1 days + 1);

        assertEq(timelock.isOperationDone(0), false);
        assertEq(timelock.isOperationDone(opHash), false);

        vm.prank(executor);
        timelock.executeBatch(targets, values, calldatas, 0, salt);

        assertEq(timelock.isOperationDone(0), false);
        assertEq(timelock.isOperationDone(opHash), true);
    }

    function testGetTimestamp() public {
        vm.prank(proposer);
        timelock.scheduleBatch(targets, values, calldatas, 0, salt, 1 days);
        assertEq(timelock.getTimestamp(opHash), block.timestamp + 1 days);
    }

    function testGetMinDelay() public {
        assertEq(timelock.getMinDelay(), 1 days);
    }

    function testCantScheduleLowerThanMinimumDelay() public {
        vm.prank(proposer);
        vm.expectRevert("TimelockController: insufficient delay");
        timelock.scheduleBatch(targets, values, calldatas, 0, salt, 0.5 days);
    }

    function testCancellerCanCancel() public {
        vm.startPrank(deployer);
        timelock.grantRole(timelock.CANCELLER_ROLE(), canceller);
        vm.stopPrank();

        vm.prank(proposer);
        timelock.scheduleBatch(targets, values, calldatas, 0, salt, 1 days);

        vm.prank(canceller);
        vm.expectEmit(true, true, true, true, address(timelock));
        emit Cancelled(opHash);
        timelock.cancel(opHash);
    }

    function testCanCancelReadyOperations() public {
        vm.startPrank(deployer);
        timelock.grantRole(timelock.CANCELLER_ROLE(), canceller);
        vm.stopPrank();

        vm.prank(proposer);
        timelock.scheduleBatch(targets, values, calldatas, 0, salt, 1 days);

        assertFalse(timelock.isOperationReady(opHash));

        vm.warp(block.timestamp + 1 days + 1);

        assertTrue(timelock.isOperationReady(opHash));

        vm.prank(canceller);
        vm.expectEmit(true, true, true, true, address(timelock));
        emit Cancelled(opHash);
        timelock.cancel(opHash);
    }

    function testCantCancelDoneOperations() public {
        vm.startPrank(deployer);
        timelock.grantRole(timelock.CANCELLER_ROLE(), canceller);
        vm.stopPrank();

        vm.prank(proposer);
        timelock.scheduleBatch(targets, values, calldatas, 0, salt, 1 days);

        vm.warp(block.timestamp + 1 days + 1);

        assertFalse(timelock.isOperationDone(opHash));

        vm.prank(executor);
        timelock.executeBatch(targets, values, calldatas, 0, salt);

        assertTrue(timelock.isOperationDone(opHash));

        vm.prank(canceller);
        vm.expectRevert("TimelockController: operation cannot be cancelled");
        timelock.cancel(opHash);
    }

    function testUpdateDelay() public {
        vm.prank(address(timelock));
        vm.expectEmit(true, true, true, true, address(timelock));
        emit MinDelayChange(1 days, 2 days);
        timelock.updateDelay(2 days);
    }

    function testCantDirectlyUpdateDelay() public {
        vm.prank(address(deployer));
        vm.expectRevert("TimelockController: caller must be timelock");
        timelock.updateDelay(2 days);
    }

    function testOnERC721Received() public {
        assertEq(
            timelock.onERC721Received(address(0), address(0), 0, ""),
            bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))
        );
    }

    function testOnERC1155Received() public {
        assertEq(
            timelock.onERC1155Received(address(0), address(0), 0, 0, ""),
            bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))
        );
    }

    function testOnERC1155BatchReceived() public {
        assertEq(
            timelock.onERC1155BatchReceived(address(0), address(0), new uint256[](0), new uint256[](0), ""),
            bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))
        );
    }
}

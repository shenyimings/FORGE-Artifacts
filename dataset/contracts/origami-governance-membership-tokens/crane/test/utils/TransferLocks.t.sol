// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {TransferLocks} from "src/utils/TransferLocks.sol";
import {ITransferLocks} from "src/interfaces/ITransferLocks.sol";
import {TransparentUpgradeableProxy} from "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@oz/proxy/transparent/ProxyAdmin.sol";
import {Test, console2} from "@std/Test.sol";

contract TransferLocksTestHelper is Test {
    TransferLocks public impl;
    ProxyAdmin public proxyAdmin;
    TransparentUpgradeableProxy public proxy;
    TransferLocks public token;

    address public deployer = address(0x1);
    address public owner = address(0x2);

    address public mintee = address(0x3);
    address public minter = address(0x4);
    address public recipient = address(0x5);

    constructor() {
        vm.startPrank(owner);
        impl = new TransferLocks();
        proxyAdmin = new ProxyAdmin();
        proxy = new TransparentUpgradeableProxy(
            address(impl),
            address(proxyAdmin),
            ""
        );
        token = TransferLocks(address(proxy));
        token.initialize(owner, "TransferLocksTest", "TLT", type(uint256).max);
        token.mint(mintee, 100);
        token.enableTransfer();
        vm.stopPrank();
    }
}

contract TransferLocksTest is TransferLocksTestHelper {
    function testEmptyTransferLock() public {
        uint256 amount = token.getTransferLockTotal(mintee);
        assertEq(amount, 0);
    }

    function testAddTransferLock() public {
        assertEq(block.timestamp, 1);
        vm.prank(mintee);
        token.addTransferLock(100, 1000);
        uint256 amount = token.getTransferLockTotal(mintee);
        assertEq(amount, 100);
    }

    function testIncreaseTransferLockAllowance() public {
        vm.prank(minter);
        token.increaseTransferLockAllowance(mintee, 50);
        assertEq(token.allowances(minter, mintee), 50);
    }

    function testCannotIncreaseTransferLockAllowanceAboveMax() public {
        vm.startPrank(minter);
        token.increaseTransferLockAllowance(mintee, type(uint8).max);
        vm.expectRevert("TransferLocks: cannot exceed max account locks and allowances");
        token.increaseTransferLockAllowance(mintee, 1);
        vm.stopPrank();
        vm.startPrank(mintee);
        token.increaseTransferLockAllowance(minter, 155);
        vm.expectRevert("TransferLocks: cannot exceed max account locks and allowances");
        token.increaseTransferLockAllowance(minter, 101);
        // does not revert
        token.increaseTransferLockAllowance(minter, 100);
        vm.stopPrank();
        assertEq(token.allowances(minter, mintee), 255);
        assertEq(token.allowances(mintee, minter), 255);
    }

    function testDecreaseTransferLockAllowance() public {
        vm.startPrank(minter);
        token.increaseTransferLockAllowance(mintee, 50);
        assertEq(token.allowances(minter, mintee), 50);
        token.decreaseTransferLockAllowance(mintee, 25);
        assertEq(token.allowances(minter, mintee), 25);
    }

    function testCannotDecreaseTransferLockAllowanceBelowZero() public {
        vm.startPrank(minter);
        token.increaseTransferLockAllowance(mintee, 50);
        assertEq(token.allowances(minter, mintee), 50);
        vm.expectRevert("TransferLocks: insufficient allowance");
        token.decreaseTransferLockAllowance(mintee, 51);
    }

    function testCannotAddTransferLockIfAllowanceExceeded() public {
        vm.startPrank(mintee);
        token.increaseTransferLockAllowance(minter, type(uint8).max);
        vm.expectRevert("TransferLocks: cannot exceed max account locks and allowances");
        token.addTransferLock(1, 1000);
    }

    function testCannotIncreaseTransferLockAllowanceIfAccountNumLocksWouldBeExceeded() public {
        vm.startPrank(mintee);
        for (uint8 i = 0; i < 50; i++) {
            token.addTransferLock(1, 1000);
        }
        vm.expectRevert("TransferLocks: cannot exceed max account locks and allowances");
        token.increaseTransferLockAllowance(minter, 206);
    }

    function testGetTransferLockTotalAt() public {
        vm.startPrank(mintee);
        token.addTransferLock(50, 1000);
        token.addTransferLock(25, 2000);
        token.addTransferLock(25, 3000);
        assertEq(token.getTransferLockTotalAt(mintee, 1), 100);
        assertEq(token.getTransferLockTotalAt(mintee, 1000), 100);
        assertEq(token.getTransferLockTotalAt(mintee, 1001), 50);
        assertEq(token.getTransferLockTotalAt(mintee, 2000), 50);
        assertEq(token.getTransferLockTotalAt(mintee, 2001), 25);
        assertEq(token.getTransferLockTotalAt(mintee, 3000), 25);
        assertEq(token.getTransferLockTotalAt(mintee, 3001), 0);
    }

    function testGetAvailableBalance() public {
        vm.startPrank(mintee);
        token.addTransferLock(50, 1000);
        assertEq(token.getAvailableBalance(mintee), 50);
        token.addTransferLock(25, 2000);
        assertEq(token.getAvailableBalance(mintee), 25);
        token.addTransferLock(25, 3000);
        assertEq(token.getAvailableBalance(mintee), 0);
    }

    function testGetAvailableBalanceAt() public {
        vm.startPrank(mintee);
        token.addTransferLock(50, 1000);
        token.addTransferLock(25, 2000);
        token.addTransferLock(25, 3000);
        assertEq(token.getAvailableBalanceAt(mintee, 1), 0);
        assertEq(token.getAvailableBalanceAt(mintee, 1000), 0);
        assertEq(token.getAvailableBalanceAt(mintee, 1001), 50);
        assertEq(token.getAvailableBalanceAt(mintee, 2000), 50);
        assertEq(token.getAvailableBalanceAt(mintee, 2001), 75);
        assertEq(token.getAvailableBalanceAt(mintee, 3000), 75);
        assertEq(token.getAvailableBalanceAt(mintee, 3001), 100);
    }

    function testTransferWithLock() public {
        address recipient = address(0x42);
        vm.prank(recipient);
        token.increaseTransferLockAllowance(mintee, 2);

        vm.startPrank(mintee);
        token.transferWithLock(recipient, 10, 68);
        token.transferWithLock(recipient, 10, 419);
        vm.stopPrank();

        assertEq(token.balanceOf(recipient), 20);
        assertEq(token.getAvailableBalanceAt(recipient, 1), 0);
        assertEq(token.getAvailableBalanceAt(recipient, 69), 10);
        assertEq(token.getAvailableBalanceAt(recipient, 420), 20);
    }

    function testCannotTransferWithLockWithoutAllowance() public {
        address recipient = address(0x42);
        vm.prank(mintee);
        vm.expectRevert("TransferLocks: insufficient allowance");
        token.transferWithLock(recipient, 10, 68);
    }

    function testBatchTransferWithLocksRevertsWhenInputsAreInvalidLengths() public {
        address[] memory recipients = new address[](2);
        uint256[] memory amounts = new uint256[](3);
        uint256[] memory timelocks = new uint256[](2);

        vm.prank(address(0x42));
        vm.expectRevert("TransferLock: recipients and amounts must be the same length");
        token.batchTransferWithLocks(recipients, amounts, timelocks);

        address[] memory recipients2 = new address[](2);
        uint256[] memory amounts2 = new uint256[](2);
        uint256[] memory timelocks2 = new uint256[](3);

        vm.prank(address(0x42));
        vm.expectRevert("TransferLock: recipients and deadlines must be the same length");
        token.batchTransferWithLocks(recipients2, amounts2, timelocks2);
    }

    function testBatchTransferWithLocks() public {
        address treasury = address(0x42);
        vm.prank(owner);
        token.mint(treasury, 1000000);

        vm.prank(address(0x43));
        token.increaseTransferLockAllowance(treasury, 5);
        vm.prank(address(0x44));
        token.increaseTransferLockAllowance(treasury, 5);

        address[] memory recipients = new address[](10);
        uint256[] memory amounts = new uint256[](10);
        uint256[] memory timelocks = new uint256[](10);

        for (uint256 i = 0; i < 10; i++) {
            recipients[i] = (i % 2 == 0) ? address(0x43) : address(0x44);
        }

        for (uint256 i = 0; i < 10; i++) {
            amounts[i] = 100000;
        }

        uint256 counter = 0;
        for (uint256 i = 0; i < 10; i += 2) {
            uint256 timelock = counter * 100 + 100;
            timelocks[i] = timelock;
            timelocks[i + 1] = timelock;
            counter++;
        }

        vm.prank(treasury);
        token.batchTransferWithLocks(recipients, amounts, timelocks);

        assertEq(token.balanceOf(address(0x43)), 500000);
        assertEq(token.balanceOf(address(0x44)), 500000);

        assertEq(token.getAvailableBalanceAt(address(0x43), 1), 0);
        assertEq(token.getAvailableBalanceAt(address(0x43), 101), 100000);
        assertEq(token.getAvailableBalanceAt(address(0x43), 201), 200000);
        assertEq(token.getAvailableBalanceAt(address(0x43), 301), 300000);
        assertEq(token.getAvailableBalanceAt(address(0x43), 401), 400000);
        assertEq(token.getAvailableBalanceAt(address(0x43), 501), 500000);

        assertEq(token.getAvailableBalanceAt(address(0x44), 1), 0);
        assertEq(token.getAvailableBalanceAt(address(0x44), 101), 100000);
        assertEq(token.getAvailableBalanceAt(address(0x44), 201), 200000);
        assertEq(token.getAvailableBalanceAt(address(0x44), 301), 300000);
        assertEq(token.getAvailableBalanceAt(address(0x44), 401), 400000);
        assertEq(token.getAvailableBalanceAt(address(0x44), 501), 500000);
    }

    function testBatchTransferWithLocksCannotExceedAllowance() public {
        address treasury = address(0x42);
        vm.prank(owner);
        token.mint(treasury, 1000000);

        vm.prank(address(0x43));
        token.increaseTransferLockAllowance(treasury, 5);

        address[] memory recipients = new address[](10);
        uint256[] memory amounts = new uint256[](10);
        uint256[] memory timelocks = new uint256[](10);

        for (uint256 i = 0; i < 10; i++) {
            recipients[i] = address(0x43);
        }

        for (uint256 i = 0; i < 10; i++) {
            amounts[i] = 100000;
        }

        for (uint256 i = 0; i < 10; i++) {
            timelocks[i] = 100;
        }

        vm.prank(treasury);
        vm.expectRevert("TransferLocks: insufficient allowance");
        token.batchTransferWithLocks(recipients, amounts, timelocks);
    }

    function testSupportsInterface() public {
        assertTrue(token.supportsInterface(0x01ffc9a7)); // ERC165
        assertTrue(token.supportsInterface(type(ITransferLocks).interfaceId));
    }
}

contract TransferLockUseCaseTests is TransferLocksTestHelper {
    function testCannotAddTransferLockForAmountZero() public {
        vm.prank(mintee);
        vm.expectRevert("TransferLock: amount must be greater than zero");
        token.addTransferLock(0, 1000);
    }

    function testCanSetMultipleLocks() public {
        vm.startPrank(mintee);
        token.addTransferLock(50, 1000);
        token.addTransferLock(49, 2000);
        assertEq(token.getTransferLockTotal(mintee), 99);

        vm.warp(1001);
        assertEq(token.getTransferLockTotal(mintee), 49);
    }

    function testCannotUnderflowAmount() public {
        vm.prank(mintee);
        token.addTransferLock(100, 1000);
        // we would get an underflow revert if we weren't checking the balance
        // exceeds the amount, since we do, we get the built-in revert about the
        // amount being too high
        vm.prank(mintee);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        token.transfer(minter, 200);
    }

    function testCannotCreateTransferLockInPast() public {
        vm.warp(10000);
        vm.prank(mintee);
        vm.expectRevert("TransferLock: deadline must be in the future");
        token.addTransferLock(100, 1);
    }

    function testCannotAddTransferLockAmountHigherThanBalance() public {
        vm.prank(mintee);
        vm.expectRevert("TransferLock: amount cannot exceed available balance");
        token.addTransferLock(101, 1000);
    }

    function testCannotTransferWhileLocked() public {
        vm.warp(1673049600); // 2023-01-01
        vm.prank(mintee);
        token.addTransferLock(100, 1704585600); // 2024-01-01
        vm.prank(mintee);
        vm.expectRevert("TransferLock: this exceeds your unlocked balance");
        token.transfer(minter, 10);
    }

    function testCanTransferSurplusWhileLocked() public {
        vm.warp(1673049600); // 2023-01-01
        vm.prank(mintee);
        token.addTransferLock(90, 1704585600); // 2024-01-01
        vm.prank(mintee);
        token.transfer(minter, 10);
        assertEq(token.balanceOf(mintee), 90);
        assertEq(token.balanceOf(minter), 10);
    }

    function testCanTransferAfterLockExpires() public {
        vm.warp(1673049600); // 2023-01-01
        vm.prank(mintee);
        token.addTransferLock(100, 1704585600); // 2024-01-01

        // timelock date is inclusive, so an attempt to transfer at the exact timelock time will fail
        vm.warp(1704585600); // 2024-01-01
        vm.prank(mintee);
        vm.expectRevert("TransferLock: this exceeds your unlocked balance");
        token.transfer(mintee, 10);

        // warp to the second immediately after the timelock expires and try again
        vm.prank(mintee);
        vm.warp(1704585601); // 2024-01-01
        token.transfer(minter, 10);
        assertEq(token.balanceOf(minter), 10);
    }

    function testCannotAddLockThatExceedsCurrentAvailableBalance() public {
        vm.warp(1673049600); // 2023-01-01

        // start off with 100 tokens
        assertEq(token.balanceOf(mintee), 100);

        // add a lock for the full amount until March 21, 2023
        vm.prank(mintee);
        token.addTransferLock(100, 1679426715); //2023-03-21

        assertEq(token.balanceOf(mintee), 100);
        assertEq(token.getTransferLockTotalAt(mintee, block.timestamp), 100);
        assertEq(token.getAvailableBalanceAt(mintee, block.timestamp), 0);

        // add another lock for full amount for a day longer than the last
        vm.prank(mintee);
        vm.expectRevert("TransferLock: amount cannot exceed available balance");
        token.addTransferLock(100, 1679513115); //2023-03-22
    }

    function testAddingMultipleLocksWithTheSameDeadlineAndDifferentAmounts() public {
        vm.startPrank(mintee);

        // start off with 100 tokens
        assertEq(token.balanceOf(mintee), 100);

        token.addTransferLock(10, 1000);
        token.addTransferLock(20, 1000);

        assertEq(token.balanceOf(mintee), 100);
        assertEq(token.getTransferLockTotalAt(mintee, 1000), 30);
        assertEq(token.getTransferLockTotalAt(mintee, block.timestamp), 30);
        assertEq(token.getAvailableBalanceAt(mintee, 1000), 70);
        assertEq(token.getAvailableBalanceAt(mintee, 1001), 100);

        vm.warp(50);

        token.addTransferLock(30, 1000);
        token.addTransferLock(40, 1000);

        vm.expectRevert("TransferLock: amount cannot exceed available balance");
        token.addTransferLock(10, 1000);

        assertEq(token.balanceOf(mintee), 100);
        assertEq(token.getTransferLockTotalAt(mintee, 1000), 100);
        assertEq(token.getTransferLockTotalAt(mintee, block.timestamp), 100);
        assertEq(token.getAvailableBalanceAt(mintee, 1000), 0);
        assertEq(token.getAvailableBalanceAt(mintee, 1001), 100);
    }

    function testAddingMultipleLocksWithDescendingDeadlines() public {
        vm.startPrank(mintee);

        // start off with 100 tokens
        assertEq(token.balanceOf(mintee), 100);

        token.addTransferLock(10, 1000);
        token.addTransferLock(20, 900);
        token.addTransferLock(10, 800);
        token.addTransferLock(20, 700);

        assertEq(token.balanceOf(mintee), 100);
        assertEq(token.getTransferLockTotal(mintee), 60);
        assertEq(token.getAvailableBalanceAt(mintee, 1000), 90);
        assertEq(token.getAvailableBalanceAt(mintee, 1001), 100);
        assertEq(token.getAvailableBalanceAt(mintee, 700), 40);
        assertEq(token.getTransferLockTotalAt(mintee, 1001), 0);
        assertEq(token.getTransferLockTotalAt(mintee, 1000), 10);
        assertEq(token.getTransferLockTotalAt(mintee, 700), 60);
    }

    function testTransferWithLockCannotExceedYourBalance() public {
        vm.prank(recipient);
        token.increaseTransferLockAllowance(mintee, 6);

        vm.startPrank(mintee);

        // start off with 100 tokens
        assertEq(token.balanceOf(mintee), 100);

        token.transferWithLock(recipient, 10, 1000);
        token.transferWithLock(recipient, 20, 900);
        token.transferWithLock(recipient, 10, 800);
        token.transferWithLock(recipient, 20, 700);
        token.transferWithLock(recipient, 40, 600);

        vm.expectRevert("TransferLock: amount cannot exceed available balance");
        token.transferWithLock(recipient, 1, 700);

        assertEq(token.balanceOf(recipient), 100);
        assertEq(token.getTransferLockTotal(recipient), 100);
        assertEq(token.getAvailableBalanceAt(recipient, 1000), 90);
        assertEq(token.getAvailableBalanceAt(recipient, 1001), 100);
        assertEq(token.getAvailableBalanceAt(recipient, 700), 40);
        assertEq(token.getTransferLockTotalAt(recipient, 1001), 0);
        assertEq(token.getTransferLockTotalAt(recipient, 1000), 10);
        assertEq(token.getTransferLockTotalAt(recipient, 600), 100);
        assertEq(token.getTransferLockTotalAt(recipient, 601), 60);
    }

    /// guard against not being able to add a lock if an account doesn't already
    /// have a balance that could absorb it.
    function testTransferLockIsAppliedAfterBalanceIsUpdated() public {
        // minter has no balance in advance of being transferred to
        assertEq(token.balanceOf(minter), 0);

        vm.prank(minter);
        token.increaseTransferLockAllowance(mintee, 1);

        // mintee transferWithLock's 10 tokens to minter
        vm.prank(mintee);
        token.transferWithLock(minter, 10, 1000);

        assertEq(token.getTransferLockTotal(minter), 10);
    }

    function testTransferLockAtMaxValue() public {
        vm.prank(owner);
        token.mint(mintee, type(uint256).max - 100);
        vm.prank(mintee);
        token.addTransferLock(type(uint256).max, 1000);

        assertEq(token.balanceOf(mintee), type(uint256).max);
        assertEq(token.getTransferLockTotal(mintee), type(uint256).max);
    }
}

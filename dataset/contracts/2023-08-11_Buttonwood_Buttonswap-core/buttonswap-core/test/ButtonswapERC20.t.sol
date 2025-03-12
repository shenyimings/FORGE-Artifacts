// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.13;

import "buttonswap-core_forge-std/Test.sol";
import {IButtonswapERC20Events, IButtonswapERC20Errors} from "../src/interfaces/IButtonswapERC20/IButtonswapERC20.sol";
import {ButtonswapERC20} from "../src/ButtonswapERC20.sol";
import {MockButtonswapERC20} from "./mocks/MockButtonswapERC20.sol";
import {Utils} from "./utils/Utils.sol";

contract ButtonswapERC20Test is Test, IButtonswapERC20Events, IButtonswapERC20Errors {
    ButtonswapERC20 public buttonswapERC20;
    MockButtonswapERC20 public mockButtonswapERC20;
    address public userA = 0x000000000000000000000000000000000000000A;
    address public userB = 0x000000000000000000000000000000000000000b;
    address public userC = 0x000000000000000000000000000000000000000C;
    address public userD = 0x000000000000000000000000000000000000000d;

    function setUp() public {
        buttonswapERC20 = new ButtonswapERC20();
        mockButtonswapERC20 = new MockButtonswapERC20();
    }

    function test_name() public {
        assertEq(buttonswapERC20.name(), "Buttonswap");
    }

    function test_symbol() public {
        assertEq(buttonswapERC20.symbol(), "BTNSWP");
    }

    function test_decimals() public {
        assertEq(buttonswapERC20.decimals(), 18);
    }

    function test_totalSupply() public {
        assertEq(buttonswapERC20.totalSupply(), 0);
    }

    function test_balanceOf() public {
        address owner;
        assertEq(buttonswapERC20.balanceOf(owner), 0);
    }

    function test_DOMAIN_SEPARATOR() public {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        assertEq(chainId, 31337);
        assertEq(
            buttonswapERC20.DOMAIN_SEPARATOR(),
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes("Buttonswap")),
                    keccak256(bytes("1")),
                    chainId,
                    address(buttonswapERC20)
                )
            )
        );
    }

    function test_mint(uint256 amount1, uint256 amount2) public {
        vm.assume(amount1 <= (type(uint256).max / 2));
        vm.assume(amount2 < (type(uint256).max / 2));

        mockButtonswapERC20.mockMint(userA, amount1);
        assertEq(mockButtonswapERC20.totalSupply(), amount1);
        assertEq(mockButtonswapERC20.balanceOf(userA), amount1);

        mockButtonswapERC20.mockMint(userB, amount2);
        assertEq(mockButtonswapERC20.totalSupply(), amount1 + amount2);
        assertEq(mockButtonswapERC20.balanceOf(userB), amount2);
    }

    function test_burn(uint256 amount1, uint256 amount2) public {
        vm.assume(amount1 <= (type(uint256).max / 2));
        vm.assume(amount2 < (type(uint256).max / 2));

        mockButtonswapERC20.mockMint(userA, amount1);
        mockButtonswapERC20.mockMint(userB, amount2);

        mockButtonswapERC20.mockBurn(userA, amount1);
        assertEq(mockButtonswapERC20.totalSupply(), amount2);
        assertEq(mockButtonswapERC20.balanceOf(userA), 0);
        assertEq(mockButtonswapERC20.balanceOf(userB), amount2);

        mockButtonswapERC20.mockBurn(userB, amount2);
        assertEq(mockButtonswapERC20.totalSupply(), 0);
        assertEq(mockButtonswapERC20.balanceOf(userA), 0);
        assertEq(mockButtonswapERC20.balanceOf(userB), 0);
    }

    function test_burn_CannotBurnMoreThanBalance(uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount <= type(uint256).max);

        // Mint slightly less than what is burned
        mockButtonswapERC20.mockMint(userA, amount - 1);

        vm.expectRevert(stdError.arithmeticError);
        mockButtonswapERC20.mockBurn(userA, amount);
    }

    function test_approve(uint256 amount) public {
        address owner = userA;
        address spender = userB;

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit Approval(owner, spender, amount);
        bool success = mockButtonswapERC20.approve(spender, amount);

        assertTrue(success);
        assertEq(mockButtonswapERC20.allowance(owner, spender), amount);
    }

    function test_transfer(uint256 initialBalance, uint256 amount) public {
        vm.assume(amount <= initialBalance);
        address sender = userA;
        address recipient = userB;

        mockButtonswapERC20.mockMint(sender, initialBalance);
        assertEq(mockButtonswapERC20.balanceOf(sender), initialBalance);
        assertEq(mockButtonswapERC20.balanceOf(recipient), 0);

        vm.prank(sender);
        vm.expectEmit(true, true, true, true);
        emit Transfer(sender, recipient, amount);
        bool success = mockButtonswapERC20.transfer(recipient, amount);

        assertTrue(success);
        assertEq(mockButtonswapERC20.balanceOf(sender), initialBalance - amount);
        assertEq(mockButtonswapERC20.balanceOf(recipient), amount);
    }

    function test_transfer_CannotTransferMoreThanBalance(uint256 initialBalance, uint256 amount) public {
        vm.assume(amount > initialBalance);
        address sender = userA;
        address recipient = userB;

        mockButtonswapERC20.mockMint(sender, initialBalance);
        assertEq(mockButtonswapERC20.balanceOf(sender), initialBalance);
        assertEq(mockButtonswapERC20.balanceOf(recipient), 0);

        vm.prank(sender);
        vm.expectRevert(stdError.arithmeticError);
        bool success = mockButtonswapERC20.transfer(recipient, amount);

        assertFalse(success);
        assertEq(mockButtonswapERC20.balanceOf(sender), initialBalance);
        assertEq(mockButtonswapERC20.balanceOf(recipient), 0);
    }

    function test_transferFrom(uint256 initialBalance, uint256 amount) public {
        vm.assume(amount <= initialBalance);
        // max allowance is a special case which we test elsewhere
        vm.assume(amount != type(uint256).max);
        address sender = userA;
        address spender = userB;
        address recipient = userC;

        mockButtonswapERC20.mockMint(sender, initialBalance);
        assertEq(mockButtonswapERC20.balanceOf(sender), initialBalance);
        assertEq(mockButtonswapERC20.balanceOf(spender), 0);
        assertEq(mockButtonswapERC20.balanceOf(recipient), 0);
        assertEq(mockButtonswapERC20.allowance(sender, spender), 0);

        vm.prank(sender);
        mockButtonswapERC20.approve(spender, amount);
        assertEq(mockButtonswapERC20.allowance(sender, spender), amount);

        vm.prank(spender);
        vm.expectEmit(true, true, true, true);
        emit Approval(sender, spender, 0);
        vm.expectEmit(true, true, true, true);
        emit Transfer(sender, recipient, amount);
        bool success = mockButtonswapERC20.transferFrom(sender, recipient, amount);

        assertTrue(success);
        assertEq(mockButtonswapERC20.balanceOf(sender), initialBalance - amount);
        assertEq(mockButtonswapERC20.balanceOf(spender), 0);
        assertEq(mockButtonswapERC20.balanceOf(recipient), amount);
        assertEq(mockButtonswapERC20.allowance(sender, spender), 0);
    }

    function test_transferFrom_MaxAllowance(uint256 initialBalance, uint256 amount1, uint256 amount2) public {
        vm.assume(amount1 <= (type(uint256).max / 2));
        vm.assume(amount2 < (type(uint256).max / 2));
        vm.assume((amount1 + amount2) <= initialBalance);
        address sender = userA;
        address spender = userB;
        address recipient1 = userC;
        address recipient2 = userD;

        mockButtonswapERC20.mockMint(sender, initialBalance);
        assertEq(mockButtonswapERC20.balanceOf(sender), initialBalance);
        assertEq(mockButtonswapERC20.balanceOf(spender), 0);
        assertEq(mockButtonswapERC20.balanceOf(recipient1), 0);
        assertEq(mockButtonswapERC20.balanceOf(recipient2), 0);
        assertEq(mockButtonswapERC20.allowance(sender, spender), 0);

        vm.prank(sender);
        mockButtonswapERC20.approve(spender, type(uint256).max);
        assertEq(mockButtonswapERC20.allowance(sender, spender), type(uint256).max);

        vm.prank(spender);
        // No approval event expected to be emitted
        vm.expectEmit(true, true, true, true);
        emit Transfer(sender, recipient1, amount1);
        bool success1 = mockButtonswapERC20.transferFrom(sender, recipient1, amount1);

        assertTrue(success1);
        assertEq(mockButtonswapERC20.balanceOf(sender), initialBalance - amount1);
        assertEq(mockButtonswapERC20.balanceOf(spender), 0);
        assertEq(mockButtonswapERC20.balanceOf(recipient1), amount1);
        assertEq(mockButtonswapERC20.balanceOf(recipient2), 0);
        assertEq(mockButtonswapERC20.allowance(sender, spender), type(uint256).max);

        vm.prank(spender);
        vm.expectEmit(true, true, true, true);
        emit Transfer(sender, recipient2, amount2);
        bool success2 = mockButtonswapERC20.transferFrom(sender, recipient2, amount2);

        assertTrue(success2);
        assertEq(mockButtonswapERC20.balanceOf(sender), initialBalance - amount1 - amount2);
        assertEq(mockButtonswapERC20.balanceOf(spender), 0);
        assertEq(mockButtonswapERC20.balanceOf(recipient1), amount1);
        assertEq(mockButtonswapERC20.balanceOf(recipient2), amount2);
        assertEq(mockButtonswapERC20.allowance(sender, spender), type(uint256).max);
    }

    function test_transferFrom_CannotTransferMoreThanBalance(uint256 initialBalance, uint256 amount) public {
        vm.assume(amount > initialBalance);
        address sender = userA;
        address spender = userB;
        address recipient = userC;

        mockButtonswapERC20.mockMint(sender, initialBalance);
        assertEq(mockButtonswapERC20.balanceOf(sender), initialBalance);
        assertEq(mockButtonswapERC20.balanceOf(spender), 0);
        assertEq(mockButtonswapERC20.balanceOf(recipient), 0);
        assertEq(mockButtonswapERC20.allowance(sender, spender), 0);

        vm.prank(sender);
        mockButtonswapERC20.approve(spender, amount);
        assertEq(mockButtonswapERC20.allowance(sender, spender), amount);

        vm.prank(spender);
        vm.expectRevert(stdError.arithmeticError);
        bool success = mockButtonswapERC20.transferFrom(sender, recipient, amount);

        assertFalse(success);
        assertEq(mockButtonswapERC20.balanceOf(sender), initialBalance);
        assertEq(mockButtonswapERC20.balanceOf(spender), 0);
        assertEq(mockButtonswapERC20.balanceOf(recipient), 0);
        assertEq(mockButtonswapERC20.allowance(sender, spender), amount);
    }

    function test_permit(uint256 privateKey, uint256 amount) public {
        vm.assume(Utils.isValidPrivateKey(privateKey));

        address owner = vm.addr(privateKey);
        address spender = userA;
        assertEq(mockButtonswapERC20.nonces(owner), 0);
        assertEq(mockButtonswapERC20.allowance(owner, spender), 0);

        uint256 deadline = block.timestamp + 1 hours;
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                mockButtonswapERC20.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        mockButtonswapERC20.PERMIT_TYPEHASH(),
                        owner,
                        spender,
                        amount,
                        mockButtonswapERC20.nonces(owner),
                        deadline
                    )
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        vm.expectEmit(true, true, true, true);
        emit Approval(owner, spender, amount);
        mockButtonswapERC20.permit(owner, spender, amount, deadline, v, r, s);

        assertEq(mockButtonswapERC20.nonces(owner), 1);
        assertEq(mockButtonswapERC20.allowance(owner, spender), amount);
    }

    function test_permit_CannotCallWhenDeadlineInvalid(uint256 privateKey, uint256 amount) public {
        // This test matches permit call deadline param to what was used to create the signature, but
        //   warps time beyond the value such that it has expired.
        vm.assume(Utils.isValidPrivateKey(privateKey));

        address owner = vm.addr(privateKey);
        address spender = userA;
        assertEq(mockButtonswapERC20.nonces(owner), 0);
        assertEq(mockButtonswapERC20.allowance(owner, spender), 0);

        uint256 deadline = block.timestamp + 1 hours;
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                mockButtonswapERC20.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        mockButtonswapERC20.PERMIT_TYPEHASH(),
                        owner,
                        spender,
                        amount,
                        mockButtonswapERC20.nonces(owner),
                        deadline
                    )
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        // Exceed deadline
        vm.warp(deadline + 1 seconds);
        vm.expectRevert(PermitExpired.selector);
        mockButtonswapERC20.permit(owner, spender, amount, deadline, v, r, s);

        assertEq(mockButtonswapERC20.nonces(owner), 0);
        assertEq(mockButtonswapERC20.allowance(owner, spender), 0);
    }

    function test_permit_CannotCallWhenDeadlineMismatch(uint256 privateKey, uint256 amount) public {
        // This test simulates attempting to call permit with a deadline that is later than the current time, but
        //   which differs from the value used in signature (which has expired)
        vm.assume(Utils.isValidPrivateKey(privateKey));

        address owner = vm.addr(privateKey);
        address spender = userA;
        assertEq(mockButtonswapERC20.nonces(owner), 0);
        assertEq(mockButtonswapERC20.allowance(owner, spender), 0);

        uint256 deadline = block.timestamp + 1 hours;
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                mockButtonswapERC20.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        mockButtonswapERC20.PERMIT_TYPEHASH(),
                        owner,
                        spender,
                        amount,
                        mockButtonswapERC20.nonces(owner),
                        deadline
                    )
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        // Exceed deadline
        vm.warp(deadline + 1 seconds);
        vm.expectRevert(PermitInvalidSignature.selector);
        // Try to call with a deadline value that exceeds current time but doesn't match signature deadline
        mockButtonswapERC20.permit(owner, spender, amount, deadline + 2 seconds, v, r, s);

        assertEq(mockButtonswapERC20.nonces(owner), 0);
        assertEq(mockButtonswapERC20.allowance(owner, spender), 0);
    }

    function test_permit_CannotCallWhenSpenderMismatch(uint256 privateKey, uint256 amount) public {
        // This test simulates attempting to call permit with a deadline that is later than the current time, but
        //   which differs from the value used in signature (which has expired)
        vm.assume(Utils.isValidPrivateKey(privateKey));

        address owner = vm.addr(privateKey);
        address spender = userA;
        address thief = userB;
        assertEq(mockButtonswapERC20.nonces(owner), 0);
        assertEq(mockButtonswapERC20.allowance(owner, spender), 0);
        assertEq(mockButtonswapERC20.allowance(owner, thief), 0);

        uint256 deadline = block.timestamp + 1 hours;
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                mockButtonswapERC20.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        mockButtonswapERC20.PERMIT_TYPEHASH(),
                        owner,
                        spender,
                        amount,
                        mockButtonswapERC20.nonces(owner),
                        deadline
                    )
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        // Try to call with a different spender address
        vm.expectRevert(PermitInvalidSignature.selector);
        mockButtonswapERC20.permit(owner, thief, amount, deadline, v, r, s);

        assertEq(mockButtonswapERC20.nonces(owner), 0);
        assertEq(mockButtonswapERC20.allowance(owner, spender), 0);
        assertEq(mockButtonswapERC20.allowance(owner, thief), 0);

        // Now call with actual spender address
        vm.expectEmit(true, true, true, true);
        emit Approval(owner, spender, amount);
        mockButtonswapERC20.permit(owner, spender, amount, deadline, v, r, s);

        assertEq(mockButtonswapERC20.nonces(owner), 1);
        assertEq(mockButtonswapERC20.allowance(owner, spender), amount);
        assertEq(mockButtonswapERC20.allowance(owner, thief), 0);
    }
}

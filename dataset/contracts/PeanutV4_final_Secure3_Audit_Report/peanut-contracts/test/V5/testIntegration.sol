// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

//////////////////////////////
// A few integration tests for the PeanutV5 contract
//////////////////////////////

import "@forge-std/Test.sol";
import "../../src/V5/PeanutV5.sol";
import "../../src/util/ERC20Mock.sol";
import "../../src/util/ERC721Mock.sol";
import "../../src/util/ERC1155Mock.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract PeanutV5Test is Test, ERC1155Holder, ERC721Holder {
    PeanutV5 public peanutV5;
    ERC20Mock public testToken;
    ERC721Mock public testToken721;
    ERC1155Mock public testToken1155;

    // a dummy private/public keypair to test withdrawals
    address public constant PUBKEY20 = address(0xaBC5211D86a01c2dD50797ba7B5b32e3C1167F9f);
    bytes32 public constant PRIVKEY = 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;

    function setUp() public {
        console.log("Setting up test");
        peanutV5 = new PeanutV5(address(0));
        testToken = new ERC20Mock();
        testToken721 = new ERC721Mock();
        testToken1155 = new ERC1155Mock();
    }

    receive() external payable {}

    // Make a deposit, withdraw the deposit.
    // check invariants
    function testIntegrationEtherSenderWithdraw(uint64 amount) public {
        vm.assume(amount > 0);
        assertEq(peanutV5.getDepositCount(), 0); // deposit count invariant
        assertEq(address(peanutV5).balance, 0); // contract balance invariant
        uint256 senderBalance = address(this).balance; // sender balance invariant
        uint256 depositIdx = peanutV5.makeDeposit{value: amount}(address(0), 0, amount, 0, PUBKEY20);
        assertEq(depositIdx, 0); // deposit index invariant
        assertEq(peanutV5.getDepositCount(), 1); // deposit count invariant
        assertEq(address(peanutV5).balance, amount); // contract balance invariant
        assertEq(address(this).balance, senderBalance - amount); // sender balance invariant

        // wait 25 hours
        vm.warp(block.timestamp + 25 hours);

        // Withdraw the deposit
        peanutV5.withdrawDepositSender(depositIdx);
        assertEq(peanutV5.getDepositCount(), 1); // deposit count invariant
        assertEq(address(peanutV5).balance, 0); // contract balance invariant
        assertEq(address(this).balance, senderBalance); // sender balance invariant
    }

    function testIntegrationERC20SenderWithdraw(uint64 amount) public {
        vm.assume(amount > 0);
        // mint tokens to the contract
        testToken.mint(address(this), amount);
        // approve the contract to spend the tokens
        testToken.approve(address(peanutV5), amount);
        assertEq(testToken.balanceOf(address(this)), amount); // contract token balance invariant
        uint256 depositIdx = peanutV5.makeDeposit(address(testToken), 1, amount, 0, PUBKEY20);
        assertEq(depositIdx, 0); // deposit index invariant
        assertEq(peanutV5.getDepositCount(), 1); // deposit count invariant
        assertEq(testToken.balanceOf(address(peanutV5)), amount); // contract token balance invariant
        assertEq(testToken.balanceOf(address(this)), 0); // sender token balance invariant

        // wait 25 hours
        vm.warp(block.timestamp + 25 hours);

        // Withdraw the deposit
        peanutV5.withdrawDepositSender(depositIdx);
        assertEq(peanutV5.getDepositCount(), 1); // deposit count invariant
        assertEq(testToken.balanceOf(address(peanutV5)), 0); // contract token balance invariant
        assertEq(testToken.balanceOf(address(this)), amount); // sender token balance invariant
    }

    // Test for ERC721 Token
    function testIntegrationERC721SenderWithdraw(uint64 tokenId) public {
        // setup
        testToken721.mint(address(this), tokenId);
        testToken721.approve(address(peanutV5), tokenId);

        // invariant checks
        assertEq(peanutV5.getDepositCount(), 0);
        assertEq(testToken721.ownerOf(tokenId), address(this));
        assertEq(testToken721.balanceOf(address(peanutV5)), 0);
        assertEq(testToken721.balanceOf(address(this)), 1);
        uint256 depositIdx = peanutV5.makeDeposit(address(testToken721), 2, 1, tokenId, PUBKEY20);

        // invariant checks
        assertEq(depositIdx, 0);
        assertEq(peanutV5.getDepositCount(), 1);
        assertEq(testToken721.ownerOf(tokenId), address(peanutV5));
        assertEq(testToken721.balanceOf(address(peanutV5)), 1);
        assertEq(testToken721.balanceOf(address(this)), 0);

        // wait 25 hours
        vm.warp(block.timestamp + 25 hours);

        // Withdraw the deposit
        peanutV5.withdrawDepositSender(depositIdx);

        // invariant checks
        assertEq(peanutV5.getDepositCount(), 1);
        assertEq(testToken721.ownerOf(tokenId), address(this));
        assertEq(testToken721.balanceOf(address(peanutV5)), 0);
        assertEq(testToken721.balanceOf(address(this)), 1);
    }

    // Test for ERC1155 Token
    function testIntegrationERC1155SenderWithdraw(uint64 tokenId, uint64 amount) public {
        vm.assume(amount > 0);
        // mint tokens to the contract
        testToken1155.mint(address(this), tokenId, amount, "");
        testToken1155.setApprovalForAll(address(peanutV5), true);
        assertEq(testToken1155.balanceOf(address(this), tokenId), amount); // contract token balance invariant
        uint256 depositIdx = peanutV5.makeDeposit(address(testToken1155), 3, amount, tokenId, PUBKEY20);
        assertEq(depositIdx, 0); // deposit index invariant
        assertEq(peanutV5.getDepositCount(), 1); // deposit count invariant
        assertEq(testToken1155.balanceOf(address(peanutV5), tokenId), amount); // contract token balance invariant
        assertEq(testToken1155.balanceOf(address(this), tokenId), 0); // sender token balance invariant

        // wait 25 hours
        vm.warp(block.timestamp + 25 hours);

        // Withdraw the deposit
        peanutV5.withdrawDepositSender(depositIdx);
        assertEq(peanutV5.getDepositCount(), 1); // deposit count invariant
        assertEq(testToken1155.balanceOf(address(peanutV5), tokenId), 0); // contract token balance invariant
        assertEq(testToken1155.balanceOf(address(this), tokenId), amount); // sender token balance invariant
    }
}

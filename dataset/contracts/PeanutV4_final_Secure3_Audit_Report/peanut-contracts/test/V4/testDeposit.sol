// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

//////////////////////////////
// A few integration tests for the PeanutV4 contract
//////////////////////////////

import "@forge-std/Test.sol";
import "../../src/V4/PeanutV4.sol";
import "../../src/util/ERC20Mock.sol";
import "../../src/util/ERC721Mock.sol";
import "../../src/util/ERC1155Mock.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract PeanutV4Test is Test, ERC1155Holder, ERC721Holder {
    PeanutV4 public peanutV4;
    ERC20Mock public testToken;
    ERC721Mock public testToken721;
    ERC1155Mock public testToken1155;

    // a dummy private/public keypair to test withdrawals
    address public constant PUBKEY20 = address(0xaBC5211D86a01c2dD50797ba7B5b32e3C1167F9f);
    bytes32 public constant PRIVKEY = 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;

    function setUp() public {
        console.log("Setting up test");
        peanutV4 = new PeanutV4(address(0));
        testToken = new ERC20Mock();
        testToken721 = new ERC721Mock();
        testToken1155 = new ERC1155Mock();
    }

    // make contract payable
    receive() external payable {}

    // Make a deposit, withdraw the deposit.
    // check invariants
    function testDepositEther(uint64 amount, address randomAddress) public {
        vm.assume(amount > 0);
        peanutV4.makeDeposit{value: amount}(randomAddress, 0, amount, 0, PUBKEY20);
    }

    function testDepositERC20(uint64 amount) public {
        vm.assume(amount > 0);
        // mint tokens to the contract
        testToken.mint(address(this), amount);
        // approve the contract to spend the tokens
        testToken.approve(address(peanutV4), amount);
        // console log allowance and amount
        console.log("Allowance: ", testToken.allowance(address(this), address(peanutV4)));
        console.log("Amount: ", amount);
        peanutV4.makeDeposit(address(testToken), 1, amount, 0, PUBKEY20);
    }

    // Test for ERC721 Token
    function testDepositERC721(uint64 tokenId) public {
        // mint a token to the contract
        testToken721.mint(address(this), tokenId);
        // approve the contract to spend the tokens
        testToken721.approve(address(peanutV4), tokenId);
        peanutV4.makeDeposit(address(testToken721), 2, 1, tokenId, PUBKEY20);
    }

    // Test for ERC1155 Token
    function testDepositERC1155(uint64 tokenId, uint64 amount) public {
        vm.assume(amount > 0);
        // mint tokens to the contract
        testToken1155.mint(address(this), tokenId, amount, "");
        // approve the contract to spend the tokens
        testToken1155.setApprovalForAll(address(peanutV4), true);
        peanutV4.makeDeposit(address(testToken1155), 3, amount, tokenId, PUBKEY20);
    }
}

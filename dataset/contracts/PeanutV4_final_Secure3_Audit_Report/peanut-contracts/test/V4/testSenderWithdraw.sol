// SPDX-License-Identifier:
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/V4/PeanutV4.sol";
import "../../src/util/ERC20Mock.sol";
import "../../src/util/ERC721Mock.sol";
import "../../src/util/ERC1155Mock.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract TestSenderWithdrawEther is Test {
    PeanutV4 public peanutV4;
    // a dummy private/public keypair to test withdrawals
    address public constant PUBKEY20 = address(0xaBC5211D86a01c2dD50797ba7B5b32e3C1167F9f);
    bytes32 public constant PRIVKEY = 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;

    receive() external payable {} // necessary to receive ether

    function setUp() public {
        console.log("Setting up test");
        peanutV4 = new PeanutV4(address(0));
    }

    // test sender withdrawal of ERC20
    function testSenderTimeWithdrawEther(uint64 amount) public {
        vm.assume(amount > 0);
        uint256 depositIdx = peanutV4.makeDeposit{value: amount}(address(0), 0, amount, 0, PUBKEY20);

        // wait 25 hours
        vm.warp(block.timestamp + 25 hours);

        // Withdraw the deposit
        peanutV4.withdrawDepositSender(depositIdx);
    }

    function testFailSenderTimeWithdrawEther(uint64 amount) public {
        vm.assume(amount > 0);
        uint256 depositIdx = peanutV4.makeDeposit{value: amount}(address(0), 0, amount, 0, PUBKEY20);

        // Withdraw the deposit
        peanutV4.withdrawDepositSender(depositIdx);
    }

    function testFailSenderTimeWithdrawEther1Hour(uint64 amount) public {
        vm.assume(amount > 0);
        uint256 depositIdx = peanutV4.makeDeposit{value: amount}(address(0), 0, amount, 0, PUBKEY20);

        // wait 1 hour
        vm.warp(block.timestamp + 1 hours);

        // Withdraw the deposit
        peanutV4.withdrawDepositSender(depositIdx);
    }
}

contract TestSenderWithdrawErc20 is Test {
    PeanutV4 public peanutV4;
    ERC20Mock public testToken;

    // a dummy private/public keypair to test withdrawals
    address public constant PUBKEY20 = address(0xaBC5211D86a01c2dD50797ba7B5b32e3C1167F9f);
    bytes32 public constant PRIVKEY = 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;

    uint256 _depositIdx;

    // apparently not possible to fuzz test in setUp() function?
    function setUp() public {
        console.log("Setting up test");
        peanutV4 = new PeanutV4(address(0));
        testToken = new ERC20Mock(); // contractype 1

        // Mint tokens for test accounts (larger than uint128)
        testToken.mint(address(this), 2 ** 130);

        // Approve the contract to spend the tokens
        testToken.approve(address(peanutV4), 2 ** 130);

        // Make a deposit
        uint256 amount = 2 ** 128;
        _depositIdx = peanutV4.makeDeposit(address(testToken), 1, amount, 0, PUBKEY20);
    }

    // test sender withdrawal of ERC20
    function testSenderTimeWithdrawErc20() public {
        // wait 25 hours
        vm.warp(block.timestamp + 25 hours);

        // Withdraw the deposit
        peanutV4.withdrawDepositSender(_depositIdx);
    }

    function testFailSenderTimeWithdrawErc20Immediate() public {
        // Withdraw the deposit
        peanutV4.withdrawDepositSender(_depositIdx);
    }

    function testFailSenderTimeWithdrawErc201Hour() public {
        // wait 1 hour
        vm.warp(block.timestamp + 1 hours);

        // Withdraw the deposit
        peanutV4.withdrawDepositSender(_depositIdx);
    }
}

contract TestSenderWithdrawErc721 is Test, ERC721Holder {
    PeanutV4 public peanutV4;
    ERC721Mock public testToken;

    // a dummy private/public keypair to test withdrawals
    address public constant PUBKEY20 = address(0xaBC5211D86a01c2dD50797ba7B5b32e3C1167F9f);
    bytes32 public constant PRIVKEY = 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;

    uint256 _depositIdx;
    uint256 _tokenId = 1; // tokenId used for ERC721

    // apparently not possible to fuzz test in setUp() function?
    function setUp() public {
        console.log("Setting up test");
        peanutV4 = new PeanutV4(address(0));
        testToken = new ERC721Mock(); // contractype 2

        // Mint token for test
        testToken.mint(address(this), _tokenId);

        // Approve the contract to spend the tokens
        testToken.approve(address(peanutV4), _tokenId);

        // Make a deposit
        _depositIdx = peanutV4.makeDeposit(address(testToken), 2, 0, _tokenId, PUBKEY20);
    }

    // test sender withdrawal of ERC721
    function testSenderTimeWithdrawErc721() public {
        // wait 25 hours
        vm.warp(block.timestamp + 25 hours);

        // Withdraw the deposit
        peanutV4.withdrawDepositSender(_depositIdx);
    }

    function testFailSenderTimeWithdrawErc721Immediate() public {
        // Withdraw the deposit
        peanutV4.withdrawDepositSender(_depositIdx);
    }

    function testFailSenderTimeWithdrawErc7211Hour() public {
        // wait 1 hour
        vm.warp(block.timestamp + 1 hours);

        // Withdraw the deposit
        peanutV4.withdrawDepositSender(_depositIdx);
    }
}

contract TestSenderWithdrawErc1155 is Test, ERC1155Holder {
    PeanutV4 public peanutV4;
    ERC1155Mock public testToken;

    // a dummy private/public keypair to test withdrawals
    address public constant PUBKEY20 = address(0xaBC5211D86a01c2dD50797ba7B5b32e3C1167F9f);
    bytes32 public constant PRIVKEY = 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;

    uint256 _depositIdx;
    uint256 _tokenId = 1; // tokenId used for ERC1155
    uint256 _tokenAmount = 100; // amount of ERC1155 tokens

    // apparently not possible to fuzz test in setUp() function?
    function setUp() public {
        console.log("Setting up test");
        peanutV4 = new PeanutV4(address(0));
        testToken = new ERC1155Mock(); // contractype 3

        // Mint tokens for test
        testToken.mint(address(this), _tokenId, _tokenAmount, "");

        // Approve the contract to spend the tokens
        testToken.setApprovalForAll(address(peanutV4), true);

        // Make a deposit
        _depositIdx = peanutV4.makeDeposit(address(testToken), 3, _tokenAmount, _tokenId, PUBKEY20);
    }

    // test sender withdrawal of ERC1155
    function testSenderTimeWithdrawErc1155() public {
        // wait 25 hours
        vm.warp(block.timestamp + 25 hours);

        // Withdraw the deposit
        peanutV4.withdrawDepositSender(_depositIdx);
    }

    function testFailSenderTimeWithdrawErc1155Immediate() public {
        // Withdraw the deposit
        peanutV4.withdrawDepositSender(_depositIdx);
    }

    function testFailSenderTimeWithdrawErc11551Hour() public {
        // wait 1 hour
        vm.warp(block.timestamp + 1 hours);

        // Withdraw the deposit
        peanutV4.withdrawDepositSender(_depositIdx);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@forge-std/Test.sol";
import "../../src/V4/PeanutBatcherV4.sol";
import "../../src/V4/PeanutV4.sol";
import "../../src/util/ERC20Mock.sol";
import "../../src/util/ERC721Mock.sol";
import "../../src/util/ERC1155Mock.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract PeanutBatcherTest is Test, ERC1155Holder, ERC721Holder {
    PeanutBatcherV4 public batcher;
    PeanutV4 public peanutV4;
    ERC20Mock public testToken;
    ERC721Mock public testToken721;
    ERC1155Mock public testToken1155;
    address public PUBKEY20 = address(0xaBC5211D86a01c2dD50797ba7B5b32e3C1167F9f);

    function setUp() public {
        batcher = new PeanutBatcherV4();
        peanutV4 = new PeanutV4(address(0));
        testToken = new ERC20Mock();
        testToken721 = new ERC721Mock();
        testToken1155 = new ERC1155Mock();
    }

    // make contract payable
    receive() external payable {}

    // Test making a batch deposit of ERC20 tokens
    function testBaseEtherDeposit() public {
        uint64 amount = 100;
        uint64 numDeposits = 10;
        address[] memory pubKeys20 = new address[](numDeposits);
        for (uint256 i = 0; i < numDeposits; i++) {
            pubKeys20[i] = PUBKEY20;
        }

        uint256 totalAmount = amount * numDeposits;
        // make the batch deposit
        uint256[] memory depositIndexes =
            batcher.batchMakeDeposit{value: totalAmount}(address(peanutV4), address(0), 0, amount, 0, pubKeys20);
        // check that the correct number of deposits were made
        assertEq(depositIndexes.length, numDeposits);
    }

    // Test making a batch deposit of ERC20 tokens
    function testBatchERC20Deposit() public {
        uint64 amount = 100;
        uint64 numDeposits = 10;
        address[] memory pubKeys20 = new address[](numDeposits);
        for (uint256 i = 0; i < numDeposits; i++) {
            pubKeys20[i] = PUBKEY20;
        }
        // mint tokens to the caller
        testToken.mint(address(this), amount * numDeposits);
        testToken.approve(address(batcher), amount * numDeposits);

        // make the batch deposit
        uint256[] memory depositIndexes =
            batcher.batchMakeDeposit(address(peanutV4), address(testToken), 1, amount, 0, pubKeys20);
        // check that the correct number of deposits were made
        assertEq(depositIndexes.length, numDeposits);
    }

    // Test making a batch deposit of ERC721 tokens
    function testBatchERC721Deposit() public {
        uint64 numDeposits = 10;
        address[] memory pubKeys20 = new address[](numDeposits);
        for (uint256 i = 0; i < numDeposits; i++) {
            uint64 tokenId = uint64(i);
            pubKeys20[i] = PUBKEY20;
            // mint a token to the caller
            testToken721.mint(address(this), tokenId);
            // approve the PeanutV4 contract to spend the tokens
            testToken721.approve(address(batcher), tokenId);
        }
        // make the batch deposit
        uint256[] memory depositIndexes =
            batcher.batchMakeDeposit(address(peanutV4), address(testToken721), 2, 1, 1, pubKeys20);
        // check that the correct number of deposits were made
        assertEq(depositIndexes.length, numDeposits);
    }

    // Test making a batch deposit of ERC1155 tokens
    function testBatchERC1155Deposit() public {
        uint64 numDeposits = 10;
        address[] memory pubKeys20 = new address[](numDeposits);

        for (uint256 i = 0; i < numDeposits; i++) {
            pubKeys20[i] = PUBKEY20;
            // mint a token to the caller
            testToken1155.mint(address(this), 1, 100, "");
            // approve the PeanutV4 contract to spend the tokens
            testToken1155.setApprovalForAll(address(batcher), true);
        }
        // make the batch deposit
        uint256[] memory depositIndexes =
            batcher.batchMakeDeposit(address(peanutV4), address(testToken1155), 3, 1, 1, pubKeys20);
        // check that the correct number of deposits were made
        assertEq(depositIndexes.length, numDeposits);
    }

    // Test failure case where PeanutV4 contract is not approved to spend ERC20 tokens
    function testFailBatchERC20DepositNotApproved() public {
        uint64 amount = 100;
        uint64 numDeposits = 10;
        address[] memory pubKeys20 = new address[](numDeposits);
        for (uint256 i = 0; i < numDeposits; i++) {
            pubKeys20[i] = PUBKEY20;
        }
        // mint tokens to the caller
        testToken.mint(address(this), amount * numDeposits);
        // Do NOT approve the PeanutV4 contract to spend the tokens
        // testToken.approve(address(peanutV4), amount * numDeposits);
        // make the batch deposit
        uint256[] memory depositIndexes =
            batcher.batchMakeDeposit(address(peanutV4), address(testToken), 1, amount, 0, pubKeys20);
        depositIndexes;
    }

    // Test failure case where PeanutV4 contract is not approved to spend ERC721 tokens
    function testFailBatchERC721DepositNotApproved() public {
        uint64 numDeposits = 10;
        address[] memory pubKeys20 = new address[](numDeposits);
        for (uint256 i = 0; i < numDeposits; i++) {
            uint64 tokenId = uint64(i);
            pubKeys20[i] = PUBKEY20;
            // mint a token to the caller
            testToken721.mint(address(this), tokenId);
            // Do NOT approve the PeanutV4 contract to spend the tokens
            // testToken721.approve(address(peanutV4), g);
        }
        // make the batch deposit
        uint256[] memory depositIndexes =
            batcher.batchMakeDeposit(address(peanutV4), address(testToken721), 2, 1, numDeposits, pubKeys20);
        depositIndexes;
    }

    // Test failure case where PeanutV4 contract is not approved to spend ERC1155 tokens
    function testFailBatchERC1155DepositNotApproved() public {
        uint64 numDeposits = 10;
        address[] memory pubKeys20 = new address[](numDeposits);
        for (uint256 i = 0; i < numDeposits; i++) {
            uint64 tokenId = uint64(i);
            pubKeys20[i] = PUBKEY20;
            // mint a token to the caller
            testToken1155.mint(address(this), tokenId, 1, "");

            // Do NOT approve the PeanutV4 contract to spend the tokens
            // testToken1155.setApprovalForAll(address(peanutV4), true);
        }
        // make the batch deposit
        uint256[] memory depositIndexes =
            batcher.batchMakeDeposit(address(peanutV4), address(testToken1155), 3, 1, numDeposits, pubKeys20);
        depositIndexes;
    }

    // Test making multiple batch deposits of ERC20 tokens in a row
    function testMultipleBatchERC20DepositsInRow() public {
        uint64 amount = 100;
        uint64 numDeposits = 10;
        uint64 numberOfBatches = 3; // number of times you want to batch deposit in a row
        address[] memory pubKeys20 = new address[](numDeposits);

        // Set up the pubKeys20 array
        for (uint256 i = 0; i < numDeposits; i++) {
            pubKeys20[i] = PUBKEY20;
        }

        // Iterate over the number of batches you want to create
        for (uint256 batch = 0; batch < numberOfBatches; batch++) {
            // Mint tokens to the caller for this batch
            testToken.mint(address(this), amount * numDeposits);
            testToken.approve(address(batcher), amount * numDeposits);

            // Make the batch deposit
            uint256[] memory depositIndexes =
                batcher.batchMakeDeposit(address(peanutV4), address(testToken), 1, amount, 0, pubKeys20);

            // Check that the correct number of deposits were made
            assertEq(depositIndexes.length, numDeposits);
        }
    }
}

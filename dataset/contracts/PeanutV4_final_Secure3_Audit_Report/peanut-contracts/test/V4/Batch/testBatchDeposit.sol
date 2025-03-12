// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// import "forge-std/Test.sol";
// import "../src/V4/PeanutV4.sol";
// import "../src/util/ERC20Mock.sol";
// import "../src/util/ERC721Mock.sol";
// import "../src/util/ERC1155Mock.sol";

// contract test is Test {
//     PeanutV4 public peanutV4;
//     ERC20Mock public testToken;
//     ERC721Mock public testToken721;
//     ERC1155Mock public testToken1155;

//     // a dummy private/public keypair to test withdrawals
//     address public constant PUBKEY20 =
//         address(0xaBC5211D86a01c2dD50797ba7B5b32e3C1167F9f);
//     bytes32 public constant PRIVKEY = 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;

//     function setUp() public {
//         console.log("Setting up test");
//         peanutV4 = new PeanutV4(address(0));
//         testToken = new ERC20Mock();
//         testToken721 = new ERC721Mock();
//         // testToken1155 = new ERC1155Mock();

//         // Mint tokens for test accounts
//         testToken.mint(address(this), 10000000);
//         testToken721.mint(address(this), 1);
//         // testToken1155.mint(address(this), 1, 1000, "");

//         // Approve PeanutV4 to spend tokens
//         testToken.approve(address(peanutV4), 100000000);
//         testToken721.setApprovalForAll(address(peanutV4), true);
//         // testToken1155.setApprovalForAll(address(peanutV4), true);
//     }

//     function testBatchMakeDeposit() public {
//         address[] memory tokenAddresses = new address[](3);
//         uint8[] memory contractTypes = new uint8[](3);
//         uint256[] memory amounts = new uint256[](3);
//         uint256[] memory tokenIds = new uint256[](3);
//         address[] memory pubKeys20 = new address[](3);

//         // Deposit 1: ERC20
//         tokenAddresses[0] = address(testToken);
//         contractTypes[0] = 1;
//         amounts[0] = 100;
//         tokenIds[0] = 0;
//         pubKeys20[0] = PUBKEY20;

//         // Deposit 2: ERC721
//         tokenAddresses[1] = address(testToken721);
//         contractTypes[1] = 2;
//         amounts[1] = 1;
//         tokenIds[1] = 1;
//         pubKeys20[1] = PUBKEY20;

//         // Deposit 3: Ether
//         tokenAddresses[2] = address(0);
//         contractTypes[2] = 0;
//         amounts[2] = 1 ether;
//         tokenIds[2] = 0;
//         pubKeys20[2] = PUBKEY20;

//         // Moved minting and approval to the setup function
//         uint256[] memory depositIndexes = peanutV4.batchMakeDeposit{value: 1 ether}(
//             tokenAddresses,
//             contractTypes,
//             amounts,
//             tokenIds,
//             pubKeys20
//         );

//         assertEq(depositIndexes.length, 3, "Batch deposit failed");
//         assertEq(peanutV4.getDepositCount(), 3, "Deposit count mismatch");
//     }

//     // fuzzy testing of batchMakeDeposit with varying length of input arrays
//     function testFuzz_BatchMakeDeposit_number(
//         uint8 arrayLength
//     ) public {
//         address[] memory tokenAddresses = new address[](arrayLength);
//         uint8[] memory contractTypes = new uint8[](arrayLength);
//         uint256[] memory amounts = new uint256[](arrayLength);
//         uint256[] memory tokenIds = new uint256[](arrayLength);
//         address[] memory pubKeys20 = new address[](arrayLength);

//         // fill in dummy values for the arrays
//         for (uint256 i = 0; i < arrayLength; i++) {
//             tokenAddresses[i] = address(testToken);
//             contractTypes[i] = 1;
//             amounts[i] = 100;
//             tokenIds[i] = 0;
//             pubKeys20[i] = PUBKEY20;
//         }

//         uint256[] memory depositIndexes = peanutV4.batchMakeDeposit{value: 1 ether}(
//             tokenAddresses,
//             contractTypes,
//             amounts,
//             tokenIds,
//             pubKeys20
//         );

//         assertEq(depositIndexes.length, arrayLength, "Batch deposit failed");
//         assertEq(peanutV4.getDepositCount(), arrayLength, "Deposit count mismatch");
//     }

// }

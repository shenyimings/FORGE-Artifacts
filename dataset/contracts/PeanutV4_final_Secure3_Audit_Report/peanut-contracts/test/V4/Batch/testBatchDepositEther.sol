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

//     // /**
//     //  * @notice Batch ERC20 token deposit
//     //  * @param _tokenAddress address of the token being sent
//     //  * @param _amounts uint256 array of the amounts of tokens being sent
//     //  * @param _pubKeys20 array of the last 20 bytes of the public keys of the deposit signers
//     //  * @return uint256[] array of indices of the deposits
//     //  */
//     // function batchMakeDepositERC20(
//     //     address _tokenAddress,
//     //     uint256[] calldata _amounts,
//     //     address[] calldata _pubKeys20
//     // ) external returns (uint256[] memory) {
//     //     require(
//     //         _amounts.length == _pubKeys20.length,
//     //         "PARAMETERS LENGTH MISMATCH"
//     //     );

//     //     uint256[] memory depositIndexes = new uint256[](_amounts.length);

//     //     for (uint256 i = 0; i < _amounts.length; i++) {
//     //         depositIndexes[i] = makeDeposit(
//     //             _tokenAddress,
//     //             1,
//     //             _amounts[i],
//     //             0,
//     //             _pubKeys20[i]
//     //         );
//     //     }

//     //     return depositIndexes;
//     // }
//     function testBatchMakeDepositEther() public {
//         uint256[] memory amounts = new uint256[](3);
//         address[] memory pubKeys20 = new address[](3);
//         amounts[0] = 100;
//         amounts[1] = 200;
//         amounts[2] = 300;
//         pubKeys20[0] = PUBKEY20;
//         pubKeys20[1] = PUBKEY20;
//         pubKeys20[2] = PUBKEY20;

//         // value should be sum of amounts
//         uint256[] memory depositIndexes = peanutV4.batchMakeDepositEther{value: 600}(
//             amounts,
//             pubKeys20
//         );

//         assertEq(depositIndexes.length, 3, "Batch deposit failed");
//         assertEq(peanutV4.getDepositCount(), 3, "Deposit count mismatch");

//         // console log the deposit indexes
//         for (uint256 i = 0; i < depositIndexes.length; i++) {
//             console.log("Deposit index: %s", depositIndexes[i]);
//         }
//         // console log the deposits themselves
//         for (uint256 i = 0; i < depositIndexes.length; i++) {
//             // print deposit index
//             console.log("    Deposit index: %s", depositIndexes[i]);
//             console.log("Deposit: %s", peanutV4.getDeposit(depositIndexes[i]).pubKey20);
//             console.log("Deposit: %s", peanutV4.getDeposit(depositIndexes[i]).amount);
//             console.log("Deposit: %s", peanutV4.getDeposit(depositIndexes[i]).tokenAddress);
//             console.log("Deposit: %s", peanutV4.getDeposit(depositIndexes[i]).contractType);
//             console.log("Deposit: %s", peanutV4.getDeposit(depositIndexes[i]).tokenId);
//             console.log("Deposit: %s", peanutV4.getDeposit(depositIndexes[i]).senderAddress);
//             console.log("Deposit: %s", peanutV4.getDeposit(depositIndexes[i]).timestamp);
//         }

//     }

//     function testBatchMakeDepositEther100() public {
//     uint256[] memory amounts = new uint256[](100);
//     address[] memory pubKeys20 = new address[](100);
//     uint256 totalValue = 0;

//     // fill the arrays
//     for (uint256 i = 0; i < 100; i++) {
//         amounts[i] = 100; // or any other amount
//         pubKeys20[i] = PUBKEY20; // or any other public key
//         totalValue += amounts[i];
//     }

//     // value should be sum of amounts
//     uint256[] memory depositIndexes = peanutV4.batchMakeDepositEther{value: totalValue}(
//         amounts,
//         pubKeys20
//     );

//     assertEq(depositIndexes.length, 100, "Batch deposit failed");
//     assertEq(peanutV4.getDepositCount(), 100, "Deposit count mismatch");
//     }

//     // // fuzzy testing of batchMakeDeposit with varying length of input arrays
//     // function testFuzz_BatchMakeDeposit_number(
//     //     uint8 arrayLength
//     // ) public {
//     //     address[] memory tokenAddresses = new address[](arrayLength);
//     //     uint8[] memory contractTypes = new uint8[](arrayLength);
//     //     uint256[] memory amounts = new uint256[](arrayLength);
//     //     uint256[] memory tokenIds = new uint256[](arrayLength);
//     //     address[] memory pubKeys20 = new address[](arrayLength);

//     //     // fill in dummy values for the arrays
//     //     for (uint256 i = 0; i < arrayLength; i++) {
//     //         tokenAddresses[i] = address(testToken);
//     //         contractTypes[i] = 1;
//     //         amounts[i] = 100;
//     //         tokenIds[i] = 0;
//     //         pubKeys20[i] = PUBKEY20;
//     //     }

//     //     uint256[] memory depositIndexes = peanutV4.batchMakeDeposit{value: 1 ether}(
//     //         tokenAddresses,
//     //         contractTypes,
//     //         amounts,
//     //         tokenIds,
//     //         pubKeys20
//     //     );

//     //     assertEq(depositIndexes.length, arrayLength, "Batch deposit failed");
//     //     assertEq(peanutV4.getDepositCount(), arrayLength, "Deposit count mismatch");
//     // }

// }

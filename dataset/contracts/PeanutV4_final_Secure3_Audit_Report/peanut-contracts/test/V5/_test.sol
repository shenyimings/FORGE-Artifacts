// SPDX-License-Identifier:
pragma solidity ^0.8.0;

// // import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol"; // for signature verification
// import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
// import "hardhat/console.sol";

// contract TestContract {

//     // sample address
//     address address1 = 0x06222Dd7f30f0d802d764aBa8f0DA48f7FC1d177;
//     // sample messageHash
//     // bytes32 messageHash = keccak256(abi.encodePacked("Hello, world!"));
//     // bytes32 messageHash = "0xe61e57450178cf8fbc58a193220902a251e5e4f235749f69154f6ab3b57026f8";
//     // bytes32 messageHashWPrefix = "0xf017d555ebb61a3e406d18dc960505a6bcddedb6771380c3d7b55f0894268903";
//     // sample signature = 0x37ad61a91644b52b67fd0d3d1ffe5e08a23725bd1cd86a8fea5940fbcf058e2d4decae647500d9f38eb2bd97f32933f2943c5141c9f1a92c06f92eb10ca0ab611b

//     constructor() {
//         console.log("Hello, world!");
//     }

//     function getSigner(bytes32 messageHash, bytes memory signature) public view returns (address) {
//         /* returns the signer of the messageHash using ECDSA recover */
//         address signer = ECDSA.recover(messageHash, signature);
//         console.log("Signer: ", signer);
//         return signer;
//     }

//     function signMessage(bytes32 messageHash) public view returns (bytes memory) {
//         /* signs the messageHash using the address1 private key */
//         bytes memory signature = ECDSA.toEthSignedMessageHash(messageHash).toBytes();
//         console.log("Signature: ", signature);
//         return signature;
//     }

// }

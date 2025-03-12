// SPDX-License-Identifier:
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract TestContract2 {
    // sample address
    address address1 = 0x06222Dd7f30f0d802d764aBa8f0DA48f7FC1d177;

    using ECDSA for bytes32;

    // sample messageHash
    // bytes32 messageHash = keccak256(abi.encodePacked("Hello, world!"));
    // bytes32 messageHash = "0xe61e57450178cf8fbc58a193220902a251e5e4f235749f69154f6ab3b57026f8";
    // bytes32 messageHashWPrefix = "0xf017d555ebb61a3e406d18dc960505a6bcddedb6771380c3d7b55f0894268903";
    // sample signature = 0x37ad61a91644b52b67fd0d3d1ffe5e08a23725bd1cd86a8fea5940fbcf058e2d4decae647500d9f38eb2bd97f32933f2943c5141c9f1a92c06f92eb10ca0ab611b

    constructor() {
        console.log("Hello, world!");
        address address2 = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
        testAddressHash(address2);
    }

    function getSigner(bytes32 messageHash, bytes memory signature) public view returns (address) {
        /* returns the signer of the messageHash using ECDSA recover */
        address signer = ECDSA.recover(messageHash, signature);
        console.log("Signer: ", signer);
        return signer;
    }

    function testHash(bytes20 data) public view returns (bool) {
        bytes32 dataHash = ECDSA.toEthSignedMessageHash(data);
        console.logBytes32(dataHash);
        dataHash = keccak256(abi.encodePacked(data));
        console.logBytes32(dataHash);
        dataHash = ECDSA.toEthSignedMessageHash(keccak256(abi.encodePacked(data)));
        console.logBytes32(dataHash);

        // // cast to string and use hashAddress
        // bytes memory s = abi.encodePacked(data);
        // console.logBytes(s);
        // dataHash = hashAddress(s);
        // console.logBytes32(dataHash);

        return true;
    }

    // hashes the address with ethereum signed message prefix and compares to ethHash
    function testAddressHash(address addr) public view returns (bool) {
        bytes32 hash1 = keccak256(abi.encodePacked(addr));
        bytes32 hash2 = ECDSA.toEthSignedMessageHash(hash1);
        bytes32 hash3 = hash1.toEthSignedMessageHash();
        console.logBytes32(hash1);
        console.logBytes32(hash2);
        console.logBytes32(hash3);
        console.logBytes32(ECDSA.toEthSignedMessageHash(abi.encodePacked(addr)));

        bytes32 temp = 0x5931b4ed56ace4c46b68524cb5bcbf4195f1bbaacbe5228fbd090546c88dd229;
        console.logBytes32(ECDSA.toEthSignedMessageHash(temp));

        // cast addr to bytes20
        bytes20 addrBytes = bytes20(addr);
        console.logBytes32(ECDSA.toEthSignedMessageHash(addrBytes));

        console.log("---------------------");

        // cast addr to string and hash
        bytes memory s = abi.encodePacked(addr);
        bytes32 addrHash = keccak256(s);
        console.logBytes32(addrHash);
        addrHash = ECDSA.toEthSignedMessageHash(addrHash);
        console.logBytes32(addrHash);

        console.log("---------------------");
        console.log("hello world-");

        bytes32 hash = ECDSA.toEthSignedMessageHash(0x5931b4ed56ace4c46b68524cb5bcbf4195f1bbaacbe5228fbd090546c88dd229);
        console.logBytes32(hash);
        console.logBytes32(keccak256(abi.encodePacked(hash)));
        console.log("---------------------");

        // sign with prefix

        // try out different ways to hash the address
        addrHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", "20", addr));
        console.logBytes32(addrHash);
        addrHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", "22", addr));
        console.logBytes32(addrHash);
        addrHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", "42", addr));
        console.logBytes32(addrHash);

        addrHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", "20", abi.encodePacked(addr)));
        console.logBytes32(addrHash);
        addrHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", "20", abi.encodePacked(addr)));
        console.logBytes32(addrHash);
        addrHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", "32", abi.encodePacked(addr)));
        console.logBytes32(addrHash);

        console.logBytes32(keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n20", addr)));
        console.logBytes32(keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", addr)));

        // try using toEthSignedMessageHash
        // cast to bytes memory
        bytes memory s2 = abi.encodePacked(addr);
        addrHash = ECDSA.toEthSignedMessageHash(s2);
        console.logBytes32(addrHash);

        // cast to bytes32 and use toEthSignedMessageHash
        bytes32 addr_32 = bytes32(uint256(uint160(addr)));
        addrHash = ECDSA.toEthSignedMessageHash(addr_32);
        console.logBytes32(addrHash);

        return true;
    }

    // uses ECDSA.toEthSignedMessageHash to hash a string
    function testStringHash(bytes memory str) public view returns (bool) {
        bytes32 strHash = ECDSA.toEthSignedMessageHash(keccak256(abi.encodePacked(str)));
        console.logBytes32(strHash);
        strHash = ECDSA.toEthSignedMessageHash(str);
        console.logBytes32(strHash);
        return true;
    }
}

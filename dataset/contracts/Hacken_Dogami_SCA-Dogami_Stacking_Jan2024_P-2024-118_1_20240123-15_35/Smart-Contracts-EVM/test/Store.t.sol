// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/Store.sol";
import "../src/DOGA.sol";

contract StoreTest is Test {
    Store public store;
    DOGA public doga;
    address recipient;
    address malicious;
    address storeAdmin;
    address storeBuyer;
    address storeReceiver;

    // Tree and Signature
    bytes32 treeRoot =
    0x41bd482a47eebca08827128d53f99d3784c3cd499e79a9fd1cc48e55b7b41508;
    uint8 v = 28;
    bytes32 r =
    0x0ac9c6fd4c2b70b533bf68cedc84c3e47a2bb668bd134c7077f882fba71201bb;
    bytes32 s =
    0x7cd4eb2c75edfe3b48b604a80a616767afb0dbdff146447752edc07378be2698;

    //

    function _getProofForOffer() public pure returns (bytes32[] memory) {
        bytes32[] memory b32Arr = new bytes32[](2);
        b32Arr[
        0
        ] = 0x42ccab20743476d1e58a5a1cbe2b8d82a4d5a1b32838d7709ee297adc4f07d5a;
        b32Arr[
        1
        ] = 0xb4fa4a73becb6faaae92226fc5ebc7775e2740f603af6c28dc442e6e7df08f9a;
        return b32Arr;
    }

    function _getProofForExpiring() public pure returns (bytes32[] memory) {
        bytes32[] memory b32Arr = new bytes32[](2);
        b32Arr[
        0
        ] = 0xceedeba7de756b18e70753448cbb97af912d75127fec8b21fee3692d07f5f927;
        b32Arr[
        1
        ] = 0x41f436764da0cc4b6e7202c78a6261ead112eb00210f21ac407cdd297bc25cb5;
        return b32Arr;
    }

    function setUp() public {
        storeAdmin = address(0x01411285c8f9b3994820caf81CC7887ba4D76949); // Match the private Keys
        storeBuyer = address(0x93E41cC1D3c653c836C6a4664941F50fEA2e9782); // Match the private Keys
        storeReceiver = address(0x75905D7a643057D79aD0C7Bd0f662f1759022638);
        vm.deal(storeAdmin, 1 ether);
        vm.deal(storeBuyer, 1 ether);
        doga = new DOGA("DOGA Token", "DOGA", 1000 * 10 ** 18);
        doga.transfer(storeBuyer, 1000000000000000);
        recipient = address(0x123);
        malicious = address(0x321);
        vm.warp(1698236232);
        store = new Store(storeAdmin, storeReceiver, address(doga));
    }

    function test_signature() public {
        Store.Signature memory sig = Store.Signature({
            v: v,
            r: r,
            s: s
        });
        bool isValid = store.checkSig(storeAdmin, treeRoot, sig);
        assertEq(isValid, true, "Signature is not valid !");
    }

    function test_MerkleProofBasic() public {
        bytes32[] memory proof = _getProofForOffer();
        bool proofValid = store.verifyMerkle("100000000000000|200", proof, treeRoot);
        assertEq(proofValid, true, "Proof is not valid");
    }

    function test_Expiring() public {
        bytes32[] memory proof = _getProofForExpiring();
        bool proofValid = store.verifyMerkle(
            "expire:1698238697",
            proof,
            treeRoot
        );
        assertEq(proofValid, true, "Proof is not valid");
    }

    function test_sendingTreeBeforeExpireShouldWork() public {
        bytes32[] memory proof = _getProofForExpiring();
        bool proofValid = store.checkExpiringTime(
            "expire:1698238697",
            proof,
            treeRoot
        );
        assertEq(proofValid, true, "Proof is not valid");
    }

    function test_sendingTreeAfterExpireShouldRevert() public {
        vm.warp(1796328898); // In the future
        bytes32[] memory proof = _getProofForExpiring();
        vm.expectRevert(ExpiredTimestamp.selector);
        store.checkExpiringTime("expire:1698238697", proof, treeRoot);
        vm.warp(1696328898); // Before expiring
    }

    function test_proceedToBuyAnOffer() public {
        vm.startPrank(storeBuyer);

        Store.Signature memory sig = Store.Signature({
            v: v,
            r: r,
            s: s
        });

        // Create the ValidationData struct
        Store.ValidationData memory data = Store.ValidationData({
            expiringTime: "expire:1698238697",
            expiringProof: _getProofForExpiring(),
            offer: "100000000000000|200",
            offerProof: _getProofForOffer(),
            merkleRoot: treeRoot
        });

        doga.approve(address(store), 100000000000000);

        store.proceedToBuy("userid", data, sig);

        uint transferred = doga.balanceOf(storeReceiver);
        assertEq(transferred, 100000000000000, "Amount was not transferred");

        vm.stopPrank();
    }


    function test_proceedToBuyAnOffer_wrongValue() public {
        vm.startPrank(storeBuyer);
        bytes32[] memory proofExpire = _getProofForExpiring();
        bytes32[] memory proofOrder = _getProofForOffer();
        doga.approve(address(store), 100000000000000);
        vm.expectRevert(InvalidProof.selector);

        Store.Signature memory sig = Store.Signature({
            v: v,
            r: r,
            s: s
        });

        // Create the ValidationData struct
        Store.ValidationData memory data = Store.ValidationData({
            expiringTime: "expire:1998237232", // Wrong value
            expiringProof: _getProofForExpiring(),
            offer: "100000000000000|200",
            offerProof: _getProofForOffer(),
            merkleRoot: treeRoot
        });

        store.proceedToBuy("userid", data, sig);

        vm.stopPrank();
    }

    function test_proceedToBuyAnOffer_wrongProof() public {
        vm.startPrank(storeBuyer);
        Store.Signature memory sig = Store.Signature({
            v: v,
            r: r,
            s: s
        });

        Store.ValidationData memory data = Store.ValidationData({
            expiringTime: "expire:1698238697",
            expiringProof: _getProofForOffer(),// Wrong value
            offer: "100000000000000|200",
            offerProof: _getProofForOffer(),
            merkleRoot: treeRoot
        });

        doga.approve(address(store), 100000000000000);
        vm.expectRevert(InvalidProof.selector);
        store.proceedToBuy("userid", data, sig);

        vm.stopPrank();

    }

    function test_pausingTheContractShouldBlockTheBuy() public {
        vm.startPrank(storeAdmin);
        store.pause();
        vm.startPrank(storeBuyer);
        Store.Signature memory sig = Store.Signature({
            v: v,
            r: r,
            s: s
        });

        Store.ValidationData memory data = Store.ValidationData({
            expiringTime: "expire:1698238697",
            expiringProof: _getProofForExpiring(),
            offer: "100000000000000|200",
            offerProof: _getProofForOffer(),
            merkleRoot: treeRoot
        });
        vm.expectRevert();
        store.proceedToBuy("userid", data, sig);

        vm.stopPrank();

    }

    function test_unpausingTheContractAfterAPauseShouldWork() public {
        vm.startPrank(storeAdmin);
        store.pause();
        store.unpause();
        vm.startPrank(storeBuyer);
        Store.Signature memory sig = Store.Signature({
            v: v,
            r: r,
            s: s
        });

        Store.ValidationData memory data = Store.ValidationData({
            expiringTime: "expire:1698238697",
            expiringProof: _getProofForExpiring(),
            offer: "100000000000000|200",
            offerProof: _getProofForOffer(),
            merkleRoot: treeRoot
        });
        doga.approve(address(store), 100000000000000);
        store.proceedToBuy("userid", data, sig);
        vm.stopPrank();

    }
}

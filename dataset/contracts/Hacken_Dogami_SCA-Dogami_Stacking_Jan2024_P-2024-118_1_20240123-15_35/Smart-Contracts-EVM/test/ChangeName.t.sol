// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/ChangeName.sol";
import "../src/DOGA.sol";
import "../src/DOGAMI_MetaTxs.sol";

contract ChangeNameTest is Test {
    ChangeName public store;
    DOGA public doga;
    DOGAMI_MetaTxs public dogami;
    address recipient;
    address malicious;
    address storeAdmin;
    address storeBuyer;
    address storeReceiver;

    // Tree and Signature
    bytes32 treeRoot = 0xd31fb517bc34c524e8b5f7e73a70d93bd37ae8030777810ed646ab6218dd8c5a;
    uint8 v = 28;
    bytes32 r = 0x735f29e9018361815ecb18d56c568b818a81258c31589404775382f70497921f;
    bytes32 s = 0x07514de12a8568a46f34dee4d6653f039ba7d4b6f8d0b6ed1b8693dd49b2631b;

    function _getProofForOffer() public pure returns (bytes32[] memory) {
        bytes32[] memory b32Arr = new bytes32[](2);
        b32Arr[0] = 0xd63087bea9f1800eed943829fc1d61e7869764805baa3259078c1caf3d4f5a48;
        b32Arr[1] = 0x2a94fa07b04ed40a3c6675bc03c6e1b616349258a073f2855c2564fe28fa5596;
        return b32Arr;
    }

    function _getProofForExpiring() public pure returns (bytes32[] memory) {
        bytes32[] memory b32Arr = new bytes32[](2);
        b32Arr[0] = 0x10257b4b78eb1cc8f3bf37ee4ac776bf13f9a94a6698f944882b60d3d834a8aa;
        b32Arr[1] = 0xe65cdeb3c6da0c568e56708a93775de10110f6a4b4330aaf8c8f3e3f2af44393;
        return b32Arr;
    }

    function setUp() public {
        storeAdmin = address(0x01411285c8f9b3994820caf81CC7887ba4D76949);
        storeBuyer = address(0x93E41cC1D3c653c836C6a4664941F50fEA2e9782);
        storeReceiver = address(0x75905D7a643057D79aD0C7Bd0f662f1759022638);
        vm.deal(storeAdmin, 1 ether);
        vm.deal(storeBuyer, 1 ether);
        doga = new DOGA("DOGA Token", "DOGA", 1000 * 10 ** 18);
        doga.transfer(storeBuyer, 1000);
        recipient = address(0x123);
        malicious = address(0x321);
        vm.warp(1696328898);
        dogami = new DOGAMI_MetaTxs("MyNFT", "NFT", "https://my-nft.com/", "https://my-nft-contract.com/", storeAdmin, address(0x0));

        store = new ChangeName(address(dogami), 1, 20, " -abcdefghijklmnopqrstuvwxyz", storeReceiver, address(doga), storeAdmin);
    }

    function test_pause() public {
        vm.startPrank(storeAdmin);
        store.pause();
        vm.stopPrank();
        assertEq(store.paused(), true, "Store is not paused");
    }

    function test_unpause() public {
        vm.startPrank(storeAdmin);
        store.pause();
        store.unpause();
        vm.stopPrank();
        assertEq(store.paused(), false, "Store is still paused");
    }

    function test_setStoreReceiver() public {
        address expectedReceiver = address(0x123);
        vm.startPrank(storeAdmin);
        store.setStoreReceiver(expectedReceiver);
        vm.stopPrank();
        assertEq(store.storeReceiver(), expectedReceiver, "Store receiver address is not set correctly");
    }

    function test_setPaymentTokenAddress() public {
        address expectedTokenAddress = address(0x456);
        vm.startPrank(storeAdmin);
        store.setPaymentTokenAddress(expectedTokenAddress);
        vm.stopPrank();
        assertEq(store.paymentTokenAddress(), expectedTokenAddress, "Payment token address is not set correctly");
    }

    function test_setNFTContractAddress() public {
        address expectedNFTAddress = address(0x789);
        vm.startPrank(storeAdmin);
        store.setNFTContractAddress(expectedNFTAddress);
        vm.stopPrank();
        assertEq(address(store.nftContract()), expectedNFTAddress, "NFT contract address is not set correctly");
    }

    function test_setNameLengths_valid() public {
        uint8 expectedMinLength = 1;
        uint8 expectedMaxLength = 10;
        vm.startPrank(storeAdmin);
        store.setNameLengths(expectedMinLength, expectedMaxLength);
        vm.stopPrank();
        assertEq(store.minLength(), expectedMinLength, "Min length is not set correctly");
        assertEq(store.maxLength(), expectedMaxLength, "Max length is not set correctly");
    }

    function test_setNameLengths_invalid() public {
        uint8 invalidMinLength = 11;
        uint8 invalidMaxLength = 10;
        vm.startPrank(storeAdmin);
        vm.expectRevert("Min length should be less than or equal to max length");
        store.setNameLengths(invalidMinLength, invalidMaxLength);
        vm.stopPrank();
    }

    function test_setAllowedCharacters() public {
        bytes memory expectedCharacters = "abcdef";
        vm.startPrank(storeAdmin);
        store.setAllowedCharacters(expectedCharacters);
        assertEq(store.allowedCharacters(), expectedCharacters, "Allowed characters are not set correctly");

        bytes memory expectedCharacters2 = "ghijkl";
        store.setAllowedCharacters(expectedCharacters2);
        assertEq(store.allowedCharacters(), expectedCharacters2, "Allowed characters are not set correctly");
        vm.stopPrank();
    }

    function test_signature() public {
        ChangeName.Signature memory sig = ChangeName.Signature({
            v: v,
            r: r,
            s: s
        });
        bool isValid = store.checkSig(storeAdmin, treeRoot, sig);
        assertEq(isValid, true, "Signature is not valid !");
    }

    function test_MerkleProofBasic() public {
        bytes32[] memory proof = _getProofForOffer();
        bool proofValid = store.verifyMerkle(
            "100",
            proof,
            treeRoot
        );
        assertEq(proofValid, true, "Proof is not valid");
    }

    function test_Expiring() public {
        bytes32[] memory proof = _getProofForExpiring();
        bool proofValid = store.verifyMerkle(
            "expire:1696338684",
            proof,
            treeRoot
        );
        assertEq(proofValid, true, "Proof is not valid");
    }

    function test_sendingTreeBeforeExpireShouldWork() public {
        bytes32[] memory proof = _getProofForExpiring();
        bool proofValid = store.checkExpiringTime(
            "expire:1696338684",
            proof,
            treeRoot
        );
        assertEq(proofValid, true, "Proof is not valid");
    }

    function test_sendingTreeAfterExpireShouldRevert() public {
        vm.warp(1796328898); // In the future
        bytes32[] memory proof = _getProofForExpiring();
        vm.expectRevert(ExpiredTimestamp.selector);
        store.checkExpiringTime(
            "expire:1696338684",
            proof,
            treeRoot
        );
        vm.warp(1696328898); // Before expiring
    }

    function test_proceedToBuyAnOffer() public {
        vm.startPrank(storeAdmin);
        dogami.mintTo(storeBuyer);
        vm.stopPrank();

        vm.startPrank(storeBuyer);
        string memory name = "sample na-me";
        uint32 tokenId = 1;
        ChangeName.Signature memory sig = ChangeName.Signature({v: v, r: r, s: s});
        ChangeName.ValidationData memory data = ChangeName.ValidationData({
            expiringTime: "expire:1696338684",
            expiringProof: _getProofForExpiring(),
            offer: "100",
            offerProof: _getProofForOffer(),
            merkleRoot: treeRoot
        });
        doga.approve(address(store), 100);
        store.proceedToBuy(name, tokenId, data, sig);

        uint transferred = doga.balanceOf(storeReceiver);
        assertEq(transferred, 100, "Amount was not transferred");
        vm.stopPrank();
    }

    function test_proceedToBuyAnOffer_wrongName() public {
        vm.startPrank(storeAdmin);
        dogami.mintTo(storeBuyer);
        vm.stopPrank();

        vm.startPrank(storeBuyer);
        string memory name = "samplename_2";
        uint32 tokenId = 1;
        ChangeName.Signature memory sig = ChangeName.Signature({v: v, r: r, s: s});
        ChangeName.ValidationData memory data = ChangeName.ValidationData({
            expiringTime: "expire:1696338684",
            expiringProof: _getProofForExpiring(),
            offer: "100",
            offerProof: _getProofForOffer(),
            merkleRoot: treeRoot
        });
        doga.approve(address(store), 100);
        vm.expectRevert("Invalid character in name");
        store.proceedToBuy(name, tokenId, data, sig);
        vm.stopPrank();
    }

    function test_proceedToBuyAnOffer_nameTooLong() public {
        vm.startPrank(storeAdmin);
        dogami.mintTo(storeBuyer);
        vm.stopPrank();

        vm.startPrank(storeBuyer);
        string memory name = "samplenamethedestroyerofworlds";
        uint32 tokenId = 1;
        ChangeName.Signature memory sig = ChangeName.Signature({v: v, r: r, s: s});
        ChangeName.ValidationData memory data = ChangeName.ValidationData({
            expiringTime: "expire:1696338684",
            expiringProof: _getProofForExpiring(),
            offer: "100",
            offerProof: _getProofForOffer(),
            merkleRoot: treeRoot
        });
        doga.approve(address(store), 100);
        vm.expectRevert("Invalid name length");
        store.proceedToBuy(name, tokenId, data, sig);
        vm.stopPrank();
    }

    function test_proceedToBuyAnOffer_nftNotOwner() public {
        vm.startPrank(storeAdmin);
        dogami.mintTo(storeAdmin); // mint to admin instead of buyer
        vm.stopPrank();

        vm.startPrank(storeBuyer);
        string memory name = "sample na-me";
        uint32 tokenId = 1;
        ChangeName.Signature memory sig = ChangeName.Signature({v: v, r: r, s: s});
        ChangeName.ValidationData memory data = ChangeName.ValidationData({
            expiringTime: "expire:1696338684",
            expiringProof: _getProofForExpiring(),
            offer: "100",
            offerProof: _getProofForOffer(),
            merkleRoot: treeRoot
        });
        doga.approve(address(store), 100);
        vm.expectRevert("Caller is not the owner of the NFT");
        store.proceedToBuy(name, tokenId, data, sig);
        vm.stopPrank();
    }

    function test_proceedToBuyAnOffer_wrongValue() public {
        vm.startPrank(storeAdmin);
        dogami.mintTo(storeBuyer);
        vm.stopPrank();

        vm.startPrank(storeBuyer);
        string memory name = "sample na-me";
        uint32 tokenId = 1;
        ChangeName.Signature memory sig = ChangeName.Signature({v: v, r: r, s: s});
        ChangeName.ValidationData memory data = ChangeName.ValidationData({
            expiringTime: "expire:1696338684",
            expiringProof: _getProofForExpiring(),
            offer: "80",
            offerProof: _getProofForOffer(),
            merkleRoot: treeRoot
        });
        doga.approve(address(store), 100);
        vm.expectRevert();
        store.proceedToBuy(name, tokenId, data, sig);
        vm.stopPrank();
    }

    function test_proceedToBuyAnOffer_wrongExpiring() public {
        vm.startPrank(storeAdmin);
        dogami.mintTo(storeBuyer);
        vm.stopPrank();

        vm.startPrank(storeBuyer);
        string memory name = "sample na-me";
        uint32 tokenId = 1;
        ChangeName.Signature memory sig = ChangeName.Signature({v: v, r: r, s: s});
        ChangeName.ValidationData memory data = ChangeName.ValidationData({
            expiringTime: "expire:1896338684", // Wrong value
            expiringProof: _getProofForExpiring(),
            offer: "100",
            offerProof: _getProofForOffer(),
            merkleRoot: treeRoot
        });
        doga.approve(address(store), 100);
        vm.expectRevert(InvalidProof.selector);
        store.proceedToBuy(name, tokenId, data, sig);
        vm.stopPrank();
    }

    function test_proceedToBuyAnOffer_wrongProof() public {
        vm.startPrank(storeAdmin);
        dogami.mintTo(storeBuyer);
        vm.stopPrank();

        vm.startPrank(storeBuyer);
        string memory name = "sample na-me";
        uint32 tokenId = 1;
        ChangeName.Signature memory sig = ChangeName.Signature({v: v, r: r, s: s});
        ChangeName.ValidationData memory data = ChangeName.ValidationData({
            expiringTime: "expire:1696338684",
            expiringProof: _getProofForOffer(), // Wrong value
            offer: "100",
            offerProof: _getProofForOffer(),
            merkleRoot: treeRoot
        });
        doga.approve(address(store), 100);
        vm.expectRevert(InvalidProof.selector);
        store.proceedToBuy(name, tokenId, data, sig);
        vm.stopPrank();
    }

    function test_pausingTheContractShouldBlockTheBuy() public {
        vm.startPrank(storeAdmin);
        store.pause();
        dogami.mintTo(storeBuyer);
        vm.stopPrank();

        vm.startPrank(storeBuyer);
        string memory name = "sample na-me";
        uint32 tokenId = 1;
        ChangeName.Signature memory sig = ChangeName.Signature({v: v, r: r, s: s});
        ChangeName.ValidationData memory data = ChangeName.ValidationData({
            expiringTime: "expire:1696338684",
            expiringProof: _getProofForExpiring(),
            offer: "100",
            offerProof: _getProofForOffer(),
            merkleRoot: treeRoot
        });
        doga.approve(address(store), 100);
        vm.expectRevert();
        store.proceedToBuy(name, tokenId, data, sig);
        vm.stopPrank();
    }

    function test_unpausingTheContractAfterAPauseShouldWork() public {
        vm.startPrank(storeAdmin);
        store.pause();
        store.unpause();
        dogami.mintTo(storeBuyer);
        vm.stopPrank();

        vm.startPrank(storeBuyer);
        string memory name = "sample na-me";
        uint32 tokenId = 1;
        ChangeName.Signature memory sig = ChangeName.Signature({v: v, r: r, s: s});
        ChangeName.ValidationData memory data = ChangeName.ValidationData({
            expiringTime: "expire:1696338684",
            expiringProof: _getProofForExpiring(),
            offer: "100",
            offerProof: _getProofForOffer(),
            merkleRoot: treeRoot
        });
        doga.approve(address(store), 100);
        store.proceedToBuy(name, tokenId, data, sig);

        uint transferred = doga.balanceOf(storeReceiver);
        assertEq(transferred, 100, "Amount was not transferred");
        vm.stopPrank();
    }
}

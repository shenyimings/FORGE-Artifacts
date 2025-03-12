// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/DOGAMI_MetaTxs.sol";
import "../src/DOGAMI_Relayer.sol";

contract NFTTest is Test {DOGAMI_MetaTxs public dogami;
    DOGAMI_Relayer public dogamiRelayer;
    address NFTAdmin;
    address recipient;
    address hacker;
    address nonCrypto;
    uint256 nonCryptoPrivate;

    function setUp() public {nonCryptoPrivate = 321;
        nonCrypto = vm.addr(nonCryptoPrivate);
        NFTAdmin = address(0x01411285c8f9b3994820caf81CC7887ba4D76949);
        vm.deal(NFTAdmin, 1 ether);
        recipient = address(0x123);
        vm.deal(recipient, 1 ether);
        hacker = address(0x666);
        dogamiRelayer = new DOGAMI_Relayer("DOGAMI_RELAYER", address(NFTAdmin));
        dogami = new DOGAMI_MetaTxs("MyNFT", "NFT", "https://my-nft.com/", "https://my-nft-contract.com/", address(NFTAdmin), address(dogamiRelayer));}

    function test_Mint_to_as_owner_should_pass() public {vm.startPrank(NFTAdmin);
        uint256 expectedTokenId = 1;
        uint256 actualTokenId = dogami.mintTo(recipient);

        assertEq(actualTokenId, expectedTokenId, "Token ID does not match");
        assertEq(dogami.ownerOf(expectedTokenId), recipient, "Owner does not match");
        assertEq(dogami.balanceOf(recipient), 1, "Balance does not match");}

    function test_Mint_to_as_non_owner_should_fail() public {vm.startPrank(hacker);
        vm.expectRevert();
        dogami.mintTo(recipient);
        vm.stopPrank();}


    function test_TokenURI_should_match_expected() public {vm.startPrank(NFTAdmin);
        uint256 tokenId = dogami.mintTo(recipient);
        string memory expectedURI = "https://my-nft.com/1";
        string memory actualURI = dogami.tokenURI(tokenId);
        assertEq(actualURI, expectedURI, "Token URI does not match");}

    function test_Admin_Should_Update_ContractURI() public {vm.startPrank(NFTAdmin);
        dogami.setContractURI("https://new-url/");
        string memory actualURI = dogami.contractURI();
        assertEq(actualURI, "https://new-url/");}

    function test_Admin_Should_Update_TokenURI() public {vm.startPrank(NFTAdmin);
        uint256 tokenId = dogami.mintTo(recipient);
        dogami.setBaseURI("https://new-url-token/");
        string memory expectedURI = "https://new-url-token/1";
        string memory actualURI = dogami.tokenURI(tokenId);
        assertEq(actualURI, expectedURI);}

    function test_Transfer_as_DOGAMI_owner_should_pass() public {vm.startPrank(NFTAdmin);
        dogami.mintTo(recipient);
        vm.deal(recipient, 1 ether);
        vm.startPrank(recipient);
        address receiver = address(0x321);
        assertEq(dogami.balanceOf(recipient), 1, "Balance does not match");
        dogami.transferFrom(recipient, receiver, 1);
        assertEq(dogami.balanceOf(receiver), 1, "Balance of receiver should be one");
        vm.stopPrank();}

    function test_Transfer_Ownership_and_mint_NFTs() public {vm.startPrank(NFTAdmin);
        address newOwner = address(0x312);
        dogami.transferOwnership(newOwner);
        vm.deal(newOwner, 1 ether);
        vm.startPrank(newOwner);
        uint256 tokenId = dogami.mintTo(recipient);
        assertEq(tokenId, 1);}

    function test_pausingTheContractShouldBlockTheTransfer() public {vm.startPrank(NFTAdmin);
        dogami.pause();
        uint token = dogami.mintTo(recipient);
        vm.startPrank(recipient);
        vm.expectRevert();
        dogami.transferFrom(recipient, hacker, token);
        vm.stopPrank();}

    function test_unpausingTheContractAfterAPauseShouldWork() public {vm.startPrank(NFTAdmin);
        dogami.pause();
        // Pausing should not block the mint
        uint token = dogami.mintTo(recipient);
        dogami.unpause();
        vm.startPrank(recipient);
        dogami.transferFrom(recipient, hacker, token);
        vm.stopPrank();}

}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/*
 test command:
 forge test --via-ir --fork-url https://mainnet.infura.io/v3/7b367f3e8f1d48e5b43e1b290a1fde16
*/

import "forge-std/Test.sol";

//Frens Contracts
import "../../contracts/FrensArt.sol";
import "../../contracts/FrensMetaHelper.sol";
import "../../contracts/FrensPoolShareTokenURI.sol";
import "../../contracts/FrensStorage.sol";
import "../../contracts/StakingPool.sol";
import "../../contracts/StakingPoolFactory.sol";
import "../../contracts/FrensPoolShare.sol";
import "../../contracts/interfaces/IStakingPoolFactory.sol";
import "../../contracts/interfaces/IDepositContract.sol";
import "./TestHelper.sol";
import "../../contracts/FrensOracle.sol";


contract MiscTest is Test {
    FrensArt public frensArt;
    FrensMetaHelper public frensMetaHelper;
    FrensPoolShareTokenURI public frensPoolShareTokenURI;
    FrensStorage public frensStorage;
    StakingPoolFactory public stakingPoolFactory;
    StakingPool public stakingPool;
    StakingPool public stakingPool2;
    FrensPoolShare public frensPoolShare;
    FrensOracle public frensOracle;

    //mainnet
    address payable public depCont = payable(0x00000000219ab540356cBB839Cbe05303d7705Fa);
    //goerli
    //address payable public depCont = payable(0xff50ed3d0ec03aC01D4C79aAd74928BFF48a7b2b);
    address public ssvRegistryAddress = 0xb9e155e65B5c4D66df28Da8E9a0957f06F11Bc04;
    address public ENSAddress = 0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e;

    IDepositContract depositContract = IDepositContract(depCont);

    address public contOwner = 0x0000000000000000000000000000000001111738;
    address payable public alice = payable(0x00000000000000000000000000000000000A11cE);
    address payable public bob = payable(0x0000000000000000000000000000000000000B0b);

    bytes pubkey = hex"ac542dcb86a85a8deeef9150dbf8ad24860a066deb43b20294ed7fb65257f49899b7103c35b26289035de4227e1cc575";
    bytes withdrawal_credentials = hex"0100000000000000000000004f81992fce2e1846dd528ec0102e6ee1f61ed3e2";
    bytes signature = hex"92e3289be8c1379caae22fa1d6637c3953620db6eed35d1861b9bb9f0133be8b0cc631d16a3f034960fb826977138c59023543625ecb863cb5a748714ff5ee9f3286887e679cf251b6b0f14b190beac1ad7010cc136da6dd9e98dd4e8b7faae9";
    bytes32 deposit_data_root = 0x4093180202063b0e66cd8aef5a934bfabcf32919e494064542b5f1a3889bf516;


        function setUp() public {
      //deploy storage
      frensStorage = new FrensStorage();
      //initialise SSVRegistry
      frensStorage.setAddress(keccak256(abi.encodePacked("external.contract.address", "SSVRegistry")), ssvRegistryAddress);
      //initialise deposit Contract
      frensStorage.setAddress(keccak256(abi.encodePacked("external.contract.address", "DepositContract")), depCont);
      //initialise ENS 
      frensStorage.setAddress(keccak256(abi.encodePacked("external.contract.address", "ENS")), ENSAddress);
      //deploy NFT contract
      frensPoolShare = new FrensPoolShare(frensStorage);
      //initialise NFT contract
      frensStorage.setAddress(keccak256(abi.encodePacked("contract.address", "FrensPoolShare")), address(frensPoolShare));
      //deploy Factory
      stakingPoolFactory = new StakingPoolFactory(frensStorage);
      //initialise Factory
      frensStorage.setAddress(keccak256(abi.encodePacked("contract.address", "StakingPoolFactory")), address(stakingPoolFactory));
      frensPoolShare.grantRole(bytes32(0x00),  address(stakingPoolFactory));
      //deploy FrensOracle
      frensOracle = new FrensOracle(frensStorage);
      //initialise FrensOracle
      frensStorage.setAddress(keccak256(abi.encodePacked("contract.address", "FrensOracle")), address(frensOracle));
      //deploy MetaHelper
      frensMetaHelper = new FrensMetaHelper(frensStorage);
      //initialise Metahelper
      frensStorage.setAddress(keccak256(abi.encodePacked("contract.address", "FrensMetaHelper")), address(frensMetaHelper));
      //deploy TokenURI
      frensPoolShareTokenURI = new FrensPoolShareTokenURI(frensStorage);
      //Initialise TokenURI
      frensStorage.setAddress(keccak256(abi.encodePacked("contract.address", "FrensPoolShareTokenURI")), address(frensPoolShareTokenURI));
      //deployArt
      frensArt = new FrensArt(frensStorage);
      //initialise art
      frensStorage.setAddress(keccak256(abi.encodePacked("contract.address", "FrensOracle")), address(frensOracle));
      //set contracts as deployed
     
      //create staking pool through proxy contract
      (address pool) = stakingPoolFactory.create(contOwner, false/*, false, 0, 32000000000000000000*/);
      //connect to staking pool
      stakingPool = StakingPool(payable(pool));
      //console.log the pool address for fun  if(FrensPoolShareOld == 0){
      //console.log("pool", pool);

      //create a second staking pool
      (address pool2) = stakingPoolFactory.create(contOwner, false/*, false, 0, 32000000000000000000*/);
      //connect to staking pool
      stakingPool2 = StakingPool(payable(pool2));
      //console.log the pool address for fun  if(FrensPoolShareOld == 0){
      //console.log("pool2", pool2);

    }

    function testMintingDirectly() public {
      hoax(alice);
      vm.expectRevert("you are not allowed to mint");
      frensPoolShare.mint(address(alice));
    }

    function testApprove() public {
      startHoax(alice);
      uint i = 0;
      while( i < 255 ){ //255 is arbitrarily chosen, the point is to check a few different values.
        stakingPool.depositToPool{value: 1}();
 
        uint id = frensPoolShare.tokenOfOwnerByIndex(alice, i);
        assertTrue(id == i );

        address shouldBeZero = frensPoolShare.getApproved(i);
        assertEq(address(0), shouldBeZero);

        frensPoolShare.approve(bob, i);
        address shouldBeBob = frensPoolShare.getApproved(i);
        assertEq(bob, shouldBeBob);
        i++;
      }
    }

    function testBalanceOf() public {
      startHoax(alice);
      uint i = 0;
      while( i < 255 ){
        stakingPool.depositToPool{value: 1}();
        uint id = frensPoolShare.tokenOfOwnerByIndex(alice, i);
        assertTrue(id == i, "first is is 0");
        uint balanceOfAlice = frensPoolShare.balanceOf(alice);
        assertEq(balanceOfAlice, i + 1, "should have i + 1");
        i++;
      }
    }

    function testexists() public {
      startHoax(alice);
      
      uint i = 0;
       while( i < 255 ){
        assertFalse(frensPoolShare.exists(i));
        stakingPool.depositToPool{value: 1}();
        assertTrue(frensPoolShare.exists(i));
        i++;
      }
      
    }

    function testGetPoolById() public {
      startHoax(alice);
      uint i = 0;
      while( i < 255 ){
        stakingPool.depositToPool{value: 1}();
        address sbStakingPool = frensPoolShare.getPoolById(i);
        assertEq(address(stakingPool), sbStakingPool);
        i++;
        stakingPool2.depositToPool{value: 1}();
        address sbStakingPool2 = frensPoolShare.getPoolById(i);
        assertEq(address(stakingPool2), sbStakingPool2);
        i++;
        stakingPool.depositToPool{value: 1}(); //one more to throw off the even/odd thing for fun
        sbStakingPool = frensPoolShare.getPoolById(i);
        assertEq(address(stakingPool), sbStakingPool);
        i++; 
      }
    }

    function testIsApprovedForAll() public {
      startHoax(alice);
      uint i = 0;
      while( i < 64 ){
        stakingPool.depositToPool{value: 1}();
        i++;
      }
      assertFalse(frensPoolShare.isApprovedForAll(alice, bob));
      frensPoolShare.setApprovalForAll(bob, true);
      assertTrue(frensPoolShare.isApprovedForAll(alice, bob));
    }

    function testOwner() public {
      assertEq(address(this), frensPoolShare.owner());
      hoax(alice);
      vm.expectRevert("Ownable: caller is not the owner");
      frensPoolShare.transferOwnership(bob);
      hoax(address(this));
      frensPoolShare.transferOwnership(bob);
      assertEq(bob, frensPoolShare.owner());
    }

    function testOwnerOf() public {
      uint i = 0;
      while( i < 255 ){
        hoax(alice);
        stakingPool.depositToPool{value: 1}();
        address sbAlice = frensPoolShare.ownerOf(i);
        assertEq(alice, sbAlice);
        i++;
        hoax(bob);
        stakingPool2.depositToPool{value: 1}();
        address sbBob = frensPoolShare.ownerOf(i);
        assertEq(bob, sbBob);
        i++;
        hoax(bob);
        stakingPool.depositToPool{value: 1}(); //one more to throw off the even/odd thing for fun
        sbBob = frensPoolShare.ownerOf(i);
        assertEq(bob, sbBob);
        i++; 
      }
    }

    function testSafeTransferFrom() public {
      hoax(alice);
      stakingPool.depositToPool{value: 1}();
      uint id = frensPoolShare.tokenOfOwnerByIndex(alice, 0);
      assertEq(alice, frensPoolShare.ownerOf(id));
      hoax(bob);
      vm.expectRevert("ERC721: caller is not token owner or approved");
      frensPoolShare.safeTransferFrom(alice, bob, id);
      hoax(alice);
      frensPoolShare.safeTransferFrom(alice, bob, id);
      assertEq(bob, frensPoolShare.ownerOf(id));
      hoax(bob);
      vm.expectRevert("ERC721: transfer to non ERC721Receiver implementer");
      frensPoolShare.safeTransferFrom(bob, address(frensStorage), id);

      NftReceiver nftReceiver = new NftReceiver();
      hoax(bob);
      frensPoolShare.safeTransferFrom(bob, address(nftReceiver), id);
      assertEq(address(nftReceiver), frensPoolShare.ownerOf(id));

    }

    function testTokenByIndex() public {
      startHoax(alice);
      uint i = 0;
      while( i < 255 ){
        stakingPool.depositToPool{value: 1}();
        uint id = frensPoolShare.tokenByIndex(i);
        assertTrue(id == i );
        i++;
      }
    }

    function testTransferFrom() public {
      hoax(alice);
      stakingPool.depositToPool{value: 1}();
      uint id = frensPoolShare.tokenOfOwnerByIndex(alice, 0);
      assertEq(alice, frensPoolShare.ownerOf(id));
      hoax(bob);
      vm.expectRevert("ERC721: caller is not token owner or approved");
      frensPoolShare.transferFrom(alice, bob, id);
      hoax(alice);
      frensPoolShare.transferFrom(alice, bob, id);
      
    }

  function testUnauthorizedAccess() public {
    startHoax(alice);
    vm.expectRevert("you are not allowed to mint");
    frensPoolShare.mint(alice);
    vm.expectRevert("AccessControl: account 0x00000000000000000000000000000000000a11ce is missing role 0x0000000000000000000000000000000000000000000000000000000000000000");
    frensPoolShare.grantRole(keccak256("MINTER_ROLE"), alice);
    vm.expectRevert("AccessControl: account 0x00000000000000000000000000000000000a11ce is missing role 0x0000000000000000000000000000000000000000000000000000000000000000");
    frensPoolShare.grantRole(bytes32(0x00), alice);
  }


}

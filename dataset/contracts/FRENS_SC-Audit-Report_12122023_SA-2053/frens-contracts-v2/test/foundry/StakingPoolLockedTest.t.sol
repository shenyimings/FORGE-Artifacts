// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

//Frens Contracts
import "../../contracts/FrensArt.sol";
import "../../contracts/FrensMetaHelper.sol";
import "../../contracts/FrensPoolShareTokenURI.sol";
import "../../contracts/FrensStorage.sol";
import "../../contracts/StakingPool.sol";
import "../../contracts/StakingPoolFactory.sol";
import "../../contracts/FrensOracle.sol";
import "../../contracts/FrensPoolShare.sol";
import "../../contracts/interfaces/IStakingPoolFactory.sol";
import "../../contracts/interfaces/IDepositContract.sol";

contract StakingPoolLockedTest is Test {
    FrensArt public frensArt;
    FrensMetaHelper public frensMetaHelper;
    FrensPoolShareTokenURI public frensPoolShareTokenURI;
    FrensStorage public frensStorage;
    StakingPoolFactory public stakingPoolFactory;
    StakingPool public stakingPool;
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
      (address pool) = stakingPoolFactory.create(contOwner, true/*, false, 0, 32000000000000000000*/);
      //connect to staking pool
      stakingPool = StakingPool(payable(pool));
      //console.log the pool address for fun  if(FrensPoolShareOld == 0){
      //console.log("pool", pool);

    }

    function testOwner() public {
      address stakingPoolOwner = stakingPool.owner();
      assertEq(stakingPoolOwner, address(contOwner));
    }

    function testDeposit(uint72 x) public {
      //test pool lock
      vm.expectRevert("not accepting deposits");
      hoax(alice);
      stakingPool.depositToPool{value: 1}();
      //set pubKey
      hoax(contOwner);
      stakingPool.setPubKey(pubkey, withdrawal_credentials, signature, deposit_data_root);
      if(x > 0 && x <= 32 ether){
        startHoax(alice);
        stakingPool.depositToPool{value: x}();
        uint id = frensPoolShare.tokenOfOwnerByIndex(alice, 0);
        assertTrue(id == 0, "first id is 0");
        uint depAmt = stakingPool.depositForId(id);
        assertEq(x, depAmt);
        uint totDep = stakingPool.totalDeposits();
        assertEq(x, totDep);
      } else if(x == 0) {
        vm.expectRevert("must deposit ether");
        startHoax(alice);
        stakingPool.depositToPool{value: x}();
      } else {
        vm.expectRevert("total deposits cannot be more than 32 Eth");
        startHoax(alice);
        stakingPool.depositToPool{value: x}();
      }
    }

    function testAddToDeposit(uint64 x, uint64 y) public {
      //set pubKey
      hoax(contOwner);
      stakingPool.setPubKey(pubkey, withdrawal_credentials, signature, deposit_data_root);
      if(x > 0 && uint(x) + uint(y) <= 32 ether){
        startHoax(alice);
        stakingPool.depositToPool{value: x}();
        uint id = frensPoolShare.tokenOfOwnerByIndex(alice, 0);
        assertTrue(id == 0, "first id is 0");
        uint depAmt = stakingPool.depositForId(id);
        assertEq(x, depAmt);
        stakingPool.addToDeposit{value: y}(id);
        uint depAmt2 = stakingPool.depositForId(id);
        uint tot = uint(x) + uint(y);
        assertEq(tot, depAmt2);
      } else if(x == 0) {
        vm.expectRevert("must deposit ether");
        startHoax(alice);
        stakingPool.depositToPool{value: x}();
      } else { //uint64 cannot be > 32 ether (max 18,446,744,073,709,551,615 or ~18.45 ether)
        startHoax(alice);
        stakingPool.depositToPool{value: x}();
        uint id = frensPoolShare.tokenOfOwnerByIndex(alice, 0);
        vm.expectRevert("total deposits cannot be more than 32 Eth");
        stakingPool.addToDeposit{value: y}(id);
      }
    }

    function testWithdraw(uint72 x, uint72 y) public {
      //set pubKey
      hoax(contOwner);
      stakingPool.setPubKey(pubkey, withdrawal_credentials, signature, deposit_data_root);
      if(x >= y && x > 0 && uint(x) <= 32 ether){
        startHoax(alice);
        stakingPool.depositToPool{value: x}();
        uint id = frensPoolShare.tokenOfOwnerByIndex(alice, 0);
        assertTrue(id == 0, "first id is 0");
        uint depAmt = stakingPool.depositForId(id);
        assertEq(x, depAmt);
        stakingPool.withdraw(id, y);
        uint depAmt2 = stakingPool.depositForId(id);
        uint tot = uint(x) - uint(y);
        assertEq(tot, depAmt2);
      } else if(x == 0) {
        vm.expectRevert("must deposit ether");
        startHoax(alice);
        stakingPool.depositToPool{value: x}();
      } else if(uint(x) > 32 ether) {
        vm.expectRevert("total deposits cannot be more than 32 Eth");
        startHoax(alice);
        stakingPool.depositToPool{value: x}();
      } else {
        startHoax(alice);
        stakingPool.depositToPool{value: x}();
        uint id = frensPoolShare.tokenOfOwnerByIndex(alice, 0);
        assertTrue(id == 0, "first id is 0");
        vm.expectRevert("not enough deposited");
        stakingPool.withdraw(id, y);
      }
    }

    function testStake() public { 
      uint initialBalance = address(stakingPool).balance; //bc someone sent eth to this address on mainnet.
      hoax(alice);
      vm.expectRevert("not accepting deposits");
      stakingPool.depositToPool{value: 32000000000000000000}();
      //for this test to pass, it must be run on a mainnet fork,
      //and the vlaues below must all be correctly gererated in the staking_deposit_cli
      //use: ./deposit new-mnemonic --num_validators 1 --chain mainnet --eth1_withdrawal_address
      //followed by the stakingPool contract address
      hoax(contOwner);
      stakingPool.setPubKey(pubkey, withdrawal_credentials, signature, deposit_data_root);
      hoax(alice);
      stakingPool.depositToPool{value: 32000000000000000000}();
      assertEq(initialBalance + 32000000000000000000, address(stakingPool).balance);
      bytes32 deposit_count_hash = keccak256(depositContract.get_deposit_count());
      hoax(contOwner);
      stakingPool.stake();
      assertEq(initialBalance, address(stakingPool).balance);
      assertFalse(keccak256(depositContract.get_deposit_count()) == deposit_count_hash);
    }

    function testClaim(uint32 x, uint32 y) public {
      //set pubKey
      hoax(contOwner);
      stakingPool.setPubKey(pubkey, withdrawal_credentials, signature, deposit_data_root);
      uint maxUint32 = 4294967295;
      uint aliceDeposit = uint(x) * 31999999999999999999 / maxUint32;
      uint bobDeposit = 32000000000000000000 - aliceDeposit;
      if(x != 0 && y > 100){
        hoax(alice);
        stakingPool.depositToPool{value: aliceDeposit}();
        hoax(bob);
        stakingPool.depositToPool{value: bobDeposit}();
        payable(stakingPool).transfer(y);
        vm.expectRevert("use withdraw when not staked");
        stakingPool.claim(0);
        hoax(contOwner);
        stakingPool.stake(pubkey, withdrawal_credentials, signature, deposit_data_root);
        uint aliceBalance = address(alice).balance;
        uint bobBalance = address(bob).balance;
        uint aliceShare = (address(stakingPool).balance) * aliceDeposit / 32000000000000000000;
        uint bobShare = (address(stakingPool).balance) - aliceShare;
        //vm.prank(alice);
        stakingPool.claim(0);
/*
        uint frensClaimBalance = address(frensClaim).balance;
        //to account for rounding errors max 2 wei (bc we subtract 1 wei in contract to avoid drawing negative)
        assertApproxEqAbs(frensClaimBalance, bobShare, 2, "frensClaim balance pre-claim wrong");
*/
        if(aliceShare == 1) aliceShare = 0;
        if(bobShare == 1) bobShare =0;
        
        uint aliceBalanceExpected = aliceBalance + aliceShare;
        aliceBalance = address(alice).balance;
        //to account for rounding errors max 2 wei (bc we subtract 1 wei in contract to avoid drawing negative)
        assertApproxEqAbs(aliceBalance, aliceBalanceExpected, 2, "aliceBalance post-claim wrong");
      
        uint bobBalanceExpected = bobBalance + bobShare;
        //no claim for bob yet
        assertEq(bobBalance, address(bob).balance, "bobBalance pre-claim wrong");
        if(address(stakingPool).balance <= 100) {
          vm.expectRevert("must be greater than 100 wei to claim");
          stakingPool.claim(1);
        } else {
          stakingPool.claim(1);
          bobBalance = address(bob).balance;
          //to account for rounding errors max 2 wei (bc we subtract 1 wei in contract to avoid drawing negative)
          assertApproxEqAbs(bobBalance, bobBalanceExpected, 2, "bobBalance post-claim wrong");
        }

      } else if(x == 0) {
        vm.expectRevert("must deposit ether");
        startHoax(alice);
        stakingPool.depositToPool{value: x}();
      } else {
        hoax(alice);
        stakingPool.depositToPool{value: aliceDeposit}();
        hoax(bob);
        stakingPool.depositToPool{value: bobDeposit}();
        startHoax(contOwner);
        stakingPool.stake(pubkey, withdrawal_credentials, signature, deposit_data_root);
        payable(stakingPool).transfer(y);
        vm.expectRevert("must be greater than 100 wei to claim");
        stakingPool.claim(0);
      }
    }
    function testBadWithdrawalCred() public {
      startHoax(contOwner);
      vm.expectRevert("withdrawal credential mismatch");
      stakingPool.setPubKey(pubkey, hex"01000000000000000000000000dead", signature, deposit_data_root);
    }

    function testLock() public {
      //set pubKey
      startHoax(contOwner);
      stakingPool.setPubKey(pubkey, withdrawal_credentials, signature, deposit_data_root);
      vm.expectRevert("wrong state");
      stakingPool.setPubKey(pubkey, withdrawal_credentials, signature, deposit_data_root);
    }

}

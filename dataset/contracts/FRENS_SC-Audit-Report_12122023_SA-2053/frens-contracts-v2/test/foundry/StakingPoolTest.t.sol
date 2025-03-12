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
import "../../contracts/FrensOracle.sol";
import "../../contracts/interfaces/IStakingPoolFactory.sol";
import "../../contracts/interfaces/IDepositContract.sol";
import "./TestHelper.sol";


contract StakingPoolTest is Test {
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
    address payable public feeRecipient = payable(0x0000000000000000000000000694200000001337);

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
      //feeReceipient
      frensStorage.setAddress(keccak256(abi.encodePacked("protocol.fee.recipient")), feeRecipient);
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

      //create a second staking pool through proxy contract
      (address pool2) = stakingPoolFactory.create(contOwner, false/*, false, 0, 32000000000000000000*/);
      //connect to staking pool
      stakingPool2 = StakingPool(payable(pool2));
      //console.log the pool address for fun  if(FrensPoolShareOld == 0){
      //console.log("pool2", pool2);

    }

    function testOwner() public {
      address stakingPoolOwner = stakingPool.owner();
      assertEq(stakingPoolOwner, address(contOwner));
    }

    function testDeposit(uint72 x) public {
      if(x > 0 && x <= 32 ether){
        startHoax(alice);
        stakingPool.depositToPool{value: x}();
        uint id = frensPoolShare.tokenOfOwnerByIndex(alice, 0);
        assertTrue(id == 0, "first id is 0");
        uint depAmt = stakingPool.depositForId(id);
        assertEq(x, depAmt, "x = depAmt");
        uint totDep = stakingPool.totalDeposits();
        assertEq(x, totDep, "x=totDep");
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
      if(x > 0 && uint(x) + uint(y) <= 32 ether){
        startHoax(alice);
        stakingPool.depositToPool{value: x}();
        uint id = frensPoolShare.tokenOfOwnerByIndex(alice, 0);
        assertTrue(id == 0, "first id is 0");
        uint depAmt = stakingPool.depositForId(id);
        assertEq(x, depAmt);
        //should throw for non-existant id
        vm.expectRevert("wrong staking pool for id");
        stakingPool.addToDeposit{value: y}(69);
        //existing id should work fine
        stakingPool.addToDeposit{value: y}(id);
        uint depAmt2 = stakingPool.depositForId(id);
        uint tot = uint(x) + uint(y);
        assertEq(tot, depAmt2);
        uint totDeps = stakingPool.totalDeposits();
        assertEq(tot, totDeps);
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

    function testAddToDepositWrongPool(uint64 x, uint64 y) public {
      if(x > 0 && uint(x) + uint(y) <= 32 ether){
        startHoax(alice);
        stakingPool.depositToPool{value: x}();
        uint id = frensPoolShare.tokenOfOwnerByIndex(alice, 0);
        assertTrue(id == 0, "first id is 0");
        uint depAmt = stakingPool.depositForId(id);
        assertEq(x, depAmt, "x = depAmt");
        //should throw for wrong pool
        vm.expectRevert("wrong staking pool for id");
        stakingPool2.addToDeposit{value: y}(id);
        //existing id should work fine (redundant with previous test)
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
      if(x >= y && x > 0 && uint(x) <= 32 ether){
        startHoax(alice);
        stakingPool.depositToPool{value: x}();
        uint id = frensPoolShare.tokenOfOwnerByIndex(alice, 0);
        assertTrue(id == 0, "first id should be 0");
        uint depAmt = stakingPool.depositForId(id);
        assertEq(x, depAmt, "deposit amount should be x");
        stakingPool.withdraw(id, y);
        uint depAmt2 = stakingPool.depositForId(id);
        uint tot = uint(x) - uint(y);
        assertEq(tot, depAmt2, "x - y s/b = tot");
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
      //stakingPool.sendToOwner();
      uint initialBalance = address(stakingPool).balance; //bc someone sent eth to this address on mainnet.
      hoax(alice);
      stakingPool.depositToPool{value: 32000000000000000000}();
      assertEq(initialBalance + 32000000000000000000, address(stakingPool).balance);
      bytes32 deposit_count_hash = keccak256(depositContract.get_deposit_count());
      hoax(contOwner);
      //for this test to pass, it must be run on a mainnet fork,
      //and the vlaues below must all be correctly gererated in the staking_deposit_cli
      //use: ./deposit new-mnemonic --num_validators 1 --chain mainnet --eth1_withdrawal_address
      //followed by the stakingPool contract address
      stakingPool.stake(pubkey, withdrawal_credentials, signature, deposit_data_root);
      assertEq(initialBalance, address(stakingPool).balance);
      assertFalse(keccak256(depositContract.get_deposit_count()) == deposit_count_hash);
      //test reverts for trying to deposit when staked
      startHoax(alice);
      vm.expectRevert("not accepting deposits");
      stakingPool.depositToPool{value: 1}();
      vm.expectRevert("not accepting deposits");
      stakingPool.addToDeposit{value: 1}(1);
    }

    function testStakeTwoStep() public { 
      uint initialBalance = address(stakingPool).balance; //bc someone sent eth to this address on mainnet.
      hoax(alice);
      stakingPool.depositToPool{value: 32000000000000000000}();
      assertEq(initialBalance + 32000000000000000000, address(stakingPool).balance);
      bytes32 deposit_count_hash = keccak256(depositContract.get_deposit_count());
      startHoax(contOwner);
      //for this test to pass, it must be run on a mainnet fork,
      //and the vlaues below must all be correctly gererated in the staking_deposit_cli
      //use: ./deposit new-mnemonic --num_validators 1 --chain mainnet --eth1_withdrawal_address
      //followed by the stakingPool contract address
      stakingPool.setPubKey(pubkey, withdrawal_credentials, signature, deposit_data_root);
      stakingPool.stake();
      assertEq(initialBalance, address(stakingPool).balance);
      assertFalse(keccak256(depositContract.get_deposit_count()) == deposit_count_hash);
    }

  function testClaim(uint32 x, uint32 y) public {
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
        stakingPool.claim(1);
        hoax(contOwner);
        stakingPool.stake(pubkey, withdrawal_credentials, signature, deposit_data_root);
        uint aliceBalance = address(alice).balance;
        uint bobBalance = address(bob).balance;
        uint aliceShare = (address(stakingPool).balance) * aliceDeposit / 32000000000000000000;
        uint bobShare = (address(stakingPool).balance) - aliceShare;
        //vm.prank(alice);
        /*
        uint frensClaimBalance = address(frensClaim).balance;
        //to account for rounding errors max 2 wei (bc we subtract 1 wei in contract to avoid drawing negative)
        assertApproxEqAbs(frensClaimBalance, bobShare, 2, "frensClaim balance pre-claim wrong");
*/
        if(aliceShare == 1) aliceShare = 0;
        if(bobShare == 1) bobShare =0;
        
        stakingPool.claim(0);
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
        stakingPool.claim(1);
      }

    }

    function testBadWithdrawalCred() public {
      startHoax(contOwner);
      vm.expectRevert("withdrawal credential mismatch");
      stakingPool.setPubKey(pubkey, hex"01000000000000000000000000dead", signature, deposit_data_root);
      vm.expectRevert("withdrawal credential mismatch");
      stakingPool.stake(pubkey, hex"01000000000000000000000000dead", signature, deposit_data_root);
    }

    function testPubKeyMismatch() public {
      startHoax(contOwner);
      stakingPool.setPubKey(pubkey, withdrawal_credentials, signature, deposit_data_root);
      vm.expectRevert("pubKey mismatch");
      stakingPool.stake(hex"dead", withdrawal_credentials, signature, deposit_data_root);
    }
/*
    function testArbitrarySend() public {
      hoax(alice);
      stakingPool.depositToPool{value: 1 ether}();
      uint bobBalance = address(bob).balance;

      hoax(contOwner);
      vm.expectRevert("contract not allowed");
      stakingPool.arbitraryContractCall(payable(address(bob)), 1 ether, "0x0");
      assertEq(bobBalance, address(bob).balance);

      frensInitialiser.allowExternalContract(0x0000000000000000000000000000000000000B0b); //bob is our external contract here
      
      hoax(contOwner);
      stakingPool.arbitraryContractCall(payable(address(bob)), 1 ether, "0x0");
      assertEq(bobBalance + 1 ether, address(bob).balance);
    }


    function testBurn(uint72 x) public { //this would be a stupid thing to want to do, so it will probably not be included
      if(x > 0 && x <= 32 ether){
        startHoax(alice);
        stakingPool.depositToPool{value: x}();
        uint id = frensPoolShare.tokenOfOwnerByIndex(alice, 0);
        stakingPool.burn(id);
        vm.expectRevert("ERC721Enumerable: owner index out of bounds");
        id = frensPoolShare.tokenOfOwnerByIndex(alice, 0);
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
*/

function testFees(uint32 x, uint32 y) public {
      uint maxUint32 = 4294967295;
      uint aliceDeposit = uint(x) * 31999999999999999999 / maxUint32;
      uint bobDeposit = 32000000000000000000 - aliceDeposit;
      if(x != 0 && y > 100){
        vm.prank(address(this));
        frensStorage.setUint(keccak256(abi.encodePacked("protocol.fee.percent")), 5);
        hoax(alice);
        stakingPool.depositToPool{value: aliceDeposit}();
        hoax(bob);
        stakingPool.depositToPool{value: bobDeposit}();
        payable(stakingPool).transfer(y);
        vm.expectRevert("use withdraw when not staked");
        stakingPool.claim(1);
        hoax(contOwner);
        stakingPool.stake(pubkey, withdrawal_credentials, signature, deposit_data_root);
        uint poolBalance = (address(stakingPool).balance);
        uint fees = poolBalance * 5 / 100;
        uint poolBalanceMinusFees = poolBalance - fees;
        uint aliceBalance = address(alice).balance;
        uint bobBalance = address(bob).balance;
        uint aliceShare = poolBalanceMinusFees * aliceDeposit / 32000000000000000000;
        uint bobShare = poolBalanceMinusFees - aliceShare;
        console.log("pool balance", address(stakingPool).balance);
        console.log("alice share", aliceShare);
        uint aliceDistShare = stakingPool.getDistributableShare(0);
        uint bobDistShare = stakingPool.getDistributableShare(1);
        assertApproxEqAbs(aliceShare, aliceDistShare, 3, "alice share does not match distibutable share");
        assertApproxEqAbs(bobShare, bobDistShare, 3, "bob share does not match bob distributable share");
        console.log("feeRecipient.balance", address(feeRecipient).balance);
 /*       stakingPool.distribute();
        uint frensClaimBalance = address(frensClaim).balance;
        assertEq(frensClaimBalance, aliceShare + bobShare, "frensClaim balance pre-claim wrong"); */
        
        if(aliceShare == 1) aliceShare = 0;
        if(bobShare == 1) bobShare =0;
        
        uint aliceBalanceExpected = aliceBalance + aliceShare;
        //distribute was called, no claim, so there should be no change yet
        assertEq(aliceBalance, address(alice).balance, "aliceBalance pre-claim wrong");
        vm.prank(alice);
        console.log("staking Pool balance", address(stakingPool).balance);
        stakingPool.claim(0);
        aliceBalance = address(alice).balance;
        //to account for rounding errors max 2 wei (bc we subtract 1 wei in contract to avoid drawing negative)
        assertApproxEqAbs(aliceBalance, aliceBalanceExpected, 2, "aliceBalance post-claim wrong");
      
        uint bobBalanceExpected = bobBalance + bobShare;
        //no claim for bob yet
        assertEq(bobBalance, address(bob).balance, "bobBalance pre-claim wrong");
        vm.prank(bob);
        if(address(stakingPool).balance <= 100) {
          vm.expectRevert("must be greater than 100 wei to claim");
          stakingPool.claim(1);
        } else {
          stakingPool.claim(1);
          bobBalance = address(bob).balance;
          //to account for rounding errors max 2 wei (bc we subtract 1 wei in contract to avoid drawing negative)
          assertApproxEqAbs(bobBalance, bobBalanceExpected, 3, "bobBalance post-claim wrong"); 
        }
        assertApproxEqAbs(fees, address(feeRecipient).balance, 10, "fee recipient balance incorrect"); 

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
        stakingPool.claim(1);
      }

    }

    function testExit() public {
      hoax(alice);
      stakingPool.depositToPool{value: 32 ether}();
      vm.prank(contOwner);
      stakingPool.stake(pubkey, withdrawal_credentials, signature, deposit_data_root);
      vm.expectRevert("must be called by oracle");
      stakingPool.exitPool();
      vm.expectRevert("must be guardian");
      vm.prank(alice);
      frensOracle.setExiting(pubkey, true);
      vm.prank(address(this), address(this));
      frensOracle.setExiting(pubkey, true);
      frensOracle.checkValidatorState(address(stakingPool));
      string memory state = stakingPool.getState();
      assertEq(keccak256(abi.encodePacked("exited")), keccak256(abi.encodePacked(state)),"not exited");
    }
}

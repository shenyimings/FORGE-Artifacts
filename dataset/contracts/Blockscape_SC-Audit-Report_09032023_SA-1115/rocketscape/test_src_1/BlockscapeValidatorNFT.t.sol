// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {BlockscapeValidatorNFT} from "src/BlockscapeValidatorNFT.sol";
import {HelperContract} from "./BlockscapeValidatorNFT_utils.sol";

contract BlockscapeValidatorNFTTest is Test, HelperContract {
    uint256 initWithdrawFee = 20 ether;

    bytes validatorBytesAddress =
        hex"a2e78385831894094502727373588fc1794ea2800b2b6e614358fea78dcf0cc4d103008a53c665f294e31af0397253e3";

    error NotEnoughRPLStake();

    function setUp() public {
        _setupParticipants();
    }

    function testOpenValidatorNFT() public {
        _testInitContractSetup();
        _testInitRocketPoolSetup();

        // not enough RPL to stake, shouldn't open vault
        vm.expectRevert(NotEnoughRPLStake.selector);
        _openValidatorNFT();

        _stakeRPL();

        _testContractSetupAfterStaking();
        _testRocketPoolSetupAfterStaking();

        // only owner should be able to call function
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(singleStaker);
        blockscapeValidatorNFT.openValidatorNFT();

        _openValidatorNFT();
        assertEq(blockscapeValidatorNFT.isVaultOpen(), true);
    }

    function testCloseValidatorNFT() public {
        _testInitContractSetup();
        _testInitRocketPoolSetup();

        // only owner should be able to call function
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(singleStaker);
        blockscapeValidatorNFT.closeValidatorNFT();

        vm.prank(deployer);
        blockscapeValidatorNFT.closeValidatorNFT();
        assertEq(blockscapeValidatorNFT.isVaultOpen(), false);

        _stakeRPL();

        _openValidatorNFT();
        assertEq(blockscapeValidatorNFT.isVaultOpen(), true);

        // only owner should be able to call function
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(singleStaker);
        blockscapeValidatorNFT.closeValidatorNFT();

        vm.prank(deployer);
        blockscapeValidatorNFT.closeValidatorNFT();
        assertEq(blockscapeValidatorNFT.isVaultOpen(), false);
    }

    function testDepositValidatorNFT() public {
        _stakeRPL();
        _openValidatorNFT();

        assertEq(blockscapeValidatorNFT.totalSupply(), 0);

        // expect incorrect values of ether to revert
        vm.expectRevert();
        vm.prank(poolStaker1);
        blockscapeValidatorNFT.depositValidatorNFT();

        vm.expectRevert();
        vm.prank(poolStaker1);
        blockscapeValidatorNFT.depositValidatorNFT{value: curETHlimit - 1 ether}();

        vm.expectRevert();
        vm.prank(poolStaker1);
        blockscapeValidatorNFT.depositValidatorNFT{value: curETHlimit + 1 ether}();

        _depositSoloStaker();

        BlockscapeValidatorNFT.Metadata memory shouldBeM;
        shouldBeM.stakedETH = curETHlimit;
        shouldBeM.stakedTimestamp = block.timestamp;
        shouldBeM.institution = false;
        shouldBeM.institutionName = "";
        shouldBeM.institutionVerified = false;

        (
            BlockscapeValidatorNFT.Metadata memory m,
           // address staker,
            bytes memory validator
        ) = blockscapeValidatorNFT.getMetadata(1);

        // TODO: Write test cases for other token ids that they return
        // default values == they are unset?

        assertEq(m.stakedETH, shouldBeM.stakedETH);
        assertEq(m.stakedTimestamp, shouldBeM.stakedTimestamp);
        assertEq(m.institution, shouldBeM.institution);
        assertEq(m.institutionName, shouldBeM.institutionName);
        assertEq(m.institutionVerified, shouldBeM.institutionVerified);
       // assertEq(staker, singleStaker);
        assertEq(string(validator), string(""));

        assertEq(blockscapeValidatorNFT.isVaultOpen(), false);

        assertEq(blockscapeValidatorNFT.totalSupply(), 1);
        assertEq(blockscapeValidatorNFT.getTokenID(), 2);
        assertEq(
            blockscapeValidatorNFT.contractURI(),
            "https://ipfs.blockscape.network/ipfs/QmUr8P96kNuFjcZb2WBjBP4e1fiGGXwRGChfTi42pnujY7"
        );
        assertEq(
            blockscapeValidatorNFT.uri(1),
            "https://ipfs.blockscape.network/ipns/k51qzi5uqu5di5eo5fzr1zypdsz0zct39zpct9s4wesjustul1caeofak3zoej/1.json"
        );

        // vault is closed
        vm.expectRevert();
        vm.prank(poolStaker1);
        blockscapeValidatorNFT.depositValidatorNFT{value: curETHlimit}();
    }

    function testFallbacks() public {
        vm.expectRevert();
        vm.prank(poolStaker1);
        payable(address(blockscapeValidatorNFT)).transfer(5 ether);
    }

    function testWithdraw() public {
        _stakeRPL();
        _openValidatorNFT();
        _depositSoloStaker();

        assertEq(blockscapeValidatorNFT.getBalance(), curETHlimit);

        // only owner should be able to call function
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(singleStaker);
        blockscapeValidatorNFT.withdraw(curETHlimit);

        uint256 deployerBalance = deployer.balance;

        vm.prank(deployer);
        blockscapeValidatorNFT.withdraw(curETHlimit);

        assertEq(deployer.balance - deployerBalance, curETHlimit);
        assertEq(blockscapeValidatorNFT.getBalance(), 0 ether);
    }

    function testWithdrawBatch() public {
        _stakeRPL();
        _openValidatorNFT();

        // nothing deposited yet
        vm.expectRevert();
        vm.prank(deployer);
        blockscapeValidatorNFT.withdrawBatch();

        assertEq(blockscapeValidatorNFT.getBalance(), 0 ether);

        _depositSoloStaker();

        assertEq(blockscapeValidatorNFT.getBalance(), curETHlimit);

        availableRPL = blockscapeValidatorNFT.getAvailableRPLStake();

        // only owner should be able to call function
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(singleStaker);
        blockscapeValidatorNFT.withdrawBatch();

        vm.startPrank(deployer);
        blockscapeValidatorNFT.withdrawBatch();

        assertEq(blockscapeValidatorNFT.isVaultOpen(), false);
        assertEq(blockscapeValidatorNFT.getBalance(), 0 ether);

        blockscapeValidatorNFT.updateValidator(1, validatorBytesAddress);
        assertEq(blockscapeValidatorNFT.isVaultOpen(), true);

        vm.stopPrank();

        // TODO: check that vault can't reopen if not enough RPL are there
        // use either depositRocketpool or transfer RPL away from blockscape
        // (second option would be an workaround)
        // _depositToRocketpool();

        // availableRPL = blockscapeValidatorNFT.getAvailableRPLStake();
        // console.log("availableRPL");
        // console.logUint(availableRPL);

        // _warpAfterStakingCooldown();
        // _unstakeRPL();
    }

    function testUpdateValidator() public {
        _stakeRPL();
        _openValidatorNFT();
        _depositSoloStaker();

        bytes memory otherBytesAddr = abi.encodePacked(address(2));

        // only owner should be able to call function
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(singleStaker);
        blockscapeValidatorNFT.updateValidator(1, validatorBytesAddress);

        vm.prank(deployer);
        blockscapeValidatorNFT.updateValidator(1, validatorBytesAddress);

        (, bytes memory validator) = blockscapeValidatorNFT
            .getMetadata(1);

        // TODO: Write test cases for other token ids that they return
        // default values == they are unset?

       // assertEq(staker, singleStaker);
        assertEq(validator, validatorBytesAddress);

        // can only be set once
        vm.expectRevert();
        vm.prank(deployer);
        blockscapeValidatorNFT.updateValidator(1, otherBytesAddr);
    }

    function testUserRequestWithdraw() public {
        _stakeRPL();
        _openValidatorNFT();
        _depositSoloStaker();

        uint256 amount = blockscapeValidatorNFT.userRequestWithdraw(1);
        uint256 amountView = blockscapeValidatorNFT.viewUserRequestWithdraw(1, msg.sender);
        assertEq(amount, initWithdrawFee);
        assertEq(amountView, initWithdrawFee);

        vm.startPrank(singleStaker);
        amount = blockscapeValidatorNFT.userRequestWithdraw(1);
        amountView = blockscapeValidatorNFT.viewUserRequestWithdraw(1, msg.sender);
        assertEq(amount, initWithdrawFee);
        assertEq(amountView, initWithdrawFee);

        uint256 origTimestamp = block.timestamp;
        uint256 feesDropTimestamp = block.timestamp + 30747600;

        vm.warp(origTimestamp + 10 days);
        amount = blockscapeValidatorNFT.userRequestWithdraw(1);
        amountView = blockscapeValidatorNFT.viewUserRequestWithdraw(1, msg.sender);
        assertEq(
            amount,
            initWithdrawFee - (initWithdrawFee / 365 days) * 10 days
        );
        assertEq(
            amountView,
            initWithdrawFee - (initWithdrawFee / 365 days) * 10 days
        );

        vm.warp(origTimestamp + 100 days);
        amount = blockscapeValidatorNFT.userRequestWithdraw(1);
        amountView = blockscapeValidatorNFT.viewUserRequestWithdraw(1, msg.sender);
        assertEq(
            amount,
            initWithdrawFee - (initWithdrawFee / 365 days) * 100 days
        );
        assertEq(
            amountView,
            initWithdrawFee - (initWithdrawFee / 365 days) * 100 days
        );

        vm.warp(feesDropTimestamp);
        amount = blockscapeValidatorNFT.userRequestWithdraw(1);
        amountView = blockscapeValidatorNFT.viewUserRequestWithdraw(1, msg.sender);
        assertEq(amount, 0.5 ether);
        assertEq(amountView, 0.5 ether);

        vm.warp(feesDropTimestamp + 1000 days);
        amount = blockscapeValidatorNFT.userRequestWithdraw(1);
        amountView = blockscapeValidatorNFT.viewUserRequestWithdraw(1, msg.sender);
        assertEq(amount, 0.5 ether);
        assertEq(amountView, 0.5 ether);

        vm.stopPrank();
    }

    function testChangeETHLimit() public {
        uint256 ethLimit = blockscapeValidatorNFT.getCurrentEthLimit();
        assertEq(ethLimit, curETHlimit);

        vm.expectRevert("Ownable: caller is not the owner");
        blockscapeValidatorNFT.changeETHLimit(64 ether);

        vm.prank(deployer);
        blockscapeValidatorNFT.changeETHLimit(64 ether);

        ethLimit = blockscapeValidatorNFT.getCurrentEthLimit();
        assertEq(ethLimit, 64 ether);
    }

    function testSetWithdrawFee() public {
        vm.expectRevert("Ownable: caller is not the owner");
        blockscapeValidatorNFT.setWithdrawFee(1 ether);

        vm.prank(deployer);
        blockscapeValidatorNFT.setWithdrawFee(1 ether);
    }

    function testSetBlockscapeRocketPoolNode() public {
        vm.expectRevert("Ownable: caller is not the owner");
        blockscapeValidatorNFT.setBlockscapeRocketPoolNode(address(0x1));

        vm.prank(deployer);
        blockscapeValidatorNFT.setBlockscapeRocketPoolNode(address(0x1));
    }

    function testDepositWithdrawalMulti() public {
        _stakeRPL();
        _openValidatorNFT();
        _depositSoloStaker();

        vm.prank(deployer);
        blockscapeValidatorNFT.withdrawBatch();

        // can't deposit before updateValidator function has been run
        // and vault is opened
        vm.expectRevert();
        vm.prank(poolStaker1);
        blockscapeValidatorNFT.depositValidatorNFT{value: curETHlimit}();

        vm.prank(deployer);
        blockscapeValidatorNFT.updateValidator(1, validatorBytesAddress);

        vm.prank(poolStaker1);
        blockscapeValidatorNFT.depositValidatorNFT{value: curETHlimit}();

        // can't deposit before stake has been withdrawn
        vm.expectRevert();
        vm.prank(poolStaker2);
        blockscapeValidatorNFT.depositValidatorNFT{value: curETHlimit}();

        vm.prank(deployer);
        blockscapeValidatorNFT.withdrawBatch();

        assertEq(blockscapeValidatorNFT.isVaultOpen(), false);
        assertEq(blockscapeValidatorNFT.getBalance(), 0 ether);

        vm.prank(deployer);
        blockscapeValidatorNFT.updateValidator(2, validatorBytesAddress);

        assertEq(blockscapeValidatorNFT.isVaultOpen(), true);

        vm.prank(poolStaker2);
        blockscapeValidatorNFT.depositValidatorNFT{value: curETHlimit}();

        assertEq(blockscapeValidatorNFT.getBalance(), curETHlimit);

        vm.startPrank(deployer);
        blockscapeValidatorNFT.withdrawBatch();

        console.log(blockscapeValidatorNFT.getAvailableRPLStake());
        _warpAfterStakingCooldown();
        _unstakeRPL();
        console.log(blockscapeValidatorNFT.getAvailableRPLStake());
        console.log(blockscapeValidatorNFT.getReqRPLStake());

        blockscapeValidatorNFT.updateValidator(3, validatorBytesAddress);

        // updateValidator doesn't open vault as not enough RPL are present
        assertEq(blockscapeValidatorNFT.isVaultOpen(), false);

        assertEq(blockscapeValidatorNFT.totalSupply(), 3);
        assertEq(blockscapeValidatorNFT.getTokenID(), 4);

        vm.stopPrank();
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {BlockscapeETHStakeNFT} from "src/BlockscapeETHStakeNFTv2.sol";
import {HelperContract} from "./BlockscapeETHStakeNFT_utils.sol";

contract BlockscapeETHStakeNFTTest is Test, HelperContract {
    uint256 initWithdrawFee = 20 ether;

    bytes ETHStakeBytesAddress =
        hex"a2e78385831894094502727373588fc1794ea2800b2b6e614358fea78dcf0cc4d103008a53c665f294e31af0397253e3";

    error NotEnoughRPLStake();

    function setUp() public {
        _setupParticipants();
    }

    
    // function testdepositStakeNFT() public {
    //     _stakeRPL();

    //     // assertEq(BlockscapeETHStakeNFT.totalSupply(), 0);

    //     // // expect incorrect values of ether to revert
    //     // vm.expectRevert();
    //     // vm.prank(poolStaker1);
    //     // BlockscapeETHStakeNFT.depositStakeNFT();

    //     // vm.expectRevert();
    //     // vm.prank(poolStaker1);
    //     // BlockscapeETHStakeNFT.depositStakeNFT{value: curETHlimit - 1 ether}();

    //     // vm.expectRevert();
    //     // vm.prank(poolStaker1);
    //     // BlockscapeETHStakeNFT.depositStakeNFT{value: curETHlimit + 1 ether}();

    //     _depositSoloStaker();

    //     BlockscapeETHStakeNFT.Metadata memory shouldBeM;
    //     shouldBeM.stakedETH = curETHlimit;
    //     shouldBeM.stakedTimestamp = block.timestamp;
    //     shouldBeM.institution = false;
    //     shouldBeM.institutionName = "";
    //     shouldBeM.institutionVerified = false;

    //     (
    //         BlockscapeETHStakeNFT.Metadata memory m,
    //        // address staker,
    //         bytes memory ETHStake
    //     ) = BlockscapeETHStakeNFT.getMetadata(1);

    //     // TODO: Right test cases for other token ids that they return
    //     // default values == they are unset?

    //     assertEq(m.stakedETH, shouldBeM.stakedETH);
    //     assertEq(m.stakedTimestamp, shouldBeM.stakedTimestamp);
    //     assertEq(m.institution, shouldBeM.institution);
    //     assertEq(m.institutionName, shouldBeM.institutionName);
    //     assertEq(m.institutionVerified, shouldBeM.institutionVerified);
    //    // assertEq(staker, singleStaker);
    //     assertEq(string(ETHStake), string(""));

    //     assertEq(BlockscapeETHStakeNFT.isVaultOpen(), false);

    //     assertEq(BlockscapeETHStakeNFT.totalSupply(), 1);
    //     assertEq(BlockscapeETHStakeNFT.getTokenID(), 2);
    //     assertEq(
    //         BlockscapeETHStakeNFT.contractURI(),
    //         "https://ipfs.blockscape.network/ipfs/QmPRDjSg3idxTE8BTS37umDmTZ2LZb3x34LVBQMyaj9nVy"
    //     );
    //     assertEq(
    //         BlockscapeETHStakeNFT.uri(1),
    //         "https://ipfs.blockscape.network/ipns/k51qzi5uqu5divkfa2vxu2i71yhj3k6rm6bgvgnd4q00h4f80cb4imsg9uy29l/1.json"
    //     );

    //     // vault is closed
    //     vm.expectRevert();
    //     vm.prank(poolStaker1);
    //     BlockscapeETHStakeNFT.depositStakeNFT{value: curETHlimit}();
    // }

    function testFallbacks() public {
        vm.expectRevert();
        vm.prank(poolStaker1);
        payable(address(BlockscapeETHStakeNFT)).transfer(5 ether);
    }

    function testWithdraw() public {
        _stakeRPL();
        _depositSoloStaker();

        assertEq(BlockscapeETHStakeNFT.getBalance(), curETHlimit);

        // only owner should be able to call function
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(singleStaker);
        BlockscapeETHStakeNFT.withdraw(curETHlimit);

        uint256 deployerBalance = deployer.balance;

        vm.prank(deployer);
        BlockscapeETHStakeNFT.withdraw(curETHlimit);

        assertEq(deployer.balance - deployerBalance, curETHlimit);
        assertEq(BlockscapeETHStakeNFT.getBalance(), 0 ether);
    }

    function testWithdrawBatch() public {
        _stakeRPL();

        // nothing deposited yet
        vm.expectRevert();
        vm.prank(deployer);
        BlockscapeETHStakeNFT.withdrawBatch();

        assertEq(BlockscapeETHStakeNFT.getBalance(), 0 ether);

        _depositSoloStaker();

        assertEq(BlockscapeETHStakeNFT.getBalance(), curETHlimit);

        availableRPL = BlockscapeETHStakeNFT.getAvailableRPLStake();

        // only owner should be able to call function
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(singleStaker);
        BlockscapeETHStakeNFT.withdrawBatch();

        vm.startPrank(deployer);
        BlockscapeETHStakeNFT.withdrawBatch();

        assertEq(BlockscapeETHStakeNFT.isVaultOpen(), false);
        assertEq(BlockscapeETHStakeNFT.getBalance(), 0 ether);

        BlockscapeETHStakeNFT.updateETHStake(1, ETHStakeBytesAddress);
        assertEq(BlockscapeETHStakeNFT.isVaultOpen(), true);

        vm.stopPrank();

        // TODO: check that vault can't reopen if not enough RPL are there
        // use either depositRocketpool or transfer RPL away from blockscape
        // (second option would be an workaround)
        // _depositToRocketpool();

        // availableRPL = BlockscapeETHStakeNFT.getAvailableRPLStake();
        // console.log("availableRPL");
        // console.logUint(availableRPL);

        // _warpAfterStakingCooldown();
        // _unstakeRPL();
    }

    function testUpdateETHStake() public {
        _stakeRPL();
        _depositSoloStaker();

        bytes memory otherBytesAddr = abi.encodePacked(address(2));

        // only owner should be able to call function
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(singleStaker);
        BlockscapeETHStakeNFT.updateETHStake(1, ETHStakeBytesAddress);

        vm.prank(deployer);
        BlockscapeETHStakeNFT.updateETHStake(1, ETHStakeBytesAddress);

        (, bytes memory ETHStake) = BlockscapeETHStakeNFT
            .getMetadata(1);

        // TODO: Right test cases for other token ids that they return
        // default values == they are unset?

       // assertEq(staker, singleStaker);
        assertEq(ETHStake, ETHStakeBytesAddress);

        // can only be set once
        vm.expectRevert();
        vm.prank(deployer);
        BlockscapeETHStakeNFT.updateETHStake(1, otherBytesAddr);
    }

    function testUserRequestWithdraw() public {
        _stakeRPL();
        _depositSoloStaker();

        uint256 amount = BlockscapeETHStakeNFT.userRequestWithdraw(1);
        uint256 amountView = BlockscapeETHStakeNFT.viewUserRequestWithdraw(1);
        assertEq(amount, initWithdrawFee);
        assertEq(amountView, initWithdrawFee);

        vm.startPrank(singleStaker);
        amount = BlockscapeETHStakeNFT.userRequestWithdraw(1);
        amountView = BlockscapeETHStakeNFT.viewUserRequestWithdraw(1);
        assertEq(amount, initWithdrawFee);
        assertEq(amountView, initWithdrawFee);

        uint256 origTimestamp = block.timestamp;
        uint256 feesDropTimestamp = block.timestamp + 30747600;

        vm.warp(origTimestamp + 10 days);
        amount = BlockscapeETHStakeNFT.userRequestWithdraw(1);
        amountView = BlockscapeETHStakeNFT.viewUserRequestWithdraw(1);
        assertEq(
            amount,
            initWithdrawFee - (initWithdrawFee / 365 days) * 10 days
        );
        assertEq(
            amountView,
            initWithdrawFee - (initWithdrawFee / 365 days) * 10 days
        );

        vm.warp(origTimestamp + 100 days);
        amount = BlockscapeETHStakeNFT.userRequestWithdraw(1);
        amountView = BlockscapeETHStakeNFT.viewUserRequestWithdraw(1);
        assertEq(
            amount,
            initWithdrawFee - (initWithdrawFee / 365 days) * 100 days
        );
        assertEq(
            amountView,
            initWithdrawFee - (initWithdrawFee / 365 days) * 100 days
        );

        vm.warp(feesDropTimestamp);
        amount = BlockscapeETHStakeNFT.userRequestWithdraw(1);
        amountView = BlockscapeETHStakeNFT.viewUserRequestWithdraw(1);
        assertEq(amount, 0.5 ether);
        assertEq(amountView, 0.5 ether);

        vm.warp(feesDropTimestamp + 1000 days);
        amount = BlockscapeETHStakeNFT.userRequestWithdraw(1);
        amountView = BlockscapeETHStakeNFT.viewUserRequestWithdraw(1);
        assertEq(amount, 0.5 ether);
        assertEq(amountView, 0.5 ether);

        vm.stopPrank();
    }

    function testChangeETHLimit() public {
        uint256 ethLimit = BlockscapeETHStakeNFT.getCurrentEthLimit();
        assertEq(ethLimit, curETHlimit);

        vm.expectRevert("Ownable: caller is not the owner");
        BlockscapeETHStakeNFT.changeETHLimit(64 ether);

        vm.prank(deployer);
        BlockscapeETHStakeNFT.changeETHLimit(64 ether);

        ethLimit = BlockscapeETHStakeNFT.getCurrentEthLimit();
        assertEq(ethLimit, 64 ether);
    }

    function testSetWithdrawFee() public {
        vm.expectRevert("Ownable: caller is not the owner");
        BlockscapeETHStakeNFT.setWithdrawFee(1 ether);

        vm.prank(deployer);
        BlockscapeETHStakeNFT.setWithdrawFee(1 ether);
    }

    function testSetBlockscapeRocketPoolNode() public {
        vm.expectRevert("Ownable: caller is not the owner");
        BlockscapeETHStakeNFT.setBlockscapeRocketPoolNode(address(0x1));

        vm.prank(deployer);
        BlockscapeETHStakeNFT.setBlockscapeRocketPoolNode(address(0x1));
    }

    function testDepositWithdrawalMulti() public {
        _stakeRPL();
        _depositSoloStaker();

        vm.prank(deployer);
        BlockscapeETHStakeNFT.withdrawBatch();

        // can't deposit before updateETHStake function has been run
        // and vault is opened
        vm.expectRevert();
        vm.prank(poolStaker1);
        BlockscapeETHStakeNFT.depositStakeNFT{value: curETHlimit}();

        vm.prank(deployer);
        BlockscapeETHStakeNFT.updateETHStake(1, ETHStakeBytesAddress);

        vm.prank(poolStaker1);
        BlockscapeETHStakeNFT.depositStakeNFT{value: curETHlimit}();

        // can't deposit before stake has been withdrawn
        vm.expectRevert();
        vm.prank(poolStaker2);
        BlockscapeETHStakeNFT.depositStakeNFT{value: curETHlimit}();

        vm.prank(deployer);
        BlockscapeETHStakeNFT.withdrawBatch();

        assertEq(BlockscapeETHStakeNFT.isVaultOpen(), false);
        assertEq(BlockscapeETHStakeNFT.getBalance(), 0 ether);

        vm.prank(deployer);
        BlockscapeETHStakeNFT.updateETHStake(2, ETHStakeBytesAddress);

        assertEq(BlockscapeETHStakeNFT.isVaultOpen(), true);

        vm.prank(poolStaker2);
        BlockscapeETHStakeNFT.depositStakeNFT{value: curETHlimit}();

        assertEq(BlockscapeETHStakeNFT.getBalance(), curETHlimit);

        vm.startPrank(deployer);
        BlockscapeETHStakeNFT.withdrawBatch();

        console.log(BlockscapeETHStakeNFT.getAvailableRPLStake());
        _warpAfterStakingCooldown();
        _unstakeRPL();
        console.log(BlockscapeETHStakeNFT.getAvailableRPLStake());
        console.log(BlockscapeETHStakeNFT.getReqRPLStake());

        BlockscapeETHStakeNFT.updateETHStake(3, ETHStakeBytesAddress);

        // updateETHStake doesn't open vault as not enough RPL are present
        assertEq(BlockscapeETHStakeNFT.isVaultOpen(), false);

        assertEq(BlockscapeETHStakeNFT.totalSupply(), 3);
        assertEq(BlockscapeETHStakeNFT.getTokenID(), 4);

        vm.stopPrank();
    }
}

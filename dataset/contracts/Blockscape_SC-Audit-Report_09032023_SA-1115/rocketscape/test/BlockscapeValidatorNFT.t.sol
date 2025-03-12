// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.16;

import "openzeppelin-contracts/utils/Address.sol";
import "forge-std/Test.sol";

import {console} from "forge-std/console.sol";

import {BlockscapeValidatorNFT} from "src/BlockscapeValidatorNFT.sol";
import {BlockscapeValidatorNFTTestHelper} from "./utils/BlockscapeValidatorNFTTestHelper.sol";

contract BlockscapeValidatorNFTTest is Test, BlockscapeValidatorNFTTestHelper {
    error NotEnoughRPLStake();

    event ETHLimitChanged(uint256 _newLimit);
    event UserRequestedWithdrawalVali(
        uint256 indexed _tokenID,
        address indexed _user,
        uint256 _fee,
        uint256 _stakedETH,
        uint256 _rewards
    );

    constructor() BlockscapeValidatorNFTTestHelper(blockscapeValidatorNFT) {}

    function setUp() public {
        _setupParticipants();

        _testInitContractSetup();
        _testInitRocketPoolSetup();
    }

    function testAccess() public {
        _testAccessControl();
    }

    function testVault() public {
        _testClosingVault();

        _blockscapeStakeRPL();

        _testOpeningVault();
    }

    function testStaking() public {
        _testInitStakeRPLReadyForStaking();

        uint256 ethDeposit = blockscapeValidatorNFT.getCurrentEthLimit();

        vm.expectRevert();
        vm.prank(poolStaker1);
        blockscapeValidatorNFT.depositValidatorNFT();

        // too much deposit
        vm.expectRevert();
        vm.prank(poolStaker1);
        blockscapeValidatorNFT.depositValidatorNFT{
            value: ethDeposit + 1 ether
        }();

        // too little deposit
        vm.expectRevert();
        vm.prank(poolStaker1);
        blockscapeValidatorNFT.depositValidatorNFT{
            value: ethDeposit - 1 ether
        }();

        _depositSoloStaker();

        // cannot deposit when pool is full
        vm.expectRevert();
        vm.prank(singleStaker);
        blockscapeValidatorNFT.depositValidatorNFT{value: ethDeposit}();

        assertEq(blockscapeValidatorNFT.isVaultOpen(), false);
        assertEq(
            blockscapeValidatorNFT.getBalance(),
            blockscapeValidatorNFT.getCurrentEthLimit()
        );
        assertEq(blockscapeValidatorNFT.getTokenID(), 2);
        assertEq(blockscapeValidatorNFT.totalSupply(), 1);

        // check metadata
        BlockscapeValidatorNFT.Metadata memory m = blockscapeValidatorNFT
            .getMetadata(1);

        BlockscapeValidatorNFT.Metadata memory shouldBeM;
        shouldBeM.stakedETH = ethDeposit;
        shouldBeM.stakedTimestamp = block.timestamp;
        assertEq(
            blockscapeValidatorNFT.contractURI(),
            "https://ipfs.blockscape.network/ipfs/QmP6bkWQT2Y2zdyB395nLTmqurV1SBGt8qK64hTBkbYr3W"
        );
        assertEq(
            blockscapeValidatorNFT.uri(1),
            "https://ipfs.blockscape.network/ipns/k51qzi5uqu5di5eo5fzr1zypdsz0zct39zpct9s4wesjustul1caeofak3zoej/1.json"
        );

        assertEq(m.stakedETH, shouldBeM.stakedETH);
        assertEq(m.stakedTimestamp, shouldBeM.stakedTimestamp);

        // only current tokenID has been changed
        m = blockscapeValidatorNFT.getMetadata(0);
        assertEq(m.stakedETH, 0);
        assertEq(m.stakedTimestamp, 0);
        m = blockscapeValidatorNFT.getMetadata(2);
        assertEq(m.stakedETH, 0);
        assertEq(m.stakedTimestamp, 0);
    }

    function testWithdrawal() public {
        _testInitAndDeposit();

        uint256 tokenID = blockscapeValidatorNFT.getTokenID() - 1;

        // only owner should be able to call function
        vm.expectRevert();
        vm.prank(poolStaker1);
        blockscapeValidatorNFT.prepareWithdrawalProcess(tokenID);

        // a withdrawal has to be prepared first
        vm.expectRevert();
        vm.prank(singleStaker);
        blockscapeValidatorNFT.withdrawFunds(tokenID);

        // // funds not yet moved
        // vm.expectRevert();
        // vm.prank(singleStaker);
        // blockscapeValidatorNFT.prepareWithdrawalProcess(tokenID);

        // vm.prank(emergency_role);
        // blockscapeValidatorNFT.openVault();

        vm.expectRevert();
        blockscapeValidatorNFT.updateValidator(1, minipoolAddr);

        vm.prank(emergency_role);
        blockscapeValidatorNFT.closeVault();

        vm.startPrank(rp_backend_role);
        blockscapeValidatorNFT.withdrawBatch();
        blockscapeValidatorNFT.updateValidator(1, minipoolAddr);
        vm.stopPrank();

        vm.expectRevert();
        vm.prank(singleStaker);
        blockscapeValidatorNFT.prepareWithdrawalProcess(tokenID);

        vm.warp(block.timestamp + 3 days);
        vm.expectEmit(true, true, true, false);
        emit UserRequestedWithdrawalVali(1, singleStaker, 20 ether, 8 ether, 0);
        vm.prank(singleStaker);
        blockscapeValidatorNFT.prepareWithdrawalProcess(tokenID);

        uint256 calcRewards = 0.1 ether;

        vm.expectRevert();
        vm.prank(foundryDeployer);
        blockscapeValidatorNFT.calcRewards(tokenID, calcRewards);

        vm.expectRevert();
        vm.prank(singleStaker);
        blockscapeValidatorNFT.calcRewards(tokenID, calcRewards);

        // sets the rewards through calculation process
        vm.prank(rp_backend_role);
        blockscapeValidatorNFT.calcRewards(tokenID, calcRewards);

        uint256 rewards = blockscapeValidatorNFT.tokenIDToExitReward(tokenID);
        assertEq(rewards, calcRewards);

        // already preparing
        vm.expectRevert();
        vm.prank(singleStaker);
        blockscapeValidatorNFT.prepareWithdrawalProcess(tokenID);

        // backend controller task
        uint256 validatorBalance = address(blockscapeValidatorNFT).balance;

        vm.prank(blockscapeRocketPoolNode);
        Address.sendValue(
            payable(address(blockscapeValidatorNFT)),
            blockscapeValidatorNFT.getCurrentEthLimit() + calcRewards
        );
        assertEq(
            address(blockscapeValidatorNFT).balance,
            validatorBalance +
                blockscapeValidatorNFT.getCurrentEthLimit() +
                calcRewards
        );

        uint256 timelockWithdrawal = blockscapeValidatorNFT.timelockWithdraw();

        // nft doesn't belong to caller
        vm.expectRevert();
        vm.prank(poolStaker1);
        blockscapeValidatorNFT.withdrawFunds(tokenID);

        // too early
        vm.expectRevert();
        vm.prank(singleStaker);
        blockscapeValidatorNFT.withdrawFunds(tokenID);

        vm.warp(block.timestamp + timelockWithdrawal - 1 minutes);

        // still too early
        vm.expectRevert();
        vm.prank(singleStaker);
        blockscapeValidatorNFT.withdrawFunds(tokenID);

        vm.warp(block.timestamp + timelockWithdrawal + 1 days);

        validatorBalance = address(blockscapeValidatorNFT).balance;
        uint256 stakerBalance = singleStaker.balance;

        vm.prank(singleStaker);
        blockscapeValidatorNFT.withdrawFunds(tokenID);

        assertEq(
            address(blockscapeValidatorNFT).balance,
            validatorBalance -
                blockscapeValidatorNFT.getCurrentEthLimit() -
                calcRewards
        );
        assertEq(
            singleStaker.balance,
            stakerBalance +
                blockscapeValidatorNFT.getCurrentEthLimit() +
                calcRewards
        );

        // already withdrawn
        vm.expectRevert();
        vm.prank(singleStaker);
        blockscapeValidatorNFT.withdrawFunds(tokenID);

        vm.expectRevert();
        vm.prank(singleStaker);
        blockscapeValidatorNFT.prepareWithdrawalProcess(tokenID);
    }

    function testCalcRewards() public {
        vm.prank(rp_backend_role);
        blockscapeValidatorNFT.calcRewards(1, 1337);
    }

    function testLowerRPCommFee8() public {
        vm.expectRevert();
        vm.prank(adj_config_role);
        blockscapeValidatorNFT.lowerRPCommFee8(15);

        vm.prank(adj_config_role);
        blockscapeValidatorNFT.lowerRPCommFee8(13);
    }

    function testGetValidatorAddress() public view {
        blockscapeValidatorNFT.getValidatorAddress(1);
    }

    function testBackgroundController() public {
        _testInitStakeRPLReadyForStaking();

        // nothing deposited yet
        vm.expectRevert();
        vm.prank(rp_backend_role);
        blockscapeValidatorNFT.withdrawBatch();

        assertEq(blockscapeValidatorNFT.getBalance(), 0 ether);

        // _warpAfterStakingCooldown();
        // _blockscapeUnstakeRPL();

        _depositSoloStaker();

        assertEq(
            blockscapeValidatorNFT.getBalance(),
            blockscapeValidatorNFT.getCurrentEthLimit()
        );

        availableRPL = blockscapeValidatorNFT.getAvailableRPLStake();

        // only owner should be able to call function
        vm.expectRevert();
        vm.prank(singleStaker);
        blockscapeValidatorNFT.withdrawBatch();

        vm.startPrank(rp_backend_role);
        blockscapeValidatorNFT.withdrawBatch();

        assertEq(blockscapeValidatorNFT.isVaultOpen(), false);
        assertEq(blockscapeValidatorNFT.getBalance(), 0 ether);

        // only rp_backend_role can call updateValidator
        vm.expectRevert();
        vm.prank(singleStaker);
        blockscapeValidatorNFT.updateValidator(1, minipoolAddr);

        vm.expectRevert();
        vm.prank(foundryDeployer);
        blockscapeValidatorNFT.updateValidator(1, minipoolAddr);

        // vault mustn't be open
        vm.prank(emergency_role);
        blockscapeValidatorNFT.openVault();

        vm.expectRevert("2344werfwef");
        blockscapeValidatorNFT.updateValidator(1, minipoolAddr);

        vm.prank(emergency_role);
        blockscapeValidatorNFT.closeVault();

        blockscapeValidatorNFT.updateValidator(1, minipoolAddr);

        // updateValidator can only be called once
        vm.expectRevert();
        blockscapeValidatorNFT.updateValidator(1, address(0x0));

        address validator = blockscapeValidatorNFT.getValidatorAddress(1);
        assertEq(validator, minipoolAddr);

        assertEq(blockscapeValidatorNFT.isVaultOpen(), true);

        vm.stopPrank();
    }

    function testUserRequestWithdraw() public {
        _testInitDepositAndUpdateVali();

        uint256 tokenID = 1;
        uint256 initWithdrawFee = blockscapeValidatorNFT.initWithdrawFee();

        uint256 amount = blockscapeValidatorNFT.calcWithdrawFee(
            1,
            foundryDeployer
        );
        assertEq(amount, 0);

        amount = blockscapeValidatorNFT.calcWithdrawFee(tokenID, singleStaker);
        assertEq(amount, initWithdrawFee);

        vm.startPrank(singleStaker);

        uint256 origTimestamp = block.timestamp;
        uint256 feesDropTimestamp = block.timestamp + 30747600;

        vm.warp(origTimestamp + 10 days);
        amount = blockscapeValidatorNFT.calcWithdrawFee(tokenID, singleStaker);
        assertEq(
            amount,
            initWithdrawFee - (initWithdrawFee / 365 days) * 10 days
        );

        vm.warp(origTimestamp + 100 days);
        amount = blockscapeValidatorNFT.calcWithdrawFee(tokenID, singleStaker);
        assertEq(
            amount,
            initWithdrawFee - (initWithdrawFee / 365 days) * 100 days
        );

        vm.warp(feesDropTimestamp);
        amount = blockscapeValidatorNFT.calcWithdrawFee(tokenID, singleStaker);
        assertEq(amount, 0.5 ether);

        vm.warp(feesDropTimestamp + 1000 days);
        amount = blockscapeValidatorNFT.calcWithdrawFee(tokenID, singleStaker);
        assertEq(amount, 0.5 ether);

        vm.stopPrank();
    }

    // function testChangeETHLimit() public {
    //     uint256 ethLimit = blockscapeValidatorNFT.getCurrentEthLimit();
    //     assertEq(ethLimit, ethLimit);

    //     // vm.expectRevert();
    //     // vm.prank(singleStaker);
    //     // blockscapeValidatorNFT.changeETHLimit8();

    //     // vm.expectRevert();
    //     // vm.prank(rp_backend_role);
    //     // blockscapeValidatorNFT.changeETHLimit8();

    //     // vm.expectEmit(false, false, false, true);
    //     // emit ETHLimitChanged(8 ether);
    //     // vm.prank(adj_config_role);
    //     // blockscapeValidatorNFT.changeETHLimit8();

    //     ethLimit = blockscapeValidatorNFT.getCurrentEthLimit();
    //     assertEq(ethLimit, 8 ether);
    // }

    function testSetWithdrawFee() public {
        vm.expectRevert();
        vm.prank(singleStaker);
        blockscapeValidatorNFT.changeWithdrawFee(1 ether);

        vm.expectRevert();
        vm.prank(rp_backend_role);
        blockscapeValidatorNFT.changeWithdrawFee(1 ether);

        vm.expectRevert();
        vm.prank(adj_config_role);
        blockscapeValidatorNFT.changeWithdrawFee(100 ether);

        vm.prank(adj_config_role);
        blockscapeValidatorNFT.changeWithdrawFee(1 ether);

        uint256 initWithdrawFee = blockscapeValidatorNFT.initWithdrawFee();
        assertEq(initWithdrawFee, 1 ether);
    }

    function testSetBlockscapeRocketPoolNode() public {
        assertEq(
            blockscapeRocketPoolNode,
            blockscapeValidatorNFT.blockscapeRocketPoolNode()
        );

        vm.expectRevert();
        vm.prank(singleStaker);
        blockscapeValidatorNFT.setBlockscapeRocketPoolNode(address(0x1));

        vm.expectRevert();
        vm.prank(rp_backend_role);
        blockscapeValidatorNFT.setBlockscapeRocketPoolNode(address(0x1));

        vm.prank(adj_config_role);
        blockscapeValidatorNFT.setBlockscapeRocketPoolNode(address(0x1));

        address blockscapeRocketPoolNode = blockscapeValidatorNFT
            .blockscapeRocketPoolNode();
        assertEq(blockscapeRocketPoolNode, address(0x1));
    }

    function testUpdateValiOnlyError() public {
        _testInitStakeRPLReadyForStaking();

        vm.expectRevert();
        vm.prank(emergency_role);
        blockscapeValidatorNFT.openVault();

        vm.expectRevert();
        vm.prank(rp_backend_role);
        blockscapeValidatorNFT.updateValidator(1, address(0x02));
    }

    function testDepositWithdrawalMulti() public {
        uint256 ethDeposit = blockscapeValidatorNFT.getCurrentEthLimit();

        _testInitAndDeposit();

        // can't deposit before updateValidator function has been run
        // and vault is opened
        //vm.expectRevert();
        // vm.prank(poolStaker1);
        // blockscapeValidatorNFT.depositValidatorNFT{value: ethDeposit}();

        // assertEq(blockscapeValidatorNFT.isVaultOpen(), false);

        vm.startPrank(rp_backend_role);
        blockscapeValidatorNFT.withdrawBatch();
        blockscapeValidatorNFT.updateValidator(1, minipoolAddr);

        vm.expectRevert();
        blockscapeValidatorNFT.updateValidator(1, address(0x0));
        vm.stopPrank();

        assertEq(blockscapeValidatorNFT.isVaultOpen(), true);

        vm.prank(poolStaker1);
        blockscapeValidatorNFT.depositValidatorNFT{value: ethDeposit}();

        // can't deposit before stake has been withdrawn
        vm.expectRevert();
        vm.prank(poolStaker2);
        blockscapeValidatorNFT.depositValidatorNFT{value: ethDeposit}();

        assertEq(blockscapeValidatorNFT.isVaultOpen(), false);

        vm.startPrank(rp_backend_role);
        blockscapeValidatorNFT.withdrawBatch();
        blockscapeValidatorNFT.updateValidator(2, address(0x1));
        vm.stopPrank();

        // assertEq(blockscapeValidatorNFT.isVaultOpen(), false);
        assertEq(blockscapeValidatorNFT.getBalance(), 0 ether);

        assertEq(blockscapeValidatorNFT.isVaultOpen(), true);

        _warpAfterStakingCooldown();
        _blockscapeUnstakeRPL();

        // no more RPL stake
        // vm.expectRevert();
        // vm.prank(poolStaker2);
        // blockscapeValidatorNFT.depositValidatorNFT{value: ethDeposit}();

        assertEq(blockscapeValidatorNFT.getBalance(), 0 ether);

        _blockscapeStakeRPL();

        // // change eth limit
        // vm.prank(foundryDeployer);
        // blockscapeValidatorNFT.changeETHLimit8();

        vm.expectRevert();
        vm.prank(poolStaker2);
        blockscapeValidatorNFT.depositValidatorNFT{value: ethDeposit*2}();

        vm.prank(poolStaker2);
        blockscapeValidatorNFT.depositValidatorNFT{value: ethDeposit}();
        assertEq(blockscapeValidatorNFT.getBalance(), ethDeposit );

        vm.startPrank(rp_backend_role);
        blockscapeValidatorNFT.withdrawBatch();
        blockscapeValidatorNFT.updateValidator(3, address(0x2));
        vm.stopPrank();

        uint256 tokenID = 3;

        uint256 calcRewards = blockscapeValidatorNFT.tokenIDToExitReward(3);

        vm.warp(block.timestamp + 3 days);

        vm.prank(poolStaker2);
        blockscapeValidatorNFT.prepareWithdrawalProcess(tokenID);

        // backend controller task
        uint256 validatorBalance = address(blockscapeValidatorNFT).balance;

        vm.prank(blockscapeRocketPoolNode);
        Address.sendValue(
            payable(address(blockscapeValidatorNFT)),
            blockscapeValidatorNFT.getCurrentEthLimit() + calcRewards
        );
        assertEq(
            address(blockscapeValidatorNFT).balance,
            validatorBalance +
                blockscapeValidatorNFT.getCurrentEthLimit() +
                calcRewards
        );

        uint256 timelockWithdrawal = blockscapeValidatorNFT.timelockWithdraw();

        vm.warp(block.timestamp + timelockWithdrawal + 1 days);

        validatorBalance = address(blockscapeValidatorNFT).balance;
        uint256 stakerBalance = singleStaker.balance;

        vm.deal(address(blockscapeValidatorNFT), stakerBalance);

        vm.prank(poolStaker2);
        blockscapeValidatorNFT.withdrawFunds(tokenID);

        // assertEq(
        //     address(blockscapeValidatorNFT).balance,
        //     validatorBalance -
        //         blockscapeValidatorNFT.getCurrentEthLimit() -
        //         calcRewards
        // );
        // assertEq(
        //     singleStaker.balance,
        //     stakerBalance +
        //         blockscapeValidatorNFT.getCurrentEthLimit() +
        //         calcRewards
        // );
    }

    function testFallbacks() public {
        vm.prank(singleStaker);
        payable(address(blockscapeValidatorNFT)).transfer(5 ether);

        vm.prank(poolStaker1);
        payable(address(blockscapeValidatorNFT)).transfer(25 ether);

        assertEq(blockscapeValidatorNFT.getBalance(), 30 ether);
    }

    function testInterfaces() public {
        bytes4 interfaceId = 0x0;
        bool supportsInterface = blockscapeValidatorNFT.supportsInterface(
            interfaceId
        );
        assertEq(supportsInterface, false);
    }
}

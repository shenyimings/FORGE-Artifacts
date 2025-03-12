// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {BlockscapeETHStakeNFT} from "src/BlockscapeETHStakeNFT.sol";
import {HelperContract} from "./utils/BlockscapeETHStakeNFTTestHelper.sol";

contract BlockscapeETHStakeNFTTest is Test, HelperContract {
    bytes validatorBytesAddress =
        hex"a2e78385831894094502727373588fc1794ea2800b2b6e614358fea78dcf0cc4d103008a53c665f294e31af0397253e3";

    address minipoolAddr = 0x626CA3f82a4A11C2226101eeEA35Fcc25a5fE91D;

    function setUp() public {
        _setupParticipants();
    }

    function testAccess() public {
        _testAccessControl();
    }

    function testVault() public {
        _testClosingVault();
        _blockscapeStakeRPL();
        _testOpeningVault();
    }

    function testSingleDeposit() public {
        _testDepositStakeNFT(1 ether);
    }

    function testClosedSingleDeposit() public {
        _testInitStakeRPLReadyForStaking();
        _testClosingVault();
        vm.expectRevert();
        blockscapeETHStakeNFT.depositStakeNFT{value: 1 ether}();
    }

    function testStaking() public {
        _testInitStakeRPLReadyForStaking();

        vm.expectRevert();
        vm.prank(poolStaker1);
        blockscapeETHStakeNFT.depositStakeNFT();

        // _testHasNodeEnoughRPLStake();

        vm.prank(poolStaker1);
        blockscapeETHStakeNFT.depositStakeNFT{value: 1 ether}();

        vm.prank(poolStaker2);
        blockscapeETHStakeNFT.depositStakeNFT{value: 4 ether}();

        vm.prank(poolStaker3);
        blockscapeETHStakeNFT.depositStakeNFT{value: 4 ether}();

        vm.prank(poolStaker4);
        blockscapeETHStakeNFT.depositStakeNFT{value: 7 ether}();

        vm.prank(poolStaker2);
        blockscapeETHStakeNFT.depositStakeNFT{value: 1.5 ether}();

        assertEq(blockscapeETHStakeNFT.isVaultOpen(), true);

        assertEq(blockscapeETHStakeNFT.getTokenID(), 6);
        assertEq(blockscapeETHStakeNFT.totalSupply(), 5);

        // check metadata
        BlockscapeETHStakeNFT.Metadata memory m = blockscapeETHStakeNFT
            .getMetadata(1);

        BlockscapeETHStakeNFT.Metadata memory shouldBeM;
        shouldBeM.stakedETH = 1 ether;
        shouldBeM.stakedTimestamp = block.timestamp;
        assertEq(
            blockscapeETHStakeNFT.contractURI(),
            "https://ipfs.blockscape.network/ipfs/TBD"
        );
        assertEq(
            blockscapeETHStakeNFT.uri(1),
            "https://ipfs.blockscape.network/ipns/TBD/1.json"
        );

        assertEq(m.stakedETH, shouldBeM.stakedETH);
        assertEq(m.stakedTimestamp, shouldBeM.stakedTimestamp);

        // only current tokenID has been changed
        m = blockscapeETHStakeNFT.getMetadata(0);
        assertEq(m.stakedETH, 0);
        assertEq(m.stakedTimestamp, 0);
        m = blockscapeETHStakeNFT.getMetadata(2);
        assertEq(m.stakedETH, 4 ether);
        assertEq(m.stakedTimestamp, shouldBeM.stakedTimestamp);
    }

    function testUpdatingStaking() public {
        _testUpdateStake(1);
    }

    function testWithdraw() public {
        _complete();
    }

    function testDepositWithdrawalMulti() public {
        _completeMulti();
    }

    function testSetBlockscapeRocketPoolNode() public {
        assertEq(
            blockscapeRocketPoolNode,
            blockscapeETHStakeNFT.blockscapeRocketPoolNode()
        );

        vm.expectRevert();
        vm.prank(singleStaker);
        blockscapeETHStakeNFT.setBlockscapeRocketPoolNode(address(0x1));

        vm.expectRevert();
        vm.prank(rp_backend_role);
        blockscapeETHStakeNFT.setBlockscapeRocketPoolNode(address(0x1));

        vm.prank(adj_config_role);
        blockscapeETHStakeNFT.setBlockscapeRocketPoolNode(address(0x1));

        address blockscapeRocketPoolNode = blockscapeETHStakeNFT
            .blockscapeRocketPoolNode();
        assertEq(blockscapeRocketPoolNode, address(0x1));
    }

    function testMiscellaneous() public {
        _testnoRPLOpenVault();
        _testInitStakeRPLReadyForStaking();
        _testGetAvailableRPLStake();
        // _testGetReqRPLStake();
        // _testHasNodeEnoughRPLStake();

        _testUri();
        _testContractURI();
        _testlowerTimelockWithdraw();

        _testCloseVault();
        _testOpenVault();
        _textIsVaultOpen();
        //_testReceive();
        payable(blockscapeETHStakeNFT).transfer(20 ether);
        _textLowerWithdrawFee(5e18);

        vm.expectRevert();
        _textLowerWithdrawFee(21e18);

        _testSupportsInterface();

        //_testCalcWithdrawFee(1);
    }

    function testTemp() public {
        _testSupportsInterface();
    }
}

pragma solidity 0.8.16;

// SPDX-License-Identifier: BUSL-1.1

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import {console} from "forge-std/console.sol";
import {BlockscapeETHStakeNFT} from "src/BlockscapeETHStakeNFT.sol";
import "openzeppelin-contracts/access/AccessControl.sol";
import "./RocketPool.sol";

//import "src_2_audit_fixes/utils/BlockscapeShared.sol";

// //import {RocketPoolHelperContract} from "./RocketPool.sol";

contract HelperContract is Test, AccessControl, RocketPoolHelperContract {
    address foundryDeployer = 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84;
    address foundryEmergency = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
    // address blockscapeRocketPoolNode =
    //     0xF6132f532ABc3902EA2DcaE7f8D7FCCdF7Ba4982;

    BlockscapeETHStakeNFT blockscapeETHStakeNFT;

    // address internal deployer;
    address internal rp_backend_role;
    address internal adj_config_role;
    address internal emergency_role;

    address internal singleStaker;
    address internal poolStaker1;
    address internal poolStaker2;
    address internal poolStaker3;
    address internal poolStaker4;
    address internal poolStaker5;

    uint256 availableRPL;
    uint256 reqRPL;
    uint256 minimumRPLStake;
    uint256 minipoolLimit;
    uint256 fee;
    uint256 apr;

    /// @dev role to adjust the config of the smart contract parameters
    bytes32 public constant ADJ_CONFIG_ROLE = keccak256("ADJ_CONFIG_ROLE");

    /// @dev role for the backendController executer
    bytes32 public constant RP_BACKEND_ROLE = keccak256("RP_BACKEND_ROLE");

    /// @dev role to open / close vault in cases of emergencies
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    event StakeUpdated(
        uint256 indexed _tokenID,
        address indexed _owner,
        uint256 _newStake
    );

    event UserRequestedWithdrawalStake(
        uint256 indexed _tokenID,
        address indexed _user,
        uint256 _stakedETH,
        uint256 _rewards
    );

    function _setupParticipants() internal {
        vm.prank(foundryDeployer);
        blockscapeETHStakeNFT = new BlockscapeETHStakeNFT();

        adj_config_role = foundryDeployer; //vm.addr(uint256(uint160(foundryDeployer)));
        emergency_role = foundryEmergency; //vm.addr(uint256(uint160(foundryDeployer)));
        rp_backend_role = address(blockscapeRocketPoolNode);

        vm.deal(rp_backend_role, 1 ether);
        vm.label(rp_backend_role, "rp_backend");

        vm.deal(adj_config_role, 1 ether);
        vm.label(adj_config_role, "adj_config");

        vm.label(emergency_role, "emergency");

        singleStaker = vm.addr(0xDe0);
        vm.deal(singleStaker, 100 ether);
        vm.label(singleStaker, "singleStaker");

        poolStaker1 = vm.addr(0xDe1);
        vm.deal(poolStaker1, 100 ether);
        vm.label(poolStaker1, "poolStaker1");

        poolStaker2 = vm.addr(0xDe2);
        vm.deal(poolStaker2, 100 ether);
        vm.label(poolStaker2, "poolStaker2");

        poolStaker3 = vm.addr(0xDe3);
        vm.deal(poolStaker3, 100 ether);
        vm.label(poolStaker3, "poolStaker3");

        poolStaker4 = vm.addr(0xDe4);
        vm.deal(poolStaker4, 100 ether);
        vm.label(poolStaker4, "poolStaker4");

        poolStaker5 = vm.addr(0xDe5);
        vm.deal(poolStaker5, 100 ether);
        vm.label(poolStaker5, "poolStaker5");
    }

    function _testAccessControl() internal {
        assertEq(
            blockscapeETHStakeNFT.hasRole(ADJ_CONFIG_ROLE, foundryDeployer),
            true
        );

        assertEq(
            blockscapeETHStakeNFT.hasRole(
                RP_BACKEND_ROLE,
                blockscapeRocketPoolNode
            ),
            true
        );
        assertEq(
            blockscapeETHStakeNFT.hasRole(EMERGENCY_ROLE, foundryEmergency),
            true
        );
    }

    function _testClosingVault() internal {
        assertEq(blockscapeETHStakeNFT.isVaultOpen(), true);

        // only EMERGENCY_ROLE should be able to call function
        vm.expectRevert(
            "AccessControl: account 0xd3f7f429d80b7cdf98026230c1997b3e8a780dc5 is missing role 0xbf233dd2aafeb4d50879c4aa5c81e96d92f6e6945c906a58f9f2d1c1631b4b26"
        );
        vm.prank(singleStaker);
        blockscapeETHStakeNFT.closeVault();

        vm.expectRevert(
            "AccessControl: account 0xb4c79dab8f259c7aee6e5b2aa729821864227e84 is missing role 0xbf233dd2aafeb4d50879c4aa5c81e96d92f6e6945c906a58f9f2d1c1631b4b26"
        );
        vm.prank(adj_config_role);
        blockscapeETHStakeNFT.closeVault();

        vm.expectRevert(
            "AccessControl: account 0xf6132f532abc3902ea2dcae7f8d7fccdf7ba4982 is missing role 0xbf233dd2aafeb4d50879c4aa5c81e96d92f6e6945c906a58f9f2d1c1631b4b26"
        );
        vm.prank(rp_backend_role);
        blockscapeETHStakeNFT.closeVault();

        assertEq(blockscapeETHStakeNFT.isVaultOpen(), true);

        // console.log("emergency_role", foundryDeployer);

        vm.prank(foundryEmergency);
        blockscapeETHStakeNFT.closeVault();

        assertEq(blockscapeETHStakeNFT.isVaultOpen(), false);
    }

    function _testOpeningVault() internal {
        assertEq(blockscapeETHStakeNFT.isVaultOpen(), false);

        // only EMERGENCY_ROLE should be able to call function
        vm.expectRevert(
            "AccessControl: account 0xd3f7f429d80b7cdf98026230c1997b3e8a780dc5 is missing role 0xbf233dd2aafeb4d50879c4aa5c81e96d92f6e6945c906a58f9f2d1c1631b4b26"
        );
        vm.prank(singleStaker);
        blockscapeETHStakeNFT.openVault();

        vm.expectRevert(
            "AccessControl: account 0xb4c79dab8f259c7aee6e5b2aa729821864227e84 is missing role 0xbf233dd2aafeb4d50879c4aa5c81e96d92f6e6945c906a58f9f2d1c1631b4b26"
        );
        vm.prank(adj_config_role);
        blockscapeETHStakeNFT.openVault();

        vm.expectRevert(
            "AccessControl: account 0xf6132f532abc3902ea2dcae7f8d7fccdf7ba4982 is missing role 0xbf233dd2aafeb4d50879c4aa5c81e96d92f6e6945c906a58f9f2d1c1631b4b26"
        );
        vm.prank(rp_backend_role);
        blockscapeETHStakeNFT.openVault();

        assertEq(blockscapeETHStakeNFT.isVaultOpen(), false);

        vm.prank(foundryEmergency);
        blockscapeETHStakeNFT.openVault();

        assertEq(blockscapeETHStakeNFT.isVaultOpen(), true);
    }

    function _testSetMetadata() internal {}

    function _testDepositStakeNFT(uint256 _value) internal {
        vm.expectRevert();
        blockscapeETHStakeNFT.depositStakeNFT{value: _value}();

        _testInitStakeRPLReadyForStaking();
        vm.prank(singleStaker);
        blockscapeETHStakeNFT.depositStakeNFT{value: _value}();
        assertEq(blockscapeETHStakeNFT.balanceOf(singleStaker, 1), 1);
        assertEq(blockscapeETHStakeNFT.getPoolSupply(), 1 ether);
    }

    function _testUpdateStake(uint256 _tokenID) internal {
        vm.expectRevert();
        blockscapeETHStakeNFT.updateStake(_tokenID);

        _testInitStakeRPLReadyForStaking();

        vm.prank(singleStaker);
        blockscapeETHStakeNFT.depositStakeNFT{value: 1 ether}();
        assertEq(blockscapeETHStakeNFT.balanceOf(singleStaker, 1), 1);
        assertEq(blockscapeETHStakeNFT.getPoolSupply(), 1 ether);

        vm.prank(singleStaker);
        vm.expectRevert();
        blockscapeETHStakeNFT.updateStake(3);

        vm.prank(singleStaker);
        vm.expectRevert();
        blockscapeETHStakeNFT.updateStake{value: 0 ether}(1);

        vm.expectEmit(true, true, false, false);
        emit StakeUpdated(1, singleStaker, 5 ether);

        vm.prank(singleStaker);
        blockscapeETHStakeNFT.updateStake{value: 5 ether}(1);

        assertEq(blockscapeETHStakeNFT.balanceOf(singleStaker, 1), 1);
        assertEq(blockscapeETHStakeNFT.getPoolSupply(), 6 ether);
    }

    function _testPrepareWithdrawProcess(uint256 _tokenID) internal {
        vm.warp(block.timestamp + 365 days);
        assertEq(blockscapeETHStakeNFT.balanceOf(singleStaker, 1), 1);

        vm.expectEmit(true, true, true, false);
        emit UserRequestedWithdrawalStake(1, singleStaker, 5 ether, 0);

        vm.prank(singleStaker);
        blockscapeETHStakeNFT.prepareWithdrawalProcess(_tokenID);
    }

    function _testWithdrawFunds(uint256 _tokenID) internal {
        vm.expectRevert();
        vm.warp(block.timestamp);
        vm.prank(singleStaker);
        blockscapeETHStakeNFT.withdrawFunds(_tokenID);

        vm.warp(block.timestamp + 8 days);
        vm.prank(singleStaker);
        assertEq(blockscapeETHStakeNFT.balanceOf(singleStaker, 1), 1);

        blockscapeETHStakeNFT.withdrawFunds(_tokenID);
    }

    function _complete() public {
        _testInitStakeRPLReadyForStaking();
        vm.prank(singleStaker);
        blockscapeETHStakeNFT.depositStakeNFT{value: 4 ether}();
        assertEq(blockscapeETHStakeNFT.balanceOf(singleStaker, 1), 1);
        assertEq(blockscapeETHStakeNFT.getPoolSupply(), 4 ether);

        vm.prank(singleStaker);
        blockscapeETHStakeNFT.updateStake{value: 6 ether}(1);

        assertEq(blockscapeETHStakeNFT.getPoolSupply(), 10 ether);

        vm.warp(block.timestamp + 365 days);
        vm.prank(singleStaker);
        blockscapeETHStakeNFT.prepareWithdrawalProcess(1);

        vm.deal(address(blockscapeETHStakeNFT), 100 ether);

        vm.expectRevert();
        vm.warp(block.timestamp + 6 days);
        vm.prank(singleStaker);
        blockscapeETHStakeNFT.withdrawFunds(1);

        vm.warp(block.timestamp + 8 days);
        vm.prank(singleStaker);
        blockscapeETHStakeNFT.withdrawFunds(1);
    }

    function _completeMulti() public {
        _testInitStakeRPLReadyForStaking();
        vm.prank(singleStaker);
        blockscapeETHStakeNFT.depositStakeNFT{value: 4 ether}();
        assertEq(blockscapeETHStakeNFT.balanceOf(singleStaker, 1), 1);
        assertEq(blockscapeETHStakeNFT.getPoolSupply(), 4 ether);

        fee = blockscapeETHStakeNFT.calcWithdrawFee(1, singleStaker);

        assertEq(fee, 20e18);

        // Expect 0 fee for unknown token
        assertEq(blockscapeETHStakeNFT.calcWithdrawFee(1337, singleStaker), 0);

        // Expect 0 fee for unknown token / sender
        assertEq(blockscapeETHStakeNFT.calcWithdrawFee(1, msg.sender), 0);

        vm.warp(block.timestamp + 100 days);
        fee = blockscapeETHStakeNFT.calcWithdrawFee(1, singleStaker);
        assertEq(fee, 14520547945208000000);

        // 0.5 % after 365 days
        vm.warp(block.timestamp + 265 days);
        fee = blockscapeETHStakeNFT.calcWithdrawFee(1, singleStaker);
        assertEq(fee, 5e17);

        vm.warp(block.timestamp - 365 days);

        vm.deal(poolStaker1, 320 ether);

        vm.prank(poolStaker1);
        blockscapeETHStakeNFT.depositStakeNFT{value: 320 ether}();
        assertEq(blockscapeETHStakeNFT.balanceOf(poolStaker1, 2), 1);
        assertEq(blockscapeETHStakeNFT.getPoolSupply(), 324 ether);

        vm.prank(singleStaker);
        blockscapeETHStakeNFT.updateStake{value: 6 ether}(1);

        vm.expectRevert();
        vm.prank(singleStaker);
        blockscapeETHStakeNFT.updateStake{value: 6 ether}(2);

        assertEq(blockscapeETHStakeNFT.getPoolSupply(), 330 ether);

        vm.warp(block.timestamp + 365 days);
        vm.prank(singleStaker);
        blockscapeETHStakeNFT.prepareWithdrawalProcess(1);

        vm.expectRevert();
        vm.prank(singleStaker);
        blockscapeETHStakeNFT.prepareWithdrawalProcess(2);

        vm.prank(poolStaker1);
        blockscapeETHStakeNFT.prepareWithdrawalProcess(2);

        vm.deal(address(blockscapeETHStakeNFT), 3000 ether);

        assertEq(
            blockscapeETHStakeNFT.tokenIDToExitReward(1),
            6828726602986459200
        );

        vm.warp(block.timestamp + 8 days);
        vm.prank(singleStaker);
        blockscapeETHStakeNFT.withdrawFunds(1);

        vm.expectRevert();
        vm.prank(singleStaker);
        blockscapeETHStakeNFT.withdrawFunds(2);

        vm.prank(poolStaker1);
        blockscapeETHStakeNFT.withdrawFunds(2);
    }

    function _testSupportsInterface() internal {
        assertEq(
            blockscapeETHStakeNFT.supportsInterface(
                type(IAccessControl).interfaceId
            ),
            true
        );
        assertEq(blockscapeETHStakeNFT.supportsInterface(0x80ac58ce), false);
    }

    function _testGetPoolSupply() internal view returns (uint256) {
        return blockscapeETHStakeNFT.getPoolSupply();
    }

    function _testTotalSupply() internal {
        assertEq(blockscapeETHStakeNFT.totalSupply(), 0);
    }

    function _testContractURI() internal {
        assertEq(
            blockscapeETHStakeNFT.contractURI(),
            "https://ipfs.blockscape.network/ipfs/TBD"
        );
    }

    function _testUri() internal {
        assertEq(
            blockscapeETHStakeNFT.uri(1),
            "https://ipfs.blockscape.network/ipns/TBD/1.json"
        );
        assertEq(
            blockscapeETHStakeNFT.uri(5),
            "https://ipfs.blockscape.network/ipns/TBD/5.json"
        );
        assertEq(
            blockscapeETHStakeNFT.uri(9999999999999999991390124809148),
            "https://ipfs.blockscape.network/ipns/TBD/9999999999999999991390124809148.json"
        );
    }

    function _testGetAvailableRPLStake() internal {
        assertEq(
            blockscapeETHStakeNFT.getAvailableRPLStake(),
            84061696117349943401
        );
    }

    // function _testGetReqRPLStake() internal {
    //     assertEq(blockscapeETHStakeNFT.getReqRPLStake(), 0);
    // }

    // function _testHasNodeEnoughRPLStake() internal {
    //     assertEq(blockscapeETHStakeNFT.hasNodeEnoughRPLStake(), true);
    // }

    function _testSetBlockscapeRocketPoolNode() internal {
        vm.prank(foundryDeployer);
        blockscapeETHStakeNFT.setBlockscapeRocketPoolNode(
            0xca317A4ecCbe0Dd5832dE2A7407e3c03F88b2CdD
        );
    }

    function _testGetTokenID() internal view {
        blockscapeETHStakeNFT.getTokenID();
    }

    function _testGetBalance() internal view {
        blockscapeETHStakeNFT.getBalance();
    }

    function _testGetMetadata(uint256 _tokenID) internal view {
        blockscapeETHStakeNFT.getMetadata(_tokenID);
    }

    function _testlowerTimelockWithdraw() internal {
        vm.prank(foundryDeployer);
        blockscapeETHStakeNFT.changeTimelockWithdraw(6 days);

        vm.expectRevert();
        vm.prank(foundryDeployer);
        blockscapeETHStakeNFT.changeTimelockWithdraw(12 days);
    }

    function _testnoRPLOpenVault() internal {
        vm.expectRevert();
        vm.prank(foundryEmergency);
        blockscapeETHStakeNFT.openVault();
    }

    function _testOpenVault() internal {
        vm.prank(foundryEmergency);
        blockscapeETHStakeNFT.openVault();

        vm.expectRevert();
        vm.prank(foundryEmergency);
        blockscapeETHStakeNFT.openVault();
    }

    function _testCloseVault() internal {
        vm.prank(foundryEmergency);
        blockscapeETHStakeNFT.closeVault();
    }

    function _textIsVaultOpen() internal {
        assertEq(blockscapeETHStakeNFT.isVaultOpen(), true);
    }

    function _textLowerWithdrawFee(uint256 _newLimit) internal {
        vm.prank(foundryDeployer);
        blockscapeETHStakeNFT.changeWithdrawFee(_newLimit);
    }

    function _testReceive() internal {
        payable(blockscapeETHStakeNFT).transfer(2 ether);
        assertEq(address(blockscapeETHStakeNFT).balance, 2 ether);
    }

    function _testInitStakeRPLReadyForStaking() internal {
        _testInitContractSetup();
        _testInitRocketPoolSetup();

        _blockscapeStakeRPL();

        _testContractSetupAfterRPLStaking();
    }

    function _testInitStakeRPLReadyForStakingOtherNode() internal {
        _testInitContractSetup();
        //_testInitRocketPoolSetup();

        _blockscapeStakeRPLOtherNode();

        //_testContractSetupAfterRPLStaking();
    }

    function _testInitContractSetup() internal {
        assertEq(blockscapeETHStakeNFT.name(), "Blockscape ETH Stake NFTs");
        assertEq(blockscapeETHStakeNFT.symbol(), "BSS");
        assertEq(blockscapeETHStakeNFT.totalSupply(), 0);

        _testInitRocketPoolSetup();
        _testInitBlockscapeVaultSetup();
        _testInitBlockscapeStakingSetup();
    }

    function _testInitRocketPoolSetup() internal {
        assertEq(blockscapeETHStakeNFT.getAvailableRPLStake(), 0);
        // assertEq(blockscapeETHStakeNFT.getReqRPLStake(), 0);
        assertEq(
            rocketNodeStaking.getNodeMinimumRPLStake(blockscapeRocketPoolNode),
            0
        );
        assertEq(
            rocketNodeStaking.getNodeMinipoolLimit(blockscapeRocketPoolNode),
            0
        );
        assertEq(blockscapeETHStakeNFT.rpComm8(), 14);
    }

    function _testContractSetupAfterRPLStaking() internal {
        assertEq(blockscapeETHStakeNFT.getBalance(), 0 ether);
        assertEq(blockscapeETHStakeNFT.totalSupply(), 0);

        // RocketPool
        assertEq(blockscapeETHStakeNFT.getAvailableRPLStake(), rplStakeAsPerTx);
        // assertEq(blockscapeETHStakeNFT.getReqRPLStake(), 0);
        assertEq(
            rocketNodeStaking.getNodeMinimumRPLStake(blockscapeRocketPoolNode),
            0
        );
        assertEq(
            rocketNodeStaking.getNodeMinipoolLimit(blockscapeRocketPoolNode),
            1
        );
        assertEq(blockscapeETHStakeNFT.rpComm8(), 14);
    }

    function _testInitBlockscapeVaultSetup() internal {
        assertEq(blockscapeETHStakeNFT.isVaultOpen(), true);
    }

    function _testInitBlockscapeStakingSetup() internal {
        assertEq(blockscapeETHStakeNFT.initWithdrawFee(), 20 * 1e18);
        assertEq(blockscapeETHStakeNFT.getTokenID(), 1);
        assertEq(blockscapeETHStakeNFT.getBalance(), 0 ether);

        assertEq(blockscapeETHStakeNFT.getMetadata(0).stakedETH, 0 ether);
        assertEq(blockscapeETHStakeNFT.getMetadata(0).stakedTimestamp, 0);
    }
}

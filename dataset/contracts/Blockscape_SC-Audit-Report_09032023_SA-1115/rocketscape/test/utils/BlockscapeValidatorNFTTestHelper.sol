pragma solidity 0.8.16;

// SPDX-License-Identifier: BUSL-1.1

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {BlockscapeValidatorNFT} from "src/BlockscapeValidatorNFT.sol";
import {RocketPoolHelperContract} from "./RocketPool.sol";

contract BlockscapeValidatorNFTTestHelper is Test, RocketPoolHelperContract {
    address minipoolAddr = 0x626CA3f82a4A11C2226101eeEA35Fcc25a5fE91D;

    address foundryDeployer = 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84;

    address foundryEmergency = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;

    // address internal deployer;
    address internal rp_backend_role;
    address internal adj_config_role;
    address internal emergency_role;

    address internal singleStaker;
    address internal poolStaker1;
    address internal poolStaker2;

    uint256 availableRPL;
    uint256 reqRPL;
    uint256 minimumRPLStake;
    uint256 minipoolLimit;

    BlockscapeValidatorNFT blockscapeValidatorNFT;

    constructor(BlockscapeValidatorNFT _blockscapeValidatorNFT) {
        blockscapeValidatorNFT = _blockscapeValidatorNFT;
    }

    function _setupParticipants() internal {
        vm.prank(foundryDeployer);
        blockscapeValidatorNFT = new BlockscapeValidatorNFT();

        adj_config_role = foundryDeployer; //vm.addr(uint256(uint160(foundryDeployer)));
        emergency_role = foundryEmergency; //vm.addr(uint256(uint160(foundryDeployer)));
        // deployer = vm.addr(0xDe);

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
    }

    function _testInitContractSetup() internal {
        assertEq(blockscapeValidatorNFT.name(), "Blockscape Validator NFTs");
        assertEq(blockscapeValidatorNFT.symbol(), "BSV");
        assertEq(blockscapeValidatorNFT.totalSupply(), 0);
        assertEq(
            blockscapeValidatorNFT.getCurrentEthLimit(),
            blockscapeValidatorNFT.getCurrentEthLimit()
        );

        _testInitRocketPoolSetup();
        _testInitBlockscapeVaultSetup();
        _testInitBlockscapeStakingSetup();
    }

    function _testInitRocketPoolSetup() internal {
        assertEq(blockscapeValidatorNFT.getAvailableRPLStake(), 0);
        // assertEq(blockscapeValidatorNFT.getReqRPLStake(), 0);
        assertEq(
            rocketNodeStaking.getNodeMinimumRPLStake(blockscapeRocketPoolNode),
            0
        );
        assertEq(
            rocketNodeStaking.getNodeMinipoolLimit(blockscapeRocketPoolNode),
            0
        );
        assertEq(blockscapeValidatorNFT.rpComm8(), 14);
    }

    function _testInitBlockscapeVaultSetup() internal {
        assertEq(blockscapeValidatorNFT.isVaultOpen(), true);
    }

    function _testInitBlockscapeStakingSetup() internal {
        assertEq(blockscapeValidatorNFT.initWithdrawFee(), 20 * 1e18);
        assertEq(blockscapeValidatorNFT.getTokenID(), 1);
        assertEq(blockscapeValidatorNFT.getBalance(), 0 ether);

        assertEq(blockscapeValidatorNFT.getMetadata(0).stakedETH, 0 ether);
        assertEq(blockscapeValidatorNFT.getMetadata(0).stakedTimestamp, 0);
    }

    function _testContractSetupAfterRPLStaking() internal {
        assertEq(blockscapeValidatorNFT.getBalance(), 0 ether);
        assertEq(blockscapeValidatorNFT.totalSupply(), 0);
        assertEq(
            blockscapeValidatorNFT.getCurrentEthLimit(),
            blockscapeValidatorNFT.getCurrentEthLimit()
        );

        // RocketPool
        assertEq(
            blockscapeValidatorNFT.getAvailableRPLStake(),
            rplStakeAsPerTx
        );
        // assertEq(blockscapeValidatorNFT.getReqRPLStake(), 0);
        assertEq(
            rocketNodeStaking.getNodeMinimumRPLStake(blockscapeRocketPoolNode),
            0
        );
        assertEq(
            rocketNodeStaking.getNodeMinipoolLimit(blockscapeRocketPoolNode),
            1
        );
        assertEq(blockscapeValidatorNFT.rpComm8(), 14);
    }

    function _testInitStakeRPLReadyForStaking() internal {
        _testInitContractSetup();
        _testInitRocketPoolSetup();

        _blockscapeStakeRPL();

        _testContractSetupAfterRPLStaking();
    }

    function _depositSoloStaker() internal {
        uint256 value = blockscapeValidatorNFT.getCurrentEthLimit();
        vm.prank(singleStaker);
        blockscapeValidatorNFT.depositValidatorNFT{value: value}();
    }

    function _testInitAndDeposit() internal {
        _testInitStakeRPLReadyForStaking();

        _depositSoloStaker();

        assertEq(blockscapeValidatorNFT.isVaultOpen(), false);
        assertEq(
            blockscapeValidatorNFT.getBalance(),
            blockscapeValidatorNFT.getCurrentEthLimit()
        );
        assertEq(blockscapeValidatorNFT.balanceOf(singleStaker, 0), 0);
        assertEq(blockscapeValidatorNFT.balanceOf(singleStaker, 1), 1);
        assertEq(blockscapeValidatorNFT.balanceOf(singleStaker, 2), 0);
        assertEq(blockscapeValidatorNFT.getTokenID(), 2);
        assertEq(blockscapeValidatorNFT.totalSupply(), 1);
    }

    function _testInitDepositAndUpdateVali() internal {
        _testInitAndDeposit();

        vm.startPrank(rp_backend_role);
        blockscapeValidatorNFT.withdrawBatch();
        blockscapeValidatorNFT.updateValidator(1, minipoolAddr);
        vm.stopPrank();
    }

    function _testAccessControl() internal {
        // assertEq(
        //     blockscapeValidatorNFT.hasRole(
        //         blockscapeValidatorNFT.DEFAULT_ADMIN_ROLE(),
        //         foundryDeployer
        //     ),
        //     true
        // );
        assertEq(
            blockscapeValidatorNFT.hasRole(
                keccak256("ADJ_CONFIG_ROLE"),
                foundryDeployer
            ),
            true
        );
        assertEq(
            blockscapeValidatorNFT.hasRole(
                keccak256("RP_BACKEND_ROLE"),
                blockscapeValidatorNFT.blockscapeRocketPoolNode()
            ),
            true
        );
        assertEq(
            blockscapeValidatorNFT.hasRole(
                keccak256("EMERGENCY_ROLE"),
                foundryEmergency
            ),
            true
        );
    }

    function _testClosingVault() internal {
        // only owner should be able to call function
        string memory firstPart = "AccessControl: account ";
        string
            memory roleMissing = " is missing role 0xbf233dd2aafeb4d50879c4aa5c81e96d92f6e6945c906a58f9f2d1c1631b4b26";

        // string memory addressString = abi.encodePacked(singleStaker);
        string memory revertString = string.concat(
            string.concat(
                firstPart,
                // addressString
                "0xd3f7f429d80b7cdf98026230c1997b3e8a780dc5"
            ),
            roleMissing
        );

        vm.expectRevert(abi.encodePacked(revertString));
        vm.prank(singleStaker);
        blockscapeValidatorNFT.closeVault();

        revertString = string.concat(
            string.concat(
                firstPart,
                "0xf6132f532abc3902ea2dcae7f8d7fccdf7ba4982"
            ),
            roleMissing
        );

        vm.expectRevert(abi.encodePacked(revertString));
        vm.prank(rp_backend_role);
        blockscapeValidatorNFT.closeVault();

        vm.prank(emergency_role);
        blockscapeValidatorNFT.closeVault();
        assertEq(blockscapeValidatorNFT.isVaultOpen(), false);
    }

    function _testOpeningVault() internal {
        // only owner should be able to call function
        string memory firstPart = "AccessControl: account ";
        string
            memory roleMissing = " is missing role 0xbf233dd2aafeb4d50879c4aa5c81e96d92f6e6945c906a58f9f2d1c1631b4b26";

        string memory revertString = string.concat(
            string.concat(
                firstPart,
                "0xd3f7f429d80b7cdf98026230c1997b3e8a780dc5"
            ),
            roleMissing
        );

        vm.expectRevert(abi.encodePacked(revertString));
        vm.prank(singleStaker);
        blockscapeValidatorNFT.openVault();

        revertString = string.concat(
            string.concat(
                firstPart,
                "0xf6132f532abc3902ea2dcae7f8d7fccdf7ba4982"
            ),
            roleMissing
        );

        vm.expectRevert(abi.encodePacked(revertString));
        vm.prank(rp_backend_role);
        blockscapeValidatorNFT.openVault();

        vm.prank(emergency_role);
        blockscapeValidatorNFT.openVault();
        assertEq(blockscapeValidatorNFT.isVaultOpen(), true);
    }

    function _testSetMetadata() internal {}
}

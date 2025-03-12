pragma solidity 0.8.16;

// SPDX-License-Identifier: BUSL-1.1

import "forge-std/Test.sol";

import {console} from "forge-std/console.sol";
import {BlockscapeValidatorNFT} from "src/BlockscapeValidatorNFT.sol";

abstract contract HelperContract is Test {
    address foundryDeployer = 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84;
    address blockscapeRocketPoolNode =
        0xF6132f532ABc3902EA2DcaE7f8D7FCCdF7Ba4982;

    uint256 immutable curETHlimit = 16 ether;

    BlockscapeValidatorNFT blockscapeValidatorNFT;

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

    constructor() {}

    function _setupParticipants() internal {
        vm.prank(foundryDeployer);
        blockscapeValidatorNFT = new BlockscapeValidatorNFT();

        blockscapeValidatorNFT.getCurrentEthLimit();

        adj_config_role = vm.addr(uint256(uint160(foundryDeployer)));
        emergency_role = vm.addr(uint256(uint160(foundryDeployer)));
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
}

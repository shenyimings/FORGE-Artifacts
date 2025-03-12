// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {CREATE3Script} from "./base/CREATE3Script.sol";
import {RewardTracker} from "../src/staking/RewardTracker.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

contract DeployScript is CREATE3Script {
    bytes32 public constant DISTRIBUTOR = keccak256("DISTRIBUTOR");
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    constructor() CREATE3Script(vm.envString("VERSION")) {}

    function run() external returns (RewardTracker sQuartz) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        MockERC20 quartz;
        address WETH = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9; // weth on sepolia

        vm.startBroadcast(deployerPrivateKey);

        quartz = new MockERC20("Mock Quartz", "QUARTZ", 18);
        sQuartz = new RewardTracker(address(msg.sender), address(quartz), "Staked Quartz", "sQuartz", WETH, 30 days);

        vm.stopBroadcast();
    }
}

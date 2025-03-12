// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract BaseTest is Test {
    using SafeERC20 for IERC20;

    address public alice;
    address public bob;
    address public chad;
    address public degen;
    address public eve;
    address public whale;

    function createUser(uint32 i) public returns (address) {
        string memory mnemonic = "test test test test test test test test test test test junk";
        uint256 privateKey = vm.deriveKey(mnemonic, i);
        address user = vm.addr(privateKey);
        vm.deal(user, 100 ether);
        return user;
    }

    function eq(string memory str1, string memory str2) public pure returns (bool) {
        return keccak256(abi.encodePacked(str1)) == keccak256(abi.encodePacked(str2));
    }

    function init() public {
        init(0xdeadbeef);

        alice = createUser(0);
        bob = createUser(1);
        chad = createUser(2);
        degen = createUser(3);
        eve = createUser(4);

        whale = createUser(100);
    }

    function init(uint256 fork) public {
        if (fork == 0xdeadbeef) {
            fork = vm.createFork(vm.envString("MAINNET_RPC_URL"), 18260000);
        }

        vm.selectFork(fork);
    }
}

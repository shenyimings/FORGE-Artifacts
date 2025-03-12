// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "openzeppelin/token/ERC20/IERC20.sol";

import { IWrappedETH } from "../src/interfaces/IWrappedETH.sol";
import { IRewardTracker } from "../src/interfaces/gmx/IRewardTracker.sol";

contract BaseTest is Test {
    string ARBITRUM_RPC_URL = vm.envString("ARBITRUM_RPC_URL");

    IERC20 usdt = IERC20(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
    IERC20 weth = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);

    function createTestUser(uint32 i) public returns (address) {
        string memory mnemonic = "test test test test test test test test test test test junk";
        uint256 privateKey = vm.deriveKey(mnemonic, i);
        address user = vm.addr(privateKey);
        vm.deal(user, 200 ether);
        vm.prank(user);
        IWrappedETH(address(weth)).deposit{value: 100 ether}();
        return user;
    }
}

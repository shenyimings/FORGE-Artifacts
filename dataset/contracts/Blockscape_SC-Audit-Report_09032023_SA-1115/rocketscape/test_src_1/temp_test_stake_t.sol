// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {BlockscapeETHStakeNFT} from "src/BlockscapeETHStakeNFT.sol";

contract BlockscapeETHStakeNFTTest is Test {
    uint256 initWithdrawFee = 20 ether;
    BlockscapeETHStakeNFT blockscapeETHStakeNFT;

        address deployer;

        address poolStaker1;

        address poolStaker2;

    function setUp() public {
        deployer = vm.addr(0xDe0);
        vm.deal(deployer, 100 ether);
        vm.label(deployer, "deployer");

        poolStaker1 = vm.addr(0xDe1);
        vm.deal(poolStaker1, 100 ether);
        vm.label(poolStaker1, "poolStaker1");

        poolStaker2 = vm.addr(0xDe2);
        vm.deal(poolStaker2, 100 ether);
        vm.label(poolStaker2, "poolStaker2");
    }

    function testUnit() public {

        blockscapeETHStakeNFT = new BlockscapeETHStakeNFT();

        vm.prank(deployer);
        blockscapeETHStakeNFT.depositStakeNFT{value: 1 ether}();


        vm.prank(poolStaker1);
        blockscapeETHStakeNFT.depositStakeNFT{value: 5.214 ether}();

        vm.prank(deployer);
        assertEq(blockscapeETHStakeNFT.balanceOf(deployer, 1), 1);

        vm.prank(deployer);
        blockscapeETHStakeNFT.updateStake{value: 5 ether}(1);


        assertEq(blockscapeETHStakeNFT.getPoolSupply(), 11.214 ether);

        vm.prank(deployer);
        blockscapeETHStakeNFT.userRequestFullWithdraw(1);


        assertEq(blockscapeETHStakeNFT.getPoolSupply(), 5.214 ether);

    }
}

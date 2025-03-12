// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import { BaseTest } from "../base/BaseTest.sol";
import { Vester } from "../../vesting/Vester.sol";

import { MockErc20 } from "../mocks/MockERC20.sol";

import { Math } from "../../utils/Math.sol";

contract Vester_BaseTest is BaseTest {
  Vester internal vester;
  MockErc20 internal p88;
  MockErc20 internal esP88;

  address internal constant BURN_ADDRESS = address(1);
  address internal constant TREASURY_ADDRESS = address(2);

  function setUp() public virtual {
    esP88 = new MockErc20("Escrowed P88", "esP88", 18);
    p88 = new MockErc20("P88", "P88", 18);

    vester = deployVester(
      address(esP88),
      address(p88),
      BURN_ADDRESS,
      TREASURY_ADDRESS
    );

    esP88.mint(address(this), 100 ether);
    p88.mint(address(vester), 100 ether);

    assertEq(vester.esP88(), address(esP88));
    assertEq(vester.p88(), address(p88));
  }
}

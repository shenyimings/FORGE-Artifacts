// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import "./SolidityTemplate.sol";

contract SolidityTemplateTest is DSTestPlus {
	SolidityTemplate template;

	function setUp() public {
		template = new SolidityTemplate();
	}

	function testFail_basic_sanity() public {
		assertTrue(false);
	}

	function test_basic_sanity() public {
		assertTrue(true);
	}
}

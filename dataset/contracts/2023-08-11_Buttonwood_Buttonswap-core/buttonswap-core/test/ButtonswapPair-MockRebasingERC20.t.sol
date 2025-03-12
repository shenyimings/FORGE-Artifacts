// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.13;

import {ButtonswapPairTest} from "./ButtonswapPair-Template.sol";
import {MockRebasingERC20} from "buttonswap-core_mock-contracts/MockRebasingERC20.sol";
import {ICommonMockRebasingERC20} from
    "buttonswap-core_mock-contracts/interfaces/ICommonMockRebasingERC20/ICommonMockRebasingERC20.sol";

// MockRebasingERC20 is known to suffer inaccuracies that break Pair math.
// This is not considered blocking, so we disable the tests for now.
//contract ButtonswapPairMockRebasingERC20Test is ButtonswapPairTest {
//    function getRebasingTokenA() public override returns (ICommonMockRebasingERC20) {
//        return ICommonMockRebasingERC20(address(new MockRebasingERC20("TokenA", "TKNA", 18)));
//    }
//
//    function getRebasingTokenB() public override returns (ICommonMockRebasingERC20) {
//        return ICommonMockRebasingERC20(address(new MockRebasingERC20("TokenB", "TKNB", 18)));
//    }
//}

// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

import "./MockERC20.sol";

contract MockQuoteToken is MockERC20("Fake USD", "fUSD", 6) {}

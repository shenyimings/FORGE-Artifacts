// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;
/* solhint-disable no-global-import */
/* solhint-disable no-empty-blocks */
import "./AggregatorInterface.sol";
import "./AggregatorV3Interface.sol";

interface AggregatorV2V3Interface is AggregatorInterface, AggregatorV3Interface {}

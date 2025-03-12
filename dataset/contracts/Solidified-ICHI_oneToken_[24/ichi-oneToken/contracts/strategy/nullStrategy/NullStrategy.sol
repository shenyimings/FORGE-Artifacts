// SPDX-License-Identifier: MIT

import "../StrategyCommon.sol";

pragma solidity 0.7.6;

contract NullStrategy is StrategyCommon {

    /**
     * @notice Supports the minimum interface but does nothing with funds committed to the strategy
     */

    /**
     @notice a strategy is dedicated to exactly one oneToken instance
     @param oneTokenFactory_ bind this instance to oneTokenFactory instance
     @param oneToken_ bind this instance to one oneToken vault
     @param description_ metadata has no impact on logic
     */

    constructor(address oneTokenFactory_, address oneToken_, string memory description_) 
        StrategyCommon(oneTokenFactory_, oneToken_, description_)
    {}
}
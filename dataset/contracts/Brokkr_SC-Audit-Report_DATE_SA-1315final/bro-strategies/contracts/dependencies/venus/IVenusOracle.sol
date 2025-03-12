// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./IVToken.sol";

interface IVenusOracle {
    function getUnderlyingPrice(IVToken vToken) external view returns (uint256);
}

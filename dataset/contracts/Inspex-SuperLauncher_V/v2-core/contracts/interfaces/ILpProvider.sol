// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../lib/DataTypes.sol";


interface ILpProvider {
    function getLpProvider(DataTypes.LpProvider provider) external view returns (address, address);
    function checkLpProviders(DataTypes.LpProvider[] calldata providers) external view returns (bool);
    function getWBnb() external view returns (address);
}


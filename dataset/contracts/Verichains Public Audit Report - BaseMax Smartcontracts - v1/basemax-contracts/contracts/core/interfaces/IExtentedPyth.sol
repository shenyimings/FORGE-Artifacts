// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;


interface IExtentedPyth {
    function priceFeedExists(bytes32 id) external view returns (bool);
}

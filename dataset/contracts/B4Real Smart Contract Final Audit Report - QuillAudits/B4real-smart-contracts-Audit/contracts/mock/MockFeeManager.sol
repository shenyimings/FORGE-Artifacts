// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

contract MockFeeManager {
    function getFactoryFeeInfo(address) external pure returns (uint256, address) {
        return (1e18, address(0));
    }

    function fetchFees() external payable returns(uint256) {
        return uint256(1);
    }

    receive() external payable {
    }
}

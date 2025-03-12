// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract CallTester {
    uint256 public execResult;

    function testCall(uint256 pw)
        external
        returns (string memory greeting)
    {
        require(pw == 123, "Invalid pw");
        greeting = "Hello!";
        execResult = pw;
    }

    /// @dev For testing receiving ETH
    function testCallEther() external payable {
        require(msg.value > 0, "Payment not received");
    }

    function getBal() external view returns (uint256 bal) {
        return address(this).balance;
    }

    /// @dev For testing receiving ETH
    receive() external payable {}
}

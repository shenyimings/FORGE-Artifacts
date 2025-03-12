// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {console} from "forge-std/console.sol";
import "../../src/SmartVault.sol";
import "../libraries/Arrays.sol";

contract MockGuard {
    mapping(address => bool) whitelist;

    function test_mock() external pure {}

    function isWhitelisted(address address_) external view returns (bool) {
        return whitelist[address_];
    }

    function checkAddressesLength(uint256 expectedResult, address[] memory addresses) external pure returns (bool) {
        return expectedResult == addresses.length;
    }

    function setWhitelist(address address_, bool whitelisted_) external {
        whitelist[address_] = whitelisted_;
    }

    function checkArraySum(uint256[] memory numbers, uint256 expectedValue) external pure returns (bool) {
        uint256 result = 0;
        for (uint256 i = 0; i < numbers.length; i++) {
            result += numbers[i];
        }

        return result == expectedValue;
    }

    function checkTimelock(address smartVault, uint256[] calldata assets, uint256 timelock)
        external
        view
        returns (bool)
    {
        uint256 tokenID = assets[0];
        uint256 _maximalDepositId = 2 ** 255 - 1;

        // Withdrawal
        if (tokenID > _maximalDepositId) {
            revert("Not applicable");
        }

        DepositMetadata memory metadata =
            abi.decode(SmartVault(smartVault).getMetadata(Arrays.toArray(tokenID))[0], (DepositMetadata));
        return (block.timestamp - metadata.initiated) > timelock;
    }
}

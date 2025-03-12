// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "./OperatorAccess.sol";

/**
 * @dev Provides a function to batch together multiple calls in a single external call.
 *
 * _Available since v4.1._
 */
abstract contract MulticallExecutable is OperatorAccess {
    struct InputData {
        address dest;
        bytes data;
        uint256 value;
    }

    function execute(InputData[] calldata _data)
        external
        payable
        virtual
        returns (bytes[] memory results)
    {}

    function _execute(InputData[] calldata _data, uint256 _txValue)
        internal
        returns (bytes[] memory results)
    {
        uint256 dataLength = _data.length;
        uint256 amountPassed;
        for (uint256 i = 0; i < dataLength; i++) {
            if (_data[i].value != 0) {
                amountPassed += _data[i].value;
            }
        }
        require(_txValue == amountPassed, "Payment amount incorrect");
        results = new bytes[](dataLength);
        for (uint256 i = 0; i < dataLength; i++) {
            results[i] = Address.functionCallWithValue(
                _data[i].dest,
                _data[i].data,
                _data[i].value
            );
        }
        return results;
    }
}

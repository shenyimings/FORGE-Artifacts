// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "./OperatorAccess.sol";
import "./MulticallExecutable.sol";

/**
 * @dev Provides a function to batch together multiple calls in a single external call.
 *
 * _Available since v4.1._
 */
contract MulticallAMBExecutable is MulticallExecutable {
    function execute(InputData[] calldata _data)
        external
        payable
        override
        onlyOperator
        returns (bytes[] memory results)
    {
        results = _execute(_data, msg.value);
    }
}

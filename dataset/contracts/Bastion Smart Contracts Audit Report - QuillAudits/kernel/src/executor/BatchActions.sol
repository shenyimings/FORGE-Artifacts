// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../utils/Exec.sol";

contract BatchActions {
    function executeBatch(address[] memory to, uint256[] memory value, bytes[] memory data, Operation operation)
        external
    {
        for (uint256 i = 0; i < to.length; i++) {
            if (operation == Operation.Call) {
                (bool success, bytes memory ret) = Exec.call(to[i], value[i], data[i]);
                if (!success) {
                    assembly {
                        revert(add(ret, 32), mload(ret))
                    }
                }
            } else {
                (bool success, bytes memory ret) = Exec.delegateCall(to[i], data[i]);
                if (!success) {
                    assembly {
                        revert(add(ret, 32), mload(ret))
                    }
                }
            }
        }
    }

    function approveAndTransfer20Batch(address[] memory tokenAddress, uint256[] memory amount, address[] memory to)
        external
    {
        for (uint256 i = 0; i < tokenAddress.length; i++) {
            IERC20(tokenAddress[i]).approve(to[i], amount[i]);
            IERC20(tokenAddress[i]).transfer(to[i], amount[i]);
        }
    }
}

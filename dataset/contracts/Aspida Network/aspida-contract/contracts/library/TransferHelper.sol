//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev Library for safely executing transfers and approvals of ERC20 tokens and ETH.
 */
library TransferHelper {
    /**
     * @dev Safely approves `value` tokens for `to` by calling the `approve` function on `token`.
     * @param token The address of the ERC20 token.
     * @param to The address to approve tokens for.
     * @param value The number of tokens to approve.
     */
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TransferHelper: APPROVE_FAILED");
    }

    /**
     * @dev Safely transfers `value` tokens to `to` by calling the `transfer` function on `token`.
     * @param token The address of the ERC20 token.
     * @param to The address to transfer tokens to.
     * @param value The number of tokens to transfer.
     */
    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TransferHelper: TRANSFER_FAILED");
    }

    /**
     * @dev Safely transfers `value` tokens from `from` to `to` by calling the `transferFrom` function on `token`.
     * @param token The address of the ERC20 token.
     * @param from The address to transfer tokens from.
     * @param to The address to transfer tokens to.
     * @param value The number of tokens to transfer.
     */
    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TransferHelper: TRANSFER_FROM_FAILED");
    }

    /**
     * @dev Safely transfers `value` ETH to `to`.
     * @param to The address to transfer ETH to.
     * @param value The amount of ETH to transfer.
     */
    function safeTransferETH(address to, uint value) internal {
        (bool success, ) = to.call{ value: value }(new bytes(0));
        require(success, "TransferHelper: ETH_TRANSFER_FAILED");
    }
}

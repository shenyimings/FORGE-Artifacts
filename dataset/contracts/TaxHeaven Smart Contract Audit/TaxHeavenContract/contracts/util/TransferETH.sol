// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

contract TransferETH {
    receive() external payable {}

    /**
     * @notice transfer `amount` ETH to the `recipient` account with emitting log
     */
    function _transferETH(
        address payable recipient,
        uint256 amount,
        string memory errorMessage
    ) internal {
        (bool success, ) = recipient.call{value: amount}("");
        require(success, errorMessage);
    }

    function _transferETH(address payable recipient, uint256 amount) internal {
        _transferETH(recipient, amount, "Transfer amount exceeds balance");
    }
}

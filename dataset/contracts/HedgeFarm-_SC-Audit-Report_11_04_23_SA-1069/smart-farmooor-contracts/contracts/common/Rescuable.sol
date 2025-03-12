// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Rescuable {
    using SafeERC20 for IERC20;

    /**
     * @notice  Rescue any ERC20 token stuck on the contract
     * @param   token  Address of the ERC20 token
     */
    function _rescueToken(address token) internal {
        IERC20(token).safeTransfer(msg.sender, IERC20(token).balanceOf(address(this)));
    }

    /**
     * @notice  Rescue Native tokens stuck on the contract
     */
    function _rescueNative() internal {
        (bool sent, ) = msg.sender.call{value: address(this).balance}("");
        require(sent, "Failed to send Ether");
    }
}
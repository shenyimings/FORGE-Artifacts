// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract BasicBridge is Ownable {
    uint256 public swapFee;

    event SwapFilled(
        address indexed bep20Addr,
        bytes32 indexed mainTxHash,
        address indexed toAddress,
        uint256 amount
    );

    /**
     * @dev Returns set minimum swap fee from ERC20 to BEP20
     */
    function setSwapFee(uint256 fee) external onlyOwner {
        swapFee = fee;
    }
}

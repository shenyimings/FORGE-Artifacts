// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;


/**
 * @title IERC3156FlashBorrower
 * @author solace.fi
 * @notice An interface that borrows flash loans per the [`EIP-3156` standard](https://eips.ethereum.org/EIPS/eip-3156).
 */
interface IERC3156FlashBorrower {

    /**
     * @dev Receive a flash loan.
     * @param initiator The initiator of the loan.
     * @param token The loan currency.
     * @param amount The amount of tokens lent.
     * @param fee The additional amount of tokens to repay.
     * @param data Arbitrary data structure, intended to contain user-defined parameters.
     * @return The keccak256 hash of "ERC3156FlashBorrower.onFlashLoan"
     */
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32);
}

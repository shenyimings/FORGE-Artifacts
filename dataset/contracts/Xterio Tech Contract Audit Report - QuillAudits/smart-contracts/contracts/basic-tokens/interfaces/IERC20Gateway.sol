// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20Gateway {
    /********************************************************************
     *                         ERC20 interfaces                         *
     ********************************************************************/

    /**
     * @dev Mint some ERC20 tokens to the recipient address.
     * @notice Only gateway contract is authorized to mint.
     * @param recipient The recipient of the minted ERC20 tokens.
     * @param amount The amount to be minted.
     */
    function ERC20_mint(
        address erc20Contract,
        address recipient,
        uint256 amount
    ) external;
}

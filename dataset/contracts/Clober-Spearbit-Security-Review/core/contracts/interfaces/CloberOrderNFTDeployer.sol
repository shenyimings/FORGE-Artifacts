// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

interface CloberOrderNFTDeployer {
    /**
     * @notice Deploys the OrderNFT contract.
     * @param salt The salt to compute the OrderNFT contract address via CREATE2.
     */
    function deploy(bytes32 salt) external returns (address);

    /**
     * @notice Computes the OrderNFT contract address.
     * @param salt The salt to compute the OrderNFT contract address via CREATE2.
     */
    function computeTokenAddress(bytes32 salt) external view returns (address);
}

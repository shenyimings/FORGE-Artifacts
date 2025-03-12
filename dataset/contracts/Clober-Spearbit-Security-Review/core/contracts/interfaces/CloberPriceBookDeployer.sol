// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

interface CloberPriceBookDeployer {
    /**
     * @notice Deploys an arithmetic price book.
     * @param a The starting price point.
     * @param d The common difference between price points.
     * @return The address of the deployed arithmetic price book.
     */
    function deployArithmeticPriceBook(uint128 a, uint128 d) external returns (address);

    /**
     * @notice Deploys a geometric price book.
     * @param a The scale factor of the price points.
     * @param r The common ratio between price points.
     * @return The address of the deployed geometric price book.
     */
    function deployGeometricPriceBook(uint128 a, uint128 r) external returns (address);

    /**
     * @notice Computes the address of an arithmetic price book.
     * @param a The starting price point.
     * @param d The common difference between price points.
     * @return The address of where the arithmetic price book is or would be deployed.
     */
    function computeArithmeticPriceBookAddress(uint128 a, uint128 d) external view returns (address);

    /**
     * @notice Computes the address of a geometric price book.
     * @param a The scale factor of the price points.
     * @param r The common ratio between price points.
     * @return The address of where the geometric price book is or would be deployed.
     */
    function computeGeometricPriceBookAddress(uint128 a, uint128 r) external view returns (address);
}

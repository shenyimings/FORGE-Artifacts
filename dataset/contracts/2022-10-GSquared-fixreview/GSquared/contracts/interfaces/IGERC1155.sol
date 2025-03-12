// SPDX-License-Identifier: AGPLv3
pragma solidity 0.8.10;

interface IGERC1155 {
    function getPricePerShare(uint256 id) external view returns (uint256);

    function totalSupplyBase(uint256 id) external view returns (uint256);

    function totalSupply(uint256 id) external view returns (uint256);

    function balanceOfWithFactor(address account, uint256 id)
        external
        view
        returns (uint256);

    function balanceOfBase(address account, uint256 id)
        external
        view
        returns (uint256);

    function factor(uint256 id) external view returns (uint256);

    function factorWithAssets(uint256 id, uint256 assets)
        external
        view
        returns (uint256);
}

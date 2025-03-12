// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface IComptroller {
    function _setCreditLimit(
        address protocol,
        address market,
        uint256 creditLimit
    ) external;

    function _supportMarket(address bToken, uint8 version) external;

    function enterMarkets(
        address[] memory bTokens
    ) external returns (uint256[] memory);
}

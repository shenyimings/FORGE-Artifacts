// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

contract VenusComptroller {
    function enterMarkets(address[] calldata xTokens)
        external
        pure
        returns (uint256[] memory)
    {
        uint256[] memory results = new uint256[](1);
        results[0] = 1;

        return results;
    }

    function markets(address cTokenAddress)
        external
        pure
        returns (
            bool,
            uint256,
            bool
        )
    {
        return (true, 100, true);
    }
}

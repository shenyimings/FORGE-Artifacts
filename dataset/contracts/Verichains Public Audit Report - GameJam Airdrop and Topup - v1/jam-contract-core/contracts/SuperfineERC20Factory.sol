// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./tokens/ERC20/SimpleERC20.sol";

contract SuperfineERC20Factory {
    SimpleERC20[] private fungibleTokens;

    event CreateERC20(
        address indexed _owner,
        string template_type,
        address contract_address,
        string name,
        string symbol
    );

    function createERC20(
        uint256 capacity,
        uint256 initialSupply,
        uint8 d,
        string memory _name,
        string memory _symbol
    ) public {
        SimpleERC20 token = new SimpleERC20(
            msg.sender,
            capacity,
            initialSupply,
            d,
            _name,
            _symbol
        );
        fungibleTokens.push(token);
        emit CreateERC20(
            msg.sender,
            "SimpleERC20-V1",
            token.coinTokenAddress(),
            _name,
            _symbol
        );
    }

    function getERC20(
        uint256 _index
    )
        public
        view
        returns (
            address coinTokenAddress,
            address owner,
            string memory name,
            string memory symbol,
            uint8 decimals,
            uint256 capacity
        )
    {
        SimpleERC20 token = fungibleTokens[_index];

        return (
            token.coinTokenAddress(),
            token.owner(),
            token.name(),
            token.symbol(),
            token.decimals(),
            token.totalSupply()
        );
    }
}

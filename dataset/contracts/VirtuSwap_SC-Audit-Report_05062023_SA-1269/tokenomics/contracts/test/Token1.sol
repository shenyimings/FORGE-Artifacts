// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token1 is ERC20 {
    constructor(
        address _founder,
        uint256 _initialSupply
    ) ERC20("Token1", "T1") {
        _mint(_founder, _initialSupply);
    }

    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }

    function getTokens() external returns (address token0, address token1) {
        return (address(this), address(this));
    }
}

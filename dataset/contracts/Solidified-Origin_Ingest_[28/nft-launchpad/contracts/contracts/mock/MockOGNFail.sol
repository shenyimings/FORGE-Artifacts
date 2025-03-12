// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract MockOGNFail is ERC20 {
    uint256 private tick;

    constructor() ERC20('MockOGN', 'OGN') {}

    function mint(address to, uint256 _tokens) public virtual {
        _mint(to, _tokens);
    }

    function burn(address account) public virtual {
        _burn(account, balanceOf(account));
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public override returns (bool) {
        require(_from != address(0));
        require(_to != address(0));
        require(_value > 0);
        // Need to mutate state
        tick += 1;
        return false;
    }

    function transfer(address _to, uint256 _value)
        public
        override
        returns (bool)
    {
        require(_to != address(0));
        require(_value > 0);
        // Need to mutate state
        tick += 1;
        return false;
    }
}

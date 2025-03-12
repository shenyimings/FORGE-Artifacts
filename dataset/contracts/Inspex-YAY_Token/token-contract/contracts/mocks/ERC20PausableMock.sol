// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../BEP20YAY.sol";

// mock class using ERC20Pausable
contract ERC20PausableMock is BEP20YAY {
    constructor () public BEP20YAY() {
    }

    function pauseMock() external {
        _pause();
    }

    function unpauseMock() external {
        _unpause();
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public {
        _burn(from, amount);
    }
}

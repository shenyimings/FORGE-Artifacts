// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * A mock contract for ERC20 tokens.
 * Methods can be added as needed for testing.
 */
contract MockErc20 is ERC20 {
    uint8 internal _decimals;

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    constructor(uint8 decimals_) ERC20("mock", "MOK") {
        _decimals = decimals_;
    }

    function mint(uint256 _amount) external {
        _mint(msg.sender, _amount);
    }

    // dev: non-standard ERC20 method used for testing
    function mintFor(address _account, uint256 _amount) external returns (bool) {
        _mint(_account, _amount);
        return true;
    }
}

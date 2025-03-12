// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./MockToken.sol";
import "../interfaces/compound/ICToken.sol";

/**
 * @notice Mock cToken.
 */
contract MockCToken is ICToken, MockToken {
    MockToken public token;

    constructor(string memory _name, string memory _symbol) MockToken(_name, _symbol, 18) {
        token = new MockToken("Mock Token", "Mock Token", 18);
    }

    function mint(uint _amount) external override returns (uint256) {
        _mint(msg.sender, _amount);
        return 0;
    }

    function redeem(uint _amount) external override returns (uint256) {
        _burn(msg.sender, _amount);
        return 0;
    }

    function underlying() external view override returns (address) {
        return address(token);
    }

    function exchangeRateCurrent() external pure override returns (uint256) {
        return 11 * 10**17;
    }

    function exchangeRateStored() external pure override returns (uint256) {
        return 11 * 10**17;
    }

}
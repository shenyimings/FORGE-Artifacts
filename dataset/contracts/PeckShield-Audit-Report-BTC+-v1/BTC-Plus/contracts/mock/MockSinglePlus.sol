// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "../SinglePlus.sol";
import "./MockReward.sol";
import "./MockToken.sol";

/**
 * @dev Mock single plus contract.
 */
contract MockSinglePlus is SinglePlus {

    MockReward public reward;

    constructor(address _token) {
        SinglePlus.initialize(_token, '', '');
        reward = new MockReward(_token, new address[](0));
    }

    /**
     * @dev Returns the total value of the underlying token in terms of the peg value, scaled to 18 decimals.
     */
    function _totalUnderlyingInWad() internal view virtual override returns (uint256) {
        uint256 _balance = MockToken(token).balanceOf(address(this));
        uint256 _reward = MockToken(token).balanceOf(address(reward));
        uint256 _ratio = uint256(10) ** (18 - MockToken(token).decimals());

        return (_balance + _reward) * _ratio * WAD;
    }

    function invest() public override {
        uint256 _balance = MockToken(token).balanceOf(address(this));
        MockToken(token).transfer(address(reward), _balance);
    }

    function divest() public override {
        uint256 _balance = MockToken(token).balanceOf(address(reward));
        reward.withdraw(_balance);
    }

    function harvest() public override {
        // Simulates a 20% yield
        uint256 _balance = MockToken(token).balanceOf(address(reward));
        MockToken(token).mint(address(reward), _balance * 20 / 100);
        rebase();
    }

    /**
     * @dev Withdraws underlying tokens.
     * @param _receiver Address to receive the token withdraw.
     * @param _amount Amount of underlying token withdraw.
     */
    function _withdraw(address _receiver, uint256  _amount) internal virtual override {
        uint256 _balance = MockToken(token).balanceOf(address(this));
        if (_balance < _amount) {
            reward.withdraw(_amount - _balance);
        }
        IERC20Upgradeable(token).transfer(_receiver, _amount);
    }
}
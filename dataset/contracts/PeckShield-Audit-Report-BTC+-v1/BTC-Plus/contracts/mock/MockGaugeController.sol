// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "../interfaces/IGaugeController.sol";
import "./MockToken.sol";

/**
 * Mock Gauge Controller contract.
 */
contract MockGaugeController is IGaugeController {

    address public override reward;
    address public override governance;
    address public override treasury;
    address public claimer;
    uint256 public rate;
    mapping(address => mapping(address => uint256)) public override claimed;
    mapping(address => uint256) public override lastClaim;

    constructor(address _reward, address _governance, address _claimer) {
        reward = _reward;
        governance = _governance;
        claimer = _claimer;
    }

    function setRate(uint256 _rate) public {
        rate = _rate;
    }

    /**
     * @dev Returns the current AC emission rate for the gauge.
     * @param _gauge The liquidity gauge to check AC emission rate.
     */
    function gaugeRates(address _gauge) external view override returns (uint256) {
        _gauge;
        return rate;
    }

    /**
     * @dev Returns whether the account is a claimer which can claim rewards on behalf
     * of the user. Since user's liquidity limit is updated each time a user claims, we
     * don't want to allow anyone to claim for others.
     */
    function claimers(address _account) external view override returns (bool) {
        return _account == claimer;
    }

    /**
     * @dev Claims rewards for a user. Only the supported gauge can call this function.
     * @param _account Address of the user to claim reward.
     * @param _receiver Address that receives the claimed reward
     * @param _amount Amount of AC to claim
     */
    function claim(address _account, address _receiver, uint256 _amount) external override {
        MockToken(reward).mint(_receiver, _amount);

        claimed[msg.sender][_account] = claimed[msg.sender][_account] + _amount;
        lastClaim[msg.sender] = block.timestamp;
    }

    /**
     * @dev Donate the gauge fee. Only liqudity gauge can call this function.
     * @param _token Address of the donated token.
     */
    function donate(address _token) external override {
        if (false) {
            claimer = msg.sender;
        }
        _token;
    }
}
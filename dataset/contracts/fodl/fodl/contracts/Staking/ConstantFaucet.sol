// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/**
 * @notice A decentralised smart-contract that transfers fodl from the treasury to the single sided
 * staking contract at a constant rate, i.e. emissionRate = 50M / 3 years = 0.52849653306 FODL / second
 */
contract ConstantFaucet {
    using SafeMath for uint256;

    ///@dev State variables
    uint256 public amountDistributed;
    uint256 public lastUpdateTime;

    ///@dev Immutables
    IERC20 public immutable fodl;
    address public immutable treasury;
    address public immutable target;
    uint256 public immutable finishTime;

    ///@dev Constants
    uint256 public constant TOTAL_FODL = 50e24; // 50M Fodl
    uint256 public constant DURATION = 94608000; // 3 years in seconds

    constructor(
        IERC20 _fodl,
        address _treasury,
        address _target,
        uint256 _startTime
    ) public {
        fodl = _fodl;
        treasury = _treasury;
        target = _target;
        lastUpdateTime = _startTime;
        finishTime = _startTime.add(DURATION);
    }

    function distributeFodl() external returns (uint256 amount) {
        require(now < finishTime, 'Faucet expired!');
        uint256 elapsed = now.sub(lastUpdateTime);
        amount = elapsed.mul(TOTAL_FODL).div(DURATION);
        fodl.transferFrom(treasury, target, amount);
        lastUpdateTime = now;
    }
}

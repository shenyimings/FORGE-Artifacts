// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/**
 * @notice A decentralised smart-contract that transfers fodl from the treasury to the single sided
 * staking contract at a constant rate, i.e. emissionRate = 50M / 3 years = 0.52849653306 FODL / second
 */
contract ConstantFaucetResume {
    using SafeMath for uint256;

    ///@dev State variables
    uint256 public lastUpdateTime;
    address public treasury;

    ///@dev Immutables
    IERC20 public immutable fodl;
    address public immutable target;
    uint256 public immutable finishTime;

    ///@dev Constants
    uint256 public constant TOTAL_FODL = 50e24; // 50M Fodl
    uint256 public constant DURATION = 94608000; // 3 years in seconds

    /**
     * @notice This contract continues the constant emmission started by `previousInstance`
     * but is allowed to change the source of rewards (`newTreasury`).
     */
    constructor(ConstantFaucetResume previousInstance) public {
        fodl = previousInstance.fodl();
        treasury = previousInstance.treasury();
        target = previousInstance.target();
        lastUpdateTime = previousInstance.lastUpdateTime();
        finishTime = previousInstance.finishTime();
    }

    function distributeFodl() external returns (uint256 amount) {
        require(now < finishTime, 'Faucet expired!');
        uint256 elapsed = now.sub(lastUpdateTime);
        amount = elapsed.mul(TOTAL_FODL).div(DURATION);
        fodl.transferFrom(treasury, target, amount);
        lastUpdateTime = now;
    }

    function changeTreasury(address newTreasury) external {
        require(msg.sender == treasury, 'Only treasury allowed to call!');
        treasury = newTreasury;
    }
}

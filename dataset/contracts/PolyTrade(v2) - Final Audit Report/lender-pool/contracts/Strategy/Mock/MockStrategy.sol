//SPDX-License-Identifier: MIT
pragma solidity =0.8.15;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interface/IAaveLendingPool.sol";
import "../../Token/interface/IToken.sol";
import "../interface/IStrategy.sol";
import "./MockProtocol.sol";

/**
 * @author Polytrade
 * @title MockStrategy // Not For PROD
 */
contract MockStrategy is IStrategy, AccessControl {
    using SafeERC20 for IToken;

    IToken public stable;
    IToken public aStable;

    MockProtocol public protocol;

    bytes32 public constant LENDER_POOL = keccak256("LENDER_POOL");

    constructor(address _stable, address _protocol) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        stable = IToken(_stable);
        protocol = MockProtocol(_protocol);
    }

    function deposit(uint amount) external {
        require(
            stable.transferFrom(msg.sender, address(this), amount),
            "Stable Transfer failed"
        );
        stable.approve(address(protocol), amount);
        protocol.deposit(amount);
        emit Deposit(amount);
    }

    /**
     * @notice withdraw funds from protocol and send to lending pool
     * @dev can be called by only lender pool
     * @param amount, total amount accepted from user and transferred to protocol
     */
    function withdraw(uint amount) external onlyRole(LENDER_POOL) {
        protocol.withdrawAmount(amount);
        emit Withdraw(amount);
    }

    /**
     * @notice get aStable balance of staking strategy smart contract
     * @return total amount of aStable token in this contract
     */
    function getBalance() external view returns (uint) {
        uint depositAmount = protocol.getDeposits(address(this));
        uint rewardAmount = protocol.rewardOf(address(this));
        return depositAmount + rewardAmount;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title LiquidityPool
 * @dev A contract for managing a liquidity pool.
 */
contract LiquidityPool is Initializable, Ownable {
    event Withdrew(uint256 amount); // Event emitted when tokens are withdrawn from the pool
    event Deposit(address indexed sender, uint amount, uint balance); // Event emitted when pool received mtc

    /**
     * @dev The receive function is a special function that allows the contract to accept MTC transactions.
     * It emits a Deposit event to record the deposit details.
     */
    receive() external payable {
        emit Deposit(_msgSender(), msg.value, address(this).balance);
    }

    /**
     * @dev Initializes the contract.
     */
    function initialize() external initializer {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Transfers funds from the liquidity pool to the specified address.
     * @param withdrawalAmount The amount of tokens to withdraw from the pool
     */
    function transferFunds(uint256 withdrawalAmount) external onlyOwner {
        _withdraw(owner(), withdrawalAmount);

        emit Withdrew(withdrawalAmount);
    }

    /**
     * @dev Internal function to withdraw tokens from the pool.
     * @param _to The address to which the tokens will be transferred
     * @param _withdrawalAmount The amount of tokens to withdraw
     * @return A boolean indicating whether the withdrawal was successful
     */
    function _withdraw(
        address _to,
        uint256 _withdrawalAmount
    ) internal returns (bool) {
        uint256 poolBalance = address(this).balance;
        require(
            poolBalance > 0 && _withdrawalAmount <= poolBalance,
            "LiquidityPool: no mtc to withdraw"
        );

        (bool sent, ) = _to.call{value: _withdrawalAmount}("");
        require(sent, "LiquidityPool: unable to withdraw");

        return sent;
    }
}

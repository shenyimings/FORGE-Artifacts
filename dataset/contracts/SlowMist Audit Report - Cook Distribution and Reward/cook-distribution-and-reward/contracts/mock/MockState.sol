pragma solidity ^0.6.2;

import "../core/PoolSetters.sol";

contract MockState is PoolSetters {
    /**
     * Global
     */
    function incrementTotalRewardedE(uint256 amount) external {
        super.incrementTotalRewarded(amount);
    }

    function decrementTotalRewardedE(uint256 amount, string calldata reason)
        external
    {
        super.decrementTotalRewarded(amount, reason);
    }

    /**
     * Account
     */
    function incrementBalanceOfStakedE(address account, uint256 amount)
        external
    {
        super.incrementBalanceOfStaked(account, amount);
    }

    function decrementBalanceOfStakedE(
        address account,
        uint256 amount,
        string calldata reason
    ) external {
        super.decrementBalanceOfStaked(account, amount, reason);
    }

    function incrementBalanceOfPhantomE(address account, uint256 amount)
        external
    {
        super.incrementBalanceOfPhantom(account, amount);
    }

    function decrementBalanceOfPhantomE(
        address account,
        uint256 amount,
        string calldata reason
    ) external {
        super.decrementBalanceOfPhantom(account, amount, reason);
    }
}

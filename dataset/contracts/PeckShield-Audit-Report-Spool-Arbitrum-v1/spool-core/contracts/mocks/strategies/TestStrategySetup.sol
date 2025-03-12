// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "../../external/@openzeppelin/proxy/Proxy.sol";
import "../../shared/BaseStorage.sol";
import "../../libraries/Max/128Bit.sol";

struct StrategySetup {
    uint128 totalShares;
    uint24 index;
    Pending pendingUser;
    Pending pendingUserNext;
    uint128 pendingDepositReward;
    // ----- REALLOCATION VARIABLES
    uint128 optimizedSharesWithdrawn;
    uint128 pendingReallocateDeposit;
    uint128 pendingReallocateOptimizedDeposit;
}

contract TestStrategySetup is BaseStorage, Proxy {
    using Max128Bit for uint128;

    address private strat;

    constructor(address _strat) {
        strat = _strat;
    }

    function setStrategyState(StrategySetup memory strategySetup) external {
        Strategy storage strategy = strategies[strat];

        strategy.totalShares = strategySetup.totalShares;
        strategy.index = strategySetup.index;
        strategySetup.pendingUser.deposit = strategySetup.pendingUser.deposit.set();
        strategySetup.pendingUser.sharesToWithdraw = strategySetup.pendingUser.sharesToWithdraw.set();
        strategy.pendingUser = strategySetup.pendingUser;
        strategy.pendingUserNext = strategySetup.pendingUserNext;
        strategy.pendingDepositReward = strategySetup.pendingDepositReward;
        strategy.optimizedSharesWithdrawn = strategySetup.optimizedSharesWithdrawn;
        strategy.pendingReallocateDeposit = strategySetup.pendingReallocateDeposit;
        strategy.pendingReallocateOptimizedDeposit = strategySetup.pendingReallocateOptimizedDeposit;
    }

    function getStrategy() external view returns(StrategySetup memory) {
        Strategy storage strategy = strategies[strat];

        StrategySetup memory strategySetup;
        Pending memory pendingUser;
        Pending memory pendingUserNext;

        strategySetup.totalShares = strategy.totalShares;
        strategySetup.index = strategy.index;

        pendingUser = strategy.pendingUser;
        pendingUser.deposit = pendingUser.deposit.get();
        pendingUser.sharesToWithdraw = pendingUser.sharesToWithdraw.get();
        strategySetup.pendingUser = pendingUser;

        pendingUserNext = strategy.pendingUserNext;
        pendingUserNext.deposit = pendingUserNext.deposit.get();
        pendingUserNext.sharesToWithdraw = pendingUserNext.sharesToWithdraw.get();
        strategySetup.pendingUserNext = pendingUserNext;

        strategySetup.pendingDepositReward = strategy.pendingDepositReward;
        strategySetup.optimizedSharesWithdrawn = strategy.optimizedSharesWithdrawn;
        strategySetup.pendingReallocateDeposit = strategy.pendingReallocateDeposit;
        strategySetup.pendingReallocateOptimizedDeposit = strategy.pendingReallocateOptimizedDeposit;

        return strategySetup;
    }

    function _implementation() internal view override returns (address) {
        return strat;
    }

    function setImplementation(address impl) external {
        strat = impl;
    }
}

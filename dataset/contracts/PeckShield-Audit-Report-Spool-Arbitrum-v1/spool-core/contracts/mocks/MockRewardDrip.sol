// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "../interfaces/vault/IVaultImmutable.sol";
import "../vault/RewardDrip.sol";

contract MockRewardDrip is RewardDrip, IVaultImmutable {
    address public constant override riskProvider = address(0);
    int8 public constant override riskTolerance = 0;
    
    IERC20 public immutable override underlying;

    constructor(
        ISpool _spool,
        IController _controller,
        IFastWithdraw _fastWithdraw,
        IFeeHandler _feeHandler,
        ISpoolOwner _spoolOwner,
        address _vaultOwner,
        IERC20 _underlying
    )
        VaultBase(
            _spool,
            _controller,
            _fastWithdraw,
            _feeHandler
        )
        SpoolOwnable(_spoolOwner)
    {
        underlying = _underlying;
        vaultOwner = _vaultOwner;
    }
    
    function deposit(uint128 amount) external updateRewards {
        _addInstantDeposit(amount);
        // consider deposit is 1:1 with shares for simpler testing
        users[msg.sender].shares += amount;
    }

    function withdraw(uint128 amount, bool withdrawAll) external updateRewards {
        _withdrawShares(amount, withdrawAll);
    }
    
    // do same actions as vault implementation
    function _withdrawShares(uint128 sharesToWithdraw, bool withdrawAll) private returns(uint128) {
        User storage user = users[msg.sender];
        uint128 userShares = user.shares;

        uint128 userActiveInstantDeposit = user.instantDeposit;
        
        if (withdrawAll || userShares == sharesToWithdraw) {
            sharesToWithdraw = userShares;
            user.shares = 0;
            totalInstantDeposit -= userActiveInstantDeposit;
            user.instantDeposit -= userActiveInstantDeposit;
        } else {
            require(
                userShares >= sharesToWithdraw &&
                sharesToWithdraw > 0, 
                "WSH"
            );

            uint128 instantDepositWithdrawn = _getProportion128(userActiveInstantDeposit, sharesToWithdraw, userShares);

            totalInstantDeposit -= instantDepositWithdrawn;
            user.instantDeposit -= instantDepositWithdrawn;

            user.shares = userShares - sharesToWithdraw;
        }
        
        return sharesToWithdraw;
    }
}

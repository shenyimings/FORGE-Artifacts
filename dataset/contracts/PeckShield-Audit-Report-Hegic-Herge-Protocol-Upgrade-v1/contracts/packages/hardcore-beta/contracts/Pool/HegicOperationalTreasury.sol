pragma solidity ^0.8.3;

/**
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Hegic
 * Copyright (C) 2022 Hegic Protocol
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 **/

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@hegic/v8888/contracts/OptionsManager/IOptionsManager.sol";
import "../Interfaces/IHegicOperationalTreasury.sol";
import "../Interfaces/IHegicStakeAndCover.sol";

contract HegicOperationalTreasury is
    IHegicOperationalTreasury,
    AccessControl,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    IERC20 public immutable override token;
    IOptionsManager public immutable override manager;
    IHegicStakeAndCover public stakeandcoverPool;
    bytes32 public constant STRATEGY_ROLE = keccak256("STRATEGY_ROLE");
    mapping(uint256 => LockedLiquidity) public override lockedLiquidity;
    mapping(address => uint256) public override lockedByStrategy;
    uint256 public override benchmark;

    uint256 public override lockedPremium;
    uint256 public override totalLocked;
    uint256 public override totalBalance;
    uint256 public maxLockupPeriod;

    constructor(
        IERC20 _token,
        IOptionsManager _manager,
        uint256 _maxLockupPeriod,
        IHegicStakeAndCover _stakeandcoverPool,
        uint256 _benchmark
    ) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        token = _token;
        manager = _manager;
        maxLockupPeriod = _maxLockupPeriod;
        stakeandcoverPool = _stakeandcoverPool;
        benchmark = _benchmark;
    }

    /**
     * @notice Used for locking liquidity in an active options strategy
     * @param holder The option strategy holder address
     * @param negativepnl The amount of options strategy contract
     * @param expiration The options strategy expiration time
     **/
    function lockLiquidityFor(
        address holder,
        uint128 negativepnl,
        uint32 expiration
    ) external override onlyRole(STRATEGY_ROLE) returns (uint256 optionID) {
        uint128 positivepnl = uint128(_addTokens());
        totalLocked += negativepnl;
        lockedPremium += positivepnl;

        require(
            totalLocked + lockedPremium <=
                totalBalance + stakeandcoverPool.availableBalance(),
            "The negative pnl amount is too large"
        );
        require(
            block.timestamp + maxLockupPeriod >= expiration,
            "The period is too long"
        );
        lockedByStrategy[msg.sender] += negativepnl;
        optionID = manager.createOptionFor(holder);
        lockedLiquidity[optionID] = LockedLiquidity(
            LockedLiquidityState.Locked,
            msg.sender,
            negativepnl,
            positivepnl,
            expiration
        );
    }

    /**
     * @notice  Used for unlocking
     * liquidity after an expiration
     * @param lockedLiquidityID The option contract ID
     **/
    function unlock(uint256 lockedLiquidityID) public virtual override {
        LockedLiquidity storage ll = lockedLiquidity[lockedLiquidityID];
        require(
            block.timestamp > ll.expiration,
            "The expiration time has not yet come"
        );
        _unlock(ll);
        emit Expired(lockedLiquidityID);
    }

    /**
     * @notice Used for paying off the profits
     * if an option is exercised in-the-money
     * @param lockedLiquidityID The option contract ID
     * @param amount The amount to pay off
     * @param account The holder address
     **/
    function payOff(
        uint256 lockedLiquidityID,
        uint256 amount,
        address account
    ) external override nonReentrant {
        LockedLiquidity storage ll = lockedLiquidity[lockedLiquidityID];

        require(
            ll.expiration > block.timestamp,
            "The option has already expired"
        );
        require(ll.strategy == msg.sender, "a");
        require(account != address(0), "b");
        require(
            _checkPayOffAmount(amount, ll),
            "The amount to PayOff is too large."
        );

        _unlock(ll);
        if (totalBalance < amount) {
            _replenish(amount);
        }
        _withdraw(account, amount);
        emit Paid(lockedLiquidityID, account, amount);
    }

    function getStakeAndCoverBalance()
        external
        view
        override
        returns (uint256 balance)
    {
        return stakeandcoverPool.availableBalance();
    }

    /**
     * @notice Used for adding deposited tokens
     * (e.g. premiums) to the contract's totalBalance
     * @param amount The amount of tokens to add
     **/
    function addTokens()
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (uint256 amount)
    {
        return _addTokens();
    }

    /**
     * @notice Used for setting the initial
     * contract benchmark for calculating
     * future profits or losses
     * @param value The benchmark value
     **/
    function setBenchmark(uint256 value) external onlyRole(DEFAULT_ADMIN_ROLE) {
        benchmark = value;
    }

    /**
     * @notice Used for withdrawing deposited
     * tokens from the contract
     * @param to The recipient address
     * @param amount The amount to withdraw
     **/
    function withdraw(address to, uint256 amount)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _withdraw(to, amount);
    }

    /**replenish
     * @notice Used for replenishing of
     * the Hegic Operational Treasury contract
     **/
    function replenish() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _replenish(0);
    }

    function _unlock(LockedLiquidity storage ll) internal {
        require(
            ll.state == LockedLiquidityState.Locked,
            "The liquidity has already been unlocked"
        );
        ll.state = LockedLiquidityState.Unlocked;
        totalLocked -= ll.negativepnl;
        lockedPremium -= ll.positivepnl;
        lockedByStrategy[ll.strategy] -= ll.negativepnl;
    }

    function _replenish(uint256 additionalAmount) internal {
        uint256 transferAmount = benchmark +
            additionalAmount +
            lockedPremium -
            totalBalance;
        stakeandcoverPool.payOut(transferAmount);
        totalBalance += transferAmount;
        emit Replenished(transferAmount);
    }

    function _addTokens() private returns (uint256 amount) {
        amount = token.balanceOf(address(this)) - totalBalance;
        totalBalance += amount;
    }

    function _withdraw(address to, uint256 amount) internal {
        require(
            amount + totalLocked + lockedPremium <=
                totalBalance + stakeandcoverPool.availableBalance(),
            "The amount to withdraw is too large"
        );
        totalBalance -= amount;
        if (amount > 0) token.safeTransfer(to, amount);
    }

    function _checkPayOffAmount(
        uint256 amount,
        LockedLiquidity memory /*ll*/
    ) internal pure virtual returns (bool) {
        return amount > 0;
    }
}

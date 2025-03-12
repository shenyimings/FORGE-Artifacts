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
import "./PositionsManager/IPositionsManager.sol";
import "./IOperationalTreasury.sol";
import "./ICoverPool.sol";

contract OperationalTreasury is
    IOperationalTreasury,
    AccessControl,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    IERC20 public immutable override token;
    IPositionsManager public immutable override manager;
    ICoverPool public immutable override coverPool;
    mapping(uint256 => LockedLiquidity) public override lockedLiquidity;
    mapping(IHegicStrategy => uint256) public override lockedByStrategy;
    mapping(IHegicStrategy => bool) public acceptedStrategy;
    mapping(IHegicStrategy => uint256) public mayBeAcceptedAtEpoch;

    uint256 public override benchmark;

    uint256 public override lockedPremium;
    uint256 public override totalLocked;
    uint256 public immutable maxLockupPeriod;

    constructor(
        IERC20 _token,
        IPositionsManager _manager,
        uint256 _maxLockupPeriod,
        ICoverPool _coverPool,
        uint256 _benchmark,
        IHegicStrategy[] memory initialStrategies
    ) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        token = _token;
        manager = _manager;
        maxLockupPeriod = _maxLockupPeriod;
        coverPool = _coverPool;
        benchmark = _benchmark;
        for (uint256 i = 0; i < initialStrategies.length; i++)
            _connect(initialStrategies[i]);
    }

    /**
     * @notice Used for buying options/strategies
     * @param holder The holder address
     * @param period The option/strategy period
     * @param amount The option/strategy amount
     * @param additional TODO
     **/
    function buy(
        IHegicStrategy strategy,
        address holder,
        uint256 amount,
        uint256 period,
        bytes[] calldata additional
    ) external override nonReentrant {
        uint256 optionID = manager.createOptionFor(holder);
        (uint32 expiration, uint256 negativePNL, uint256 positivePNL) = strategy
            .create(optionID, holder, amount, period, additional);
        _lockLiquidity(
            strategy,
            optionID,
            uint128(negativePNL),
            uint128(positivePNL),
            expiration
        );
    }

    /**
     * @notice Used for locking liquidity in an active options strategy
     * @param optionID TODO
     * @param negativepnl The amount of options strategy contract
     * @param expiration The options strategy expiration time
     **/
    function _lockLiquidity(
        IHegicStrategy strategy,
        uint256 optionID,
        uint128 negativepnl,
        uint128 positivepnl,
        uint32 expiration
    ) internal {
        require(acceptedStrategy[strategy], "Wrong strategy");

        totalLocked += negativepnl;
        lockedPremium += positivepnl;

        require(
            totalLocked + lockedPremium <=
                totalBalance() + coverPool.availableForPayment(),
            "The negative pnl amount is too large"
        );
        require(
            block.timestamp + maxLockupPeriod >= expiration,
            "The period is too long"
        );

        lockedByStrategy[strategy] += negativepnl;
        lockedLiquidity[optionID] = LockedLiquidity(
            LockedLiquidityState.Locked,
            strategy,
            negativepnl,
            positivepnl,
            expiration
        );

        token.safeTransferFrom(msg.sender, address(this), positivepnl);
    }

    /**
     * @notice Used for unlocking liquidity after an expiration
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
     * @param positionID The option contract ID
     **/
    function payOff(uint256 positionID, address account)
        external
        override
        nonReentrant
    {
        LockedLiquidity storage ll = lockedLiquidity[positionID];
        uint256 amount = ll.strategy.payOffAmount(positionID);
        require(
            ll.expiration > block.timestamp,
            "The option has already expired"
        );
        require(
            ll.strategy.isPayoffAvailable(positionID, msg.sender, account),
            "You can not execute this option strat"
        );

        _unlock(ll);
        if (totalBalance() < amount) {
            _replenish(amount);
        }
        _withdraw(account, amount);
        emit Paid(positionID, account, amount);
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

    function addStrategy(IHegicStrategy s)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            mayBeAcceptedAtEpoch[s] == 0,
            "Strategy has already been added"
        );
        uint256 currentEpoch = coverPool.currentEpoch();
        (uint256 epochStart, , , , , ) = coverPool.epoch(currentEpoch);
        uint8 delay = block.timestamp - epochStart > 7 days ? 2 : 1;
        mayBeAcceptedAtEpoch[s] = coverPool.currentEpoch() + delay;
    }

    function connectStrategy(IHegicStrategy s)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        uint256 currentEpoch = coverPool.currentEpoch();
        require(
            mayBeAcceptedAtEpoch[s] > 0,
            "You should add the strategy before"
        );
        require(mayBeAcceptedAtEpoch[s] <= currentEpoch, "Wait for next epoch");
        _connect(s);
    }

    function totalBalance() public view override returns (uint256) {
        return token.balanceOf(address(this));
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
            totalBalance();
        coverPool.payOut(transferAmount);
        emit Replenished(transferAmount);
    }

    function _withdraw(address to, uint256 amount) internal {
        require(
            amount + totalLocked + lockedPremium <=
                totalBalance() + coverPool.availableForPayment(),
            "The amount to withdraw is too large"
        );
        if (amount > 0) token.safeTransfer(to, amount);
    }

    function _connect(IHegicStrategy s) internal {
        s.connect();
        acceptedStrategy[s] = true;
    }
}

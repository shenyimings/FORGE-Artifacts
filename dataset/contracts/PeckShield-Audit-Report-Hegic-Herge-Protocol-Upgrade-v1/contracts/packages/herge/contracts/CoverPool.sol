pragma solidity ^0.8.3;

/**
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Hegic
 * Copyright (C) 2021 Hegic Protocol
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

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@hegic/utils/contracts/Math.sol";
import "./ICoverPool.sol";
import "./CoverPoolToken.sol";

contract CoverPool is
    AccessControl,
    CoverPoolToken("TODO: TokenName", "TODO: TokenSymbol"),
    ICoverPool
{
    using SafeERC20 for IERC20;
    using HegicMath for uint256;
    IERC20 public immutable override coverToken;
    IERC20 public immutable override profitToken;

    uint256 _nextPositionId = 1;
    uint256 constant CHANGING_PRICE_DECIMALS = 1e30;
    uint256 constant ADDITIONAL_DECIMALS = 1e30;
    uint256 constant MINIMAL_EPOCH_DURATION = 7 days;
    bytes32 constant TEMPORARY_ADMIN_ROLE = keccak256("TEMPORARY_ADMIN_ROLE");
    bytes32 constant OPERATIONAL_TRESUARY_ROLE =
        keccak256("OPERATIONAL_TRESUARY_ROLE");

    uint32 public windowSize = 5 days;
    uint256 public cumulativeProfit;
    uint256 public profitTokenBalance;
    uint256 public totalShare;
    uint256 public unwithdrawnCoverTokens;
    address public payoffPool;

    mapping(uint256 => uint256) public shareOf;
    mapping(uint256 => uint256) public bufferredUnclaimedProfit;
    mapping(uint256 => uint256) public cumulativePoint;
    mapping(uint256 => Epoch) public override epoch;

    uint256 public nextEpochChangingPrice;
    uint256 public override currentEpoch;

    constructor(
        IERC20 _coverToken,
        IERC20 _profitToken,
        address _payoffPool,
        uint256 initialEpochChangingPrice
    ) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(TEMPORARY_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(TEMPORARY_ADMIN_ROLE, TEMPORARY_ADMIN_ROLE);
        _setRoleAdmin(OPERATIONAL_TRESUARY_ROLE, TEMPORARY_ADMIN_ROLE);

        coverToken = _coverToken;
        profitToken = _profitToken;
        payoffPool = _payoffPool;

        nextEpochChangingPrice = initialEpochChangingPrice;
        _startNextEpoch();
    }

    // ╒═══════════════════════════════════════════╕
    //               user's functions
    // ╘═══════════════════════════════════════════╛

    /**
     * @notice user call this function to provide liquidity (in HEGIC)
     * into the Cover Pool
     * @param amount amount of the $HEGIC tokens to provide
     **/
    function provide(uint256 amount, uint256 positionId)
        external
        override
        returns (uint256)
    {
        require(
            _nextPositionId > 1 || hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Only admin can create first position"
        );
        if (positionId == 0) {
            positionId = _nextPositionId++;
            _mint(msg.sender, positionId);
        }
        require(
            _isApprovedOrOwner(msg.sender, positionId),
            "Yuo are has no access to this position"
        );
        require(
            windowSize > block.timestamp - epoch[currentEpoch].start,
            "Enterence window is closed"
        );
        _bufferUnclaimedProfit(positionId);
        uint256 shareOfProvide = _provide(positionId, amount);
        coverToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Provided(
            positionId,
            amount,
            shareOfProvide,
            shareOf[positionId],
            totalShare
        );
        return positionId;
    }

    /**
     * @notice user call this function to withdraw liquidity (in HEGIC)
     * from the Cover Pool
     * @param amount amount of the $HEGIC tokens to withdraw
     **/
    function withdraw(uint256 positionId, uint256 amount) external override {
        require(
            _isApprovedOrOwner(msg.sender, positionId),
            "only owner of the position can withdraw it"
        );
        _bufferUnclaimedProfit(positionId);
        uint256 shareOfWithdraw = _withdraw(positionId, amount);
        emit Withdrawn(
            currentEpoch,
            positionId,
            amount,
            shareOfWithdraw,
            shareOf[positionId],
            totalShare
        );
    }

    /**
     * @notice used to claim 100% of users profits in $USDC (if any).
     * @param amount amount of the $USDC profits
     **/
    function claim(uint256 positionId)
        external
        override
        returns (uint256 amount)
    {
        amount = _bufferUnclaimedProfit(positionId);
        if (amount == 0) return 0;
        bufferredUnclaimedProfit[positionId] = 0;
        profitTokenBalance -= amount;
        profitToken.safeTransfer(ownerOf(positionId), amount);
        emit Claimed(positionId, amount);
    }

    /**
     * @notice allow a user to withdraw $HEGIC token when epoch is ended.
     * @param positionId TODO
     **/
    function withdrawEpoch(uint256 positionId, uint256[] calldata outFrom)
        external
    {
        uint256 profitAmount = _bufferUnclaimedProfit(positionId);
        bufferredUnclaimedProfit[positionId] = 0;
        uint256 tokenAmount;

        for (uint256 idx = 0; idx < outFrom.length; idx++) {
            (uint256 profit, uint256 token) = _withdrawFromEpoch(
                positionId,
                outFrom[idx]
            );
            profitAmount += profit;
            tokenAmount += token;
            emit WithdrawnFromEpoch(outFrom[idx], positionId, token, profit);
        }
        profitTokenBalance -= profitAmount;

        if (profitAmount > 0) emit Claimed(positionId, profitAmount);
        coverToken.safeTransfer(ownerOf(positionId), tokenAmount);
        profitToken.safeTransfer(ownerOf(positionId), profitAmount);
    }

    /**
     * @notice allows users to close previous epoch and start next epoch
     */
    function fallbackEpochClose() external {
        require(
            block.timestamp > epoch[currentEpoch].start + 90 days,
            "It's too early yet"
        );
        _startNextEpoch();
    }

    /**
     * @notice calculates all user's profits
     * @param positionId TODO
     * @return amount amount of profits in $USDC
     **/
    function availableToClaim(uint256 positionId)
        external
        view
        override
        returns (uint256 amount)
    {
        return
            bufferredUnclaimedProfit[positionId] +
            ((cumulativeProfit - cumulativePoint[positionId]) *
                shareOf[positionId]) /
            ADDITIONAL_DECIMALS;
    }

    /**
     * @notice calcualtes amount of $HEGIC token for each user
     * @param positionId TODO
     * @return amount amount of $HEGIC tokens
     **/
    function coverTokenBalance(uint256 positionId)
        external
        view
        override
        returns (uint256 amount)
    {
        return (coverTokenTotal() * shareOf[positionId]) / totalShare;
    }

    /**
     * @notice total amount of $HEGIC tokens on the Cover Pool
     * @return amount amount of $HEGIC tokens
     **/
    function coverTokenTotal() public view returns (uint256 amount) {
        return coverToken.balanceOf(address(this)) - unwithdrawnCoverTokens;
    }

    /**
     * @notice maximum amount of $USDC the Cover Pool
     * can send to the option traders.
     * @return amount amount in $USDC
     **/
    function availableForPayment()
        external
        view
        override
        returns (uint256 amount)
    {
        uint256 changingPrice = epoch[currentEpoch].changingPrice;
        uint256 coverBalance = (coverTokenTotal() * changingPrice) /
            CHANGING_PRICE_DECIMALS;
        uint256 payoffPoolBalance = profitToken.balanceOf(payoffPool);

        {
            uint256 payoffPoolAllowance = profitToken.allowance(
                payoffPool,
                address(this)
            );
            if (payoffPoolBalance > payoffPoolAllowance)
                payoffPoolBalance = payoffPoolAllowance;
        }

        return
            payoffPoolBalance < coverBalance ? payoffPoolBalance : coverBalance;
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(CoverPoolToken, AccessControl)
        returns (bool)
    {
        return
            interfaceId == type(ICoverPool).interfaceId ||
            CoverPoolToken.supportsInterface(interfaceId);
    }

    // ╒═══════════════════════════════════════════╕
    //                admin's functions
    // ╘═══════════════════════════════════════════╛

    /**
     * TODO
     **/
    function setWindowSize(uint32 value) external onlyRole(DEFAULT_ADMIN_ROLE) {
        windowSize = value;
        emit SetWindowSize(value);
    }

    /**
     * TODO
     **/
    function setPayoffPool(address value)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        payoffPool = value;
        emit SetPayoffPool(value);
    }

    /**
     * TODO
     **/
    function setNextEpochChangingPrice(uint256 value)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        nextEpochChangingPrice = value;
        emit SetNextEpochChangingPrice(value);
    }

    /**
     * TODO
     **/
    function fixProfit() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 profitAmount = profitToken.balanceOf(address(this)) -
            profitTokenBalance;
        profitTokenBalance += profitAmount;
        cumulativeProfit += (profitAmount * ADDITIONAL_DECIMALS) / totalShare;
        _startNextEpoch();
        emit Profit(currentEpoch, profitAmount);
    }

    /**
     * @notice send $USDC from the Cover Pool
     * to the Operational Treasury if any losses on
     * the Operational Treasury
     * @param amount amount of USDC to the
     * Operational Treasury
     **/
    function payOut(uint256 amount)
        external
        override
        onlyRole(OPERATIONAL_TRESUARY_ROLE)
    {
        uint256 changingPrice = epoch[currentEpoch].changingPrice;
        uint256 outAmount = ((amount * CHANGING_PRICE_DECIMALS) /
            changingPrice);

        coverToken.safeTransfer(payoffPool, outAmount);
        profitToken.safeTransferFrom(payoffPool, msg.sender, amount);
    }

    // ╒═══════════════════════════════════════════╕
    //               internal functions
    // ╘═══════════════════════════════════════════╛

    function _provide(uint256 positionId, uint256 amount)
        internal
        returns (uint256 shareOfProvide)
    {
        uint256 totalCoverBalance = coverTokenTotal();
        shareOfProvide = totalCoverBalance > 0
            ? (amount * totalShare) / totalCoverBalance
            : amount;
        shareOf[positionId] += shareOfProvide;
        totalShare += shareOfProvide;
    }

    function _withdraw(uint256 positionId, uint256 amount)
        internal
        returns (uint256 shareOfWithdraw)
    {
        uint256 totalCoverBalance = coverTokenTotal();
        shareOfWithdraw = (amount * totalShare).ceilDiv(totalCoverBalance);
        shareOf[positionId] -= shareOfWithdraw;
        epoch[currentEpoch].outShare[positionId] += shareOfWithdraw;
        epoch[currentEpoch].totalShareOut += shareOfWithdraw;
    }

    function _bufferUnclaimedProfit(uint256 positionId)
        internal
        returns (uint256 amount)
    {
        if (totalShare == 0) return 0;

        bufferredUnclaimedProfit[positionId] +=
            ((cumulativeProfit - cumulativePoint[positionId]) *
                shareOf[positionId]) /
            ADDITIONAL_DECIMALS;
        cumulativePoint[positionId] = cumulativeProfit;

        return bufferredUnclaimedProfit[positionId];
    }

    function _startNextEpoch() internal {
        require(
            MINIMAL_EPOCH_DURATION <
                block.timestamp - epoch[currentEpoch].start,
            "The epoch is too short to be closed"
        );

        uint256 totalShareOut = epoch[currentEpoch].totalShareOut;
        uint256 coverTokenOut = totalShare == 0
            ? 0
            : (totalShareOut * coverTokenTotal()) / totalShare;
        uint256 profitOut = (totalShareOut *
            (cumulativeProfit - epoch[currentEpoch].cumulativePoint)) /
            ADDITIONAL_DECIMALS;
        unwithdrawnCoverTokens += coverTokenOut;
        epoch[currentEpoch].coverTokenOut = coverTokenOut;
        epoch[currentEpoch].profitTokenOut = profitOut;
        totalShare -= epoch[currentEpoch].totalShareOut;

        currentEpoch++;
        epoch[currentEpoch].cumulativePoint = cumulativeProfit;
        epoch[currentEpoch].start = block.timestamp;
        epoch[currentEpoch].changingPrice = nextEpochChangingPrice;
        emit EpochStarted(currentEpoch, nextEpochChangingPrice);
    }

    function _withdrawFromEpoch(uint256 positionId, uint256 epochID)
        internal
        returns (uint256 profit, uint256 token)
    {
        require(
            epochID < currentEpoch,
            "Withdraw from current and future epoch are anavailable"
        );
        Epoch storage e = epoch[epochID];
        profit = (e.outShare[positionId] * e.profitTokenOut) / e.totalShareOut;
        token = (e.outShare[positionId] * e.coverTokenOut) / e.totalShareOut;
        e.outShare[positionId] = 0;
        unwithdrawnCoverTokens -= token;
    }
}

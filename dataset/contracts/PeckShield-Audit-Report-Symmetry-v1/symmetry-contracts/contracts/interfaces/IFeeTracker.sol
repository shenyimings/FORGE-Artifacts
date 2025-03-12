// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./IVotingEscrow.sol";

interface IFeeTracker {
    /*=== struct ===*/

    struct Tier {
        uint portion; // veSYM holding portion
        uint discount; // discount percent
    }

    struct LockedIterator {
        uint maxEpoch;
        uint nextEpoch;
        IVotingEscrow.Point locked;
        IVotingEscrow.Point newLocked;
    }

    struct StakedIterator {
        uint maxEpoch;
        uint nextEpoch;
        IVotingEscrow.StakedPoint staked;
        IVotingEscrow.StakedPoint newStaked;
    }

    /*=== events ===*/

    event Claimed(address indexed account, uint weekCursor, uint amount);

    /*=== functions ===*/

    function claimIncentives(address _account) external returns (uint);

    function coupon() external view returns (address);

    function getTradingFee(
        address _account,
        int _sizeDelta,
        int _price,
        bool _isTaker
    ) external view returns (uint fee, uint couponUsed);

    function distributeIncentives(uint _fee) external;

    function liquidationFee(int notional) external view returns (int);

    function liquidationPenalty(int notional) external view returns (int);

    function market() external view returns (address);

    function perpTracker() external view returns (address);

    function settings() external view returns (address);

    function tradingFeeDiscount(address _account) external view returns (uint discount);

    function tradingFeeIncentives(uint) external view returns (uint);

    function tradingFeeTiers(uint) external view returns (uint portion, uint discount);

    function votingEscrow() external view returns (address);
}

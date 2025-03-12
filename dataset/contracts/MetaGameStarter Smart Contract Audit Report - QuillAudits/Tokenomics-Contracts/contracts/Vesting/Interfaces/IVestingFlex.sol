// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0.0;


interface IVestingFlex  {

    event VestingCreated(address indexed who, uint256 indexed which, Vesting vesting);
    event VestingReduced(address indexed who, uint256 indexed which, uint256 amountBefore, uint256 amountAfter);
    event Retrieved(address indexed who, uint256 amount);
    event OwnerRevokeDisabled(address indexed who, uint256 indexed which);
    event OwnerRevokeDisabledGlobally(uint256 indexed time);

    struct Vesting {
        uint128 vestedTotal;
        uint128 claimedTotal;
        uint48 start;
        uint48 duration;
        uint48 cliff;          // % of tokens to be released ahead of startTime: 1_000_000_000 => 100%
        uint48 cliffDelay;     // the cliff can be retrieved this many seconds before StartTime of the schedule
        uint48 exp;        // exponent, form of the release, 0 => instant, when timeestmp == `end`; 1 => linear; 2 => quadratice etc.
        bool revokable;
    }

    // beneficiary retrieve
    function retrieve(uint256 which) external returns(uint256);

    // OWNER
    function createVestings(address from, address[] calldata recipients, Vesting[] calldata vestings) external;
    function reduceVesting(address who, uint256 which, uint128 amountToReduceTo, bool revokeComplete, address tokenReceiver) external;
    function disableOwnerRevokeGlobally() external;
    function disableOwnerRevoke(address who, uint256 which) external;

    // external view
    function getReleasedAt(address who, uint256 which, uint256 timestamp) external view returns(uint256);
    function getReleased(address who, uint256 which) external view returns(uint256);
    function getClaimed(address who, uint256 which) external view returns(uint256);
    function getClaimableAtTimestamp(address who, uint256 which, uint256 when) external view returns(uint256);
    function getClaimableNow(address who, uint256 which) external view returns(uint256);
    function getNumberOfVestings(address who) external view returns(uint256);
    function getVesting(address who, uint256 which) external view returns(Vesting memory);
    function canAdminRevoke(address who, uint256 which) external view returns(bool);
    function token() external view returns(address);
}
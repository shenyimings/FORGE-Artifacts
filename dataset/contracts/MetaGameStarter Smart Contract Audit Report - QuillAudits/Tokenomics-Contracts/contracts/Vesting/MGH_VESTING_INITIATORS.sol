pragma solidity ^0.8.0.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Interfaces/IVestingFlex.sol";

/// @notice DO NOT SEND TOKENS TO THIS CONTRACT
contract MGH_VESTING_INITIATORS is Ownable {
    using SafeERC20 for IERC20;

    struct Vesting {
        uint128 vested;
        uint128 claimed;
        uint256 lastRewardClaimed;
    }

    struct Staking {
        uint128 reward;
        uint128 claimed;
        mapping(address => bool) claimedByRecipient;
    }

    uint256 public immutable START;
    uint256 public immutable DURATION;
    uint256 public immutable CLIFF;          // % of tokens to be released ahead of startTime: 1_000_000_000 => 100%
    uint256 public immutable CLIFF_DELAY;     // the cliff can be retrieved this many seconds before StartTime of the schedule
    uint256 public immutable EXP;        // exponent, form of the release, 0 => instant, when timeestmp == `end`; 1 => linear; 2 => quadratice etc.
    bool public adminCanRevokeGlobal = true;


    string constant private ZERO_VALUE = "param is zero, when it should not";
    uint256 constant private PRECISISION = 1_000_000_000;
    address public immutable token;

    mapping(address => Vesting) private _vestingByUser;
    mapping(uint256 => Staking) private _stakingRewards;

    uint128 vestedTotal;
    uint128 claimedTotal;
    uint256 stakingDelay = 1 days;

    address private _revenueSplitter;

    constructor(
        address _token,
        address _owner,
        uint256 _start,
        uint256 _duration,
        uint256 _cliff,
        uint256 _cliffDelay,
        uint256 _exp
    ) {
        token = _token;
        START = _start;
        DURATION = _duration;
        CLIFF = _cliff;
        CLIFF_DELAY = _cliffDelay;
        EXP = _exp;
        _transferOwnership(_owner);
    }

    //// USER ////

    /// @notice sends all vested tokens to the vesting who
    /// @notice call `getClaimableNow()` to see the amount of available tokens
    function retrieve() external {
        _retrieve(msg.sender);
    }

    function retrieveStakingRewards(address recipient, uint256[] calldata timestamps) external {
        uint256 userVestedAmount = _vestingByUser[recipient].vested;
        uint256 totalVestedAmount = vestedTotal;
        uint256 totalPayment;
        for (uint256 i = 0; i < timestamps.length; i++) {
            Staking storage stk  = _stakingRewards[timestamps[i]];
            uint256 reward = stk.reward;
            uint256 claimed = stk.claimed;

            require(block.timestamp > timestamps[i] + stakingDelay, "too early");
            require(! stk.claimedByRecipient[recipient], "already claimed");

            stk.claimedByRecipient[recipient] = true;
            if(reward <= claimed) continue;

            uint256 rewardForUser = reward * userVestedAmount / totalVestedAmount;
            rewardForUser = (rewardForUser + claimed) > reward ? reward - claimed : rewardForUser;

            totalPayment += rewardForUser;
            stk.claimed = uint128(claimed + rewardForUser);
        }
        _processPayment(address(this), recipient, totalPayment);
    }


    //// OWNER ////

    /// @notice create multiple vestings at once for different beneficiaries
    /// @param patron the one paying for the Vestings 
    /// @param beneficiaries the recipients of `vestings` in the same order
    /// @param vestings the vesting schedules in order for recipients
    function createVestings(address patron, address[] calldata beneficiaries, Vesting[] calldata vestings) external onlyOwner {
        require(beneficiaries.length == vestings.length, "length mismatch");

        uint256 totalAmount;
        for(uint256 i = 0; i < vestings.length; i++) {
            address who = beneficiaries[i];
            Vesting calldata vesting = vestings[i];

            totalAmount += vesting.vested;
            _setVesting(who, vesting);
        }
        _processPayment(patron, address(this), totalAmount);
        vestedTotal += uint128(totalAmount);
    }

    /// @notice reduces the vested amount and sends the difference in tokens to `tokenReceiver`
    /// @param who address that the tokens are vested for
    /// @param amountToReduceTo new total amount for the vesting
    /// @param tokenReceiver address receiving the tokens that are not needed for vesting anymore
    function reduceVesting(
        address who, 
        uint128 amountToReduceTo, 
        address tokenReceiver
    ) external onlyOwner {
        require(adminCanRevokeGlobal, "admin not allowed anymore");

        Vesting storage vesting = _vestingByUser[who];
        uint128 amountBefore = vesting.vested;

        // we give what was already released to `who`
        _retrieve(who);

        require(amountToReduceTo >= vesting.claimed, "cannot reduce, already claimed");
        require(amountBefore > amountToReduceTo, "must reduce");

        vesting.vested = amountToReduceTo;
        vestedTotal = vestedTotal - amountBefore + amountToReduceTo;

        _processPayment(address(this), tokenReceiver, amountBefore - amountToReduceTo);

        emit VestingReduced(who, amountBefore, amountToReduceTo);
    }

    /// @notice when this function is called once, the owner of this
    ///         contract cannot revoke vestings, once they are created
    function disableOwnerRevokeGlobally() external onlyOwner {
        require(adminCanRevokeGlobal);
        adminCanRevokeGlobal = false;
        emit OwnerRevokeDisabledGlobally(block.timestamp);
    }

    function recoverWrongToken(address _token) external onlyOwner {
        require(_token != token || claimedTotal == vestedTotal, "cannot retrieve vested token");
        if(_token == address(0)) {
            msg.sender.call{ value: address(this).balance }("");
        } else {
            _processPayment(address(this), msg.sender, IERC20(_token).balanceOf(address(this)));
        }
    }

    function setRevenueSplitter(address revenueSplitter) external onlyOwner {
        _revenueSplitter = revenueSplitter;
    }

    function setStakingDelay(uint256 delay) external onlyOwner {
        stakingDelay = delay;
    }


    //// INTERNAL ////

    /// @dev sends all claimable token in the vesting to `who` and updates vesting
    function _retrieve(address who) internal {
        _enforceVestingExists(who);

        Vesting storage vesting = _vestingByUser[who];
        uint256 totalReleased = _releasedAt(vesting, block.timestamp);
        uint256 claimedBefore = vesting.claimed;

        // check this to not block `reduceVesting()`
        if(totalReleased < claimedBefore) {
            if(msg.sender == owner()) return;
            revert("already claimed");
        }

        uint256 claimable = totalReleased - claimedBefore;
        vesting.claimed = uint128(totalReleased);
        claimedTotal    += uint128(claimable);

        _processPayment(address(this), who, claimable);

        emit Retrieved(who, claimable);
    }

    /// @dev sets the vesting for recipient, can only be done once
    function _setVesting(address recipient, Vesting calldata vesting) internal {
        require(_vestingByUser[recipient].vested == 0, "already has a vesting");
        _enforceVestingParams(recipient, vesting);
        _vestingByUser[recipient] = vesting;
        emit VestingCreated(recipient, vesting);
    }

    function _processPayment(address from, address to, uint256 amount) internal {
        if(amount == 0) return;
        if(from == address(this)) {
            IERC20(token).safeTransfer(to, amount);
        } else {
            IERC20(token).safeTransferFrom(from, to, amount);
        }
    }

    /// @dev throws if vesting parameters are 'nonsensical'
    function _enforceVestingParams(address recipient, Vesting calldata vesting) internal view {
        require(recipient != address(0), ZERO_VALUE);
        require(recipient != address(this), "cannot vest for self");

        require(vesting.vested != 0, ZERO_VALUE);
        require(vesting.claimed == 0, "claimed == 0");
    }

    /// @dev throws if the vesting does not exist
    function _enforceVestingExists(address who) internal view {
        require(_vestingByUser[who].vested > 0, "vesting doesnt exist");
    }

    /// @dev calculates the fraction of the total amount that can be retrieved at a given timestamp. 
    ///      Based on `PRECISION`
    function _releasedFractionAt(uint256 timestamp, uint256 exponent) internal view returns(uint256) {
        if(timestamp + CLIFF_DELAY < START) {
            return 0;
        }
        if(timestamp < START) {
            return CLIFF;
        }
        uint256 fraction = (PRECISISION * (timestamp - START) ** exponent) / (uint256(DURATION) ** exponent) + CLIFF;
        if (fraction < PRECISISION) {
            return fraction;
        }
        return PRECISISION;
    }

    ///@dev calculates the amount of tokens that can be retrieved at a given timestamp. 
    function _releasedAt(Vesting storage vesting, uint256 timestamp) internal view returns(uint256) {
        return _releasedFractionAt(timestamp, EXP) * uint256(vesting.vested) / PRECISISION;
    }


    //// EXTERNAL VIEW ////

    /// @return amount number of tokens that are released in the vesting at a given timestamp
    function getReleasedAt(address who, uint256 timestamp) external view returns(uint256) {
        _enforceVestingExists(who);
        return _releasedAt(_vestingByUser[who], timestamp);
    }

    /// @return amount number of tokens that are released in the vesting at the moment
    function getReleased(address who) external view returns(uint256) {
        _enforceVestingExists(who);
        return _releasedAt(_vestingByUser[who], block.timestamp);
    }

    /// @return amount number of tokens that were already retrieved in the vesting
    function getClaimed(address who) external view returns(uint256) {
        _enforceVestingExists(who);
        return _vestingByUser[who].claimed;
    }

    function getClaimableAt(address who, uint256 when) public view returns(uint256) {
        _enforceVestingExists(who);

        uint256 released =  _releasedAt(_vestingByUser[who], when);
        uint256 claimed  = _vestingByUser[who].claimed;
        return claimed >= released ? 0 : released - claimed;
    }

    /// @return amount number of tokens that can be retrieved in the vesting at the moment
    function getClaimableNow(address who) external view returns(uint256) {
        return getClaimableAt(who, block.timestamp);
    }

    /// @param who beneficiary of the vesting
    /// @notice check `getNumberOfVestings(who)` for the smallest out-of-bound `which`
    function getVesting(address who) external view returns(Vesting memory) {
        _enforceVestingExists(who);
        return _vestingByUser[who];
    }

    function balanceOf(address who) external view returns(uint256 sum) {
        Vesting storage vesting = _vestingByUser[who];
        uint256 vested = vesting.vested;
        uint256 claimed = vesting.claimed;

        return vested > claimed ? vested - claimed : 0;
    }

    function stakeableBalance() external view returns(uint256) {
        uint256 linearReleased = _releasedFractionAt(block.timestamp, 1);
        uint256 actualReleased = _releasedFractionAt(block.timestamp, EXP);
        if(linearReleased == 0) return 0;
        if(actualReleased >= linearReleased) return 0;

        return (linearReleased - actualReleased) * uint256(vestedTotal) / PRECISISION;
    }

    function notifyShareholder(address _token, uint256 amount) external {
        require(msg.sender == _revenueSplitter);
        require(token == _token, "wrong token received");
        _stakingRewards[block.timestamp].reward += uint128(amount);
        emit StakingRewardsDistributed(amount, block.timestamp);
    }

    event VestingCreated(address indexed who, Vesting vesting);
    event VestingReduced(address indexed who, uint256 amountBefore, uint256 amountAfter);
    event Retrieved(address indexed who, uint256 amount);
    event OwnerRevokeDisabledGlobally(uint256 indexed time);

    event StakingRewardsDistributed(uint256 amount, uint256 timestamp);
}
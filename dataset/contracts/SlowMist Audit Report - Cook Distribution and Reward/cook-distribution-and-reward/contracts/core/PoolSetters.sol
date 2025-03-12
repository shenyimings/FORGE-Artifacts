pragma solidity ^0.6.2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./PoolState.sol";
import "./PoolGetters.sol";

contract PoolSetters is PoolState, PoolGetters {
    using SafeMath for uint256;

    /**
     * Global
     */
    function incrementTotalRewarded(uint256 amount) internal {
        _state.balance.rewarded = _state.balance.rewarded.add(amount);
    }

    function decrementTotalRewarded(uint256 amount, string memory reason)
        internal
    {
        _state.balance.rewarded = _state.balance.rewarded.sub(amount, reason);
    }

    function updateLastRewardBlock(uint256 lastRewardBlock) internal {
        _state.lastRewardBlock = lastRewardBlock;
    }

    /**
     * Account
     */
    function incrementBalanceOfStaked(address account, uint256 amount)
        internal
    {
        _state.accounts[account].staked = _state.accounts[account].staked.add(
            amount
        );
        _state.balance.staked = _state.balance.staked.add(amount);

        Vesting memory staking = Vesting(blockTimestamp(), amount);
        _state.accounts[account].stakings.push(staking);
    }

    function decrementBalanceOfStaked(
        address account,
        uint256 amount,
        string memory reason
    ) internal {
        _state.accounts[account].staked = _state.accounts[account].staked.sub(
            amount,
            reason
        );
        _state.balance.staked = _state.balance.staked.sub(amount, reason);

        uint256 remainingAmount = amount;
        for (uint256 i = 0; i < _state.accounts[account].stakings.length; i++) {
            if (remainingAmount == 0) {
                break;
            }
            uint256 totalStakingAmount =
                _state.accounts[account].stakings[i].amount;

            uint256 unstakeAmount =
                totalStakingAmount > remainingAmount
                    ? remainingAmount
                    : totalStakingAmount;
            _state.accounts[account].stakings[i].amount = totalStakingAmount
                .sub(unstakeAmount, reason);
            remainingAmount = remainingAmount.sub(unstakeAmount, reason);
        }
    }

    function incrementBalanceOfPhantom(address account, uint256 amount)
        internal
    {
        _state.accounts[account].phantom = _state.accounts[account].phantom.add(
            amount
        );
        _state.balance.phantom = _state.balance.phantom.add(amount);
    }

    function decrementBalanceOfPhantom(
        address account,
        uint256 amount,
        string memory reason
    ) internal {
        _state.accounts[account].phantom = _state.accounts[account].phantom.sub(
            amount,
            reason
        );
        _state.balance.phantom = _state.balance.phantom.sub(amount, reason);
    }

    function incrementBalanceOfClaimed(address account, uint256 amount)
        internal
    {
        _state.accounts[account].claimed = _state.accounts[account].claimed.add(
            amount
        );
        _state.balance.claimed = _state.balance.claimed.add(amount);
    }

    function addToVestingSchdule(address account, uint256 amount) internal {
        Vesting memory vesting = Vesting(blockTimestamp(), amount);
        _state.accounts[account].vestings.push(vesting);
        _state.balance.vesting = _state.balance.vesting.add(amount);
    }

    // Admin Functions
    // Put an evil address into blacklist
    function blacklistAddress(address addr) public {
        require(hasRole(MANAGER_ROLE, msg.sender), "only manager");
        _state.accounts[addr].isBlacklisted = true;
    }

    //Remove an address from blacklist
    function removeAddressFromBlacklist(address addr) public {
        require(hasRole(MANAGER_ROLE, msg.sender), "only manager");
        _state.accounts[addr].isBlacklisted = false;
    }

    // Pause all liquidity mining program
    function pauseMinigReward() public {
        require(hasRole(MANAGER_ROLE, msg.sender), "only manager");
        _state.pauseMinig = true;
        _state.REWARD_PER_BLOCK = 0;
    }

    // resume liquidity mining program
    function resumeMiningReward(uint256 rewardPerBlock) public {
        require(hasRole(MANAGER_ROLE, msg.sender), "only manager");
        _state.pauseMinig = false;
        _state.REWARD_PER_BLOCK = rewardPerBlock;
    }

    function setTotalPoolCapLimit(uint256 totalPoolCapLimit) public {
        require(hasRole(MANAGER_ROLE, msg.sender), "only manager");
        _state.totalPoolCapLimit = totalPoolCapLimit;
    }

    function setStakeLimitPerAddress(uint256 stakeLimitPerAddress) public {
        require(hasRole(MANAGER_ROLE, msg.sender), "only manager");
        _state.stakeLimitPerAddress = stakeLimitPerAddress;
    }
}

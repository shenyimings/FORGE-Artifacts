// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

pragma experimental ABIEncoderV2;
import "./SharedVariables.sol";
import "./Pools/SponsorPool.sol";
import "./Pools/ReferralPool.sol";
import "./libs/SortedLinkedList.sol";


contract Pools is SponsorPool, ReferralPool, SharedVariables {

    uint8 public constant MAX_REF_POOL_USERS = 12;
    uint8 public constant MAX_SPONSOR_POOL_USERS = 10;

    function _resetPools() internal {
        _cleanSponsorPoolUsers();
        _cleanRefPoolUsers();
        delete refPoolBalance;
        delete sponsorPoolBalance;
        poolDrewAt = uint32(block.timestamp);
        poolCycle++;
    }

    function _updateSponsorPoolUsers(User memory user, Stake memory stake) internal {
        _addSponsorPoolRecord(user.wallet, stake.deposit, stake.id);
    }

    // Reorganise top ref-pool users to draw pool for
    function _updateRefPoolUsers(User memory uplinkUser , Stake memory stake, uint8 uplinkUserStakeId) internal {
        _addRefPoolRecord(uplinkUser.wallet, stake.deposit, uplinkUserStakeId);
    }

    function drawPool() public {
        if (block.timestamp > poolDrewAt + 1 days) {

            SortedLinkedList.Item memory current = refPoolUsers[0];
            uint16 i = 0;

            while (i < MAX_REF_POOL_USERS && current.next != SortedLinkedList.GUARD) {
                current = refPoolUsers[current.next];
                users[current.user].stakes[current.id].rewards = users[current.user].stakes[current.id].rewards.add(_calcPercentage(refPoolBalance, refPoolBonuses[i]));
                i++;
            }

            current = sponsorPoolUsers[0];
            i = 0;

            while (i < MAX_SPONSOR_POOL_USERS && current.next != SortedLinkedList.GUARD) {
                current = sponsorPoolUsers[current.next];
                users[current.user].stakes[current.id].rewards = users[current.user].stakes[current.id].rewards.add(_calcPercentage(sponsorPoolBalance, sponsorPoolBonuses[i]));
                i++;
            }

            emit PoolDrawn(refPoolBalance, sponsorPoolBalance);

            _resetPools();
        }
    }

    // pool info getters

    function getPoolInfo() external view returns (uint32, uint16, uint, uint) {
        return (poolDrewAt, poolCycle, sponsorPoolBalance, refPoolBalance);
    }

    function getPoolParticipants() external view returns (address[] memory, uint8[] memory, uint[] memory, address[] memory, uint8[] memory, uint[] memory) {
        address[] memory sponsorPoolUsersAddresses = new address[](MAX_SPONSOR_POOL_USERS);
        uint8[] memory sponsorPoolUsersStakeIds = new uint8[](MAX_SPONSOR_POOL_USERS);
        uint[] memory sponsorPoolUsersAmounts = new uint[](MAX_SPONSOR_POOL_USERS);

        address[] memory refPoolUsersAddresses = new address[](MAX_REF_POOL_USERS);
        uint8[] memory refPoolUsersStakeIds = new uint8[](MAX_REF_POOL_USERS);
        uint[] memory refPoolUsersAmounts = new uint[](MAX_REF_POOL_USERS);

        uint16 i = 0;
        SortedLinkedList.Item memory current = sponsorPoolUsers[i];

        while (i < MAX_SPONSOR_POOL_USERS && current.next != SortedLinkedList.GUARD) {
            current = sponsorPoolUsers[current.next];
            sponsorPoolUsersAddresses[i] = current.user;
            sponsorPoolUsersStakeIds[i] = current.id;
            sponsorPoolUsersAmounts[i] = current.score;
            i++;
        }

        i = 0;
        current = refPoolUsers[i];

        while (i < MAX_REF_POOL_USERS && current.next != SortedLinkedList.GUARD) {
            current = refPoolUsers[current.next];
            refPoolUsersAddresses[i] = current.user;
            refPoolUsersStakeIds[i] = current.id;
            refPoolUsersAmounts[i] = current.score;
            i++;
        }

        return (sponsorPoolUsersAddresses, sponsorPoolUsersStakeIds, sponsorPoolUsersAmounts, refPoolUsersAddresses, refPoolUsersStakeIds, refPoolUsersAmounts);
    }
}

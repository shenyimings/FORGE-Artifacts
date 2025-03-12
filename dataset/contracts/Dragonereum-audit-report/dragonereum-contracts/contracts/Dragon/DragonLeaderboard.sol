pragma solidity 0.4.25;

import "../Common/Upgradable.sol";
import "../Common/SafeMath256.sol";

contract DragonLeaderboard is Upgradable {
    using SafeMath256 for uint256;

    struct Leaderboard {
        uint256 id;
        uint32 coolness;
    }

    Leaderboard[10] leaderboard;

    uint256 constant REWARDED_DRAGONS_AMOUNT = 10;
    uint256 constant DISTRIBUTING_FRACTION_OF_REMAINING_GOLD = 10000;
    uint256 rewardPeriod = 24 hours;
    uint256 lastRewardDate;

    constructor() public {
        lastRewardDate = now; // solium-disable-line security/no-block-members
    }

    function update(uint256 _id, uint32 _coolness) external onlyController {
        uint256 _index;
        bool _isIndex;
        uint256 _existingIndex;
        bool _isExistingIndex;

        // if coolness is more than coolness of the last dragon
        if (_coolness > leaderboard[leaderboard.length.sub(1)].coolness) {

            for (uint256 i = 0; i < leaderboard.length; i = i.add(1)) {
                // if a place for a dragon is found
                if (_coolness > leaderboard[i].coolness && !_isIndex) {
                    _index = i;
                    _isIndex = true;
                }
                // if dragon is already in leaderboard
                if (leaderboard[i].id == _id && !_isExistingIndex) {
                    _existingIndex = i;
                    _isExistingIndex = true;
                }
                if(_isIndex && _isExistingIndex) break;
            }
            // if dragon stayed at the same place
            if (_isExistingIndex && _index >= _existingIndex) {
                leaderboard[_existingIndex] = Leaderboard(_id, _coolness);
            } else if (_isIndex) {
                _add(_index, _existingIndex, _isExistingIndex, _id, _coolness);
            }
        }
    }

    function _add(
        uint256 _index,
        uint256 _existingIndex,
        bool _isExistingIndex,
        uint256 _id,
        uint32 _coolness
    ) internal {
        uint256 _length = leaderboard.length;
        uint256 _indexTo = _isExistingIndex ? _existingIndex : _length.sub(1);

        // shift other dragons
        for (uint256 i = _indexTo; i > _index; i = i.sub(1)){
            leaderboard[i] = leaderboard[i.sub(1)];
        }

        leaderboard[_index] = Leaderboard(_id, _coolness);
    }

    function getDragonsFromLeaderboard() external view returns (uint256[10] result) {
        for (uint256 i = 0; i < leaderboard.length; i = i.add(1)) {
            result[i] = leaderboard[i].id;
        }
    }

    function updateRewardTime() external onlyController {
        require(lastRewardDate.add(rewardPeriod) < now, "too early"); // solium-disable-line security/no-block-members
        lastRewardDate = now; // solium-disable-line security/no-block-members
    }

    function getRewards(uint256 _remainingGold) external view returns (uint256[10] rewards) {
        for (uint8 i = 0; i < REWARDED_DRAGONS_AMOUNT; i++) {
            rewards[i] = _remainingGold.mul(uint256(2).pow(REWARDED_DRAGONS_AMOUNT.sub(1))).div(
                DISTRIBUTING_FRACTION_OF_REMAINING_GOLD.mul((uint256(2).pow(REWARDED_DRAGONS_AMOUNT)).sub(1)).mul(uint256(2).pow(i))
            );
        }
    }

    function getDate() external view returns (uint256, uint256) {
        return (lastRewardDate, rewardPeriod);
    }
}

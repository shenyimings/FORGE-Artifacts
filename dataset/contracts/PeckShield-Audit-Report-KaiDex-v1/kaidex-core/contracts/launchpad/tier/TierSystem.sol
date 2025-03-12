//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../../interfaces/IStKDX.sol";

contract TierSystem is Ownable {
    using SafeMath for uint256;
    IStKDX public stKdx;
    // Tier checking: 
    uint256[2][] public kdxStakedTiers = [
        [uint256(200 * 1e18), 1], // Bronze
        [uint256(800 * 1e18), 5],  // Silver    
        [uint256(2500 * 1e18), 20],  // Gold    
        [uint256(6000 * 1e18), 60],  // Platinum
        [uint256(12000 * 1e18), 150]  // Diamond
    ];

    constructor(IStKDX _stKdx) {
        stKdx = _stKdx;
    }

    function setKdxStakedTiers (uint256[2][] memory _tiers) public onlyOwner {
        kdxStakedTiers = _tiers;
    }

    function getTier (address _account) external view returns(uint256) {
        uint256 currentSnapshotId = stKdx.getCurrentSnapshotId();
        uint256 kdxStaked = stKdx.getKdxBalanceAt(_account, currentSnapshotId);
        uint256 tier = 0;
        while(tier < kdxStakedTiers.length && kdxStaked >= kdxStakedTiers[tier][0]) {
            tier ++;
        }
        return tier;
    }

    function getAllocationPoint(uint256 _tier) external view returns(uint256) {
        require(_tier <= kdxStakedTiers.length, 'tier invalid');
        if (_tier == 0) return 0;
        return kdxStakedTiers[_tier - 1][1];
    }

    // Get tier from _snapshotIdFrom to _snapshotIdTo 
    function getTierFromTo (address _account, uint256 _snapshotIdFrom, uint256 _snapshotIdTo) external view returns(uint256) {
        uint256 currentSnapshotId = stKdx.getCurrentSnapshotId();
        uint256 to = _snapshotIdTo < currentSnapshotId ? _snapshotIdTo : currentSnapshotId;
        uint256 kdxStaked = _getAverageFrom(_account,_snapshotIdFrom, to);
        uint256 tier = 0;
        while(tier < kdxStakedTiers.length && kdxStaked >= kdxStakedTiers[tier][0]) {
            tier ++;
        }
        return tier;
    }

    function _getAverageFrom(address _account, uint256 _snapshotIdFrom, uint256 _snapshotIdTo)
        private
        view
        returns (uint256)
    {
        if (_snapshotIdFrom >= _snapshotIdTo) {
            return stKdx.getKdxBalanceAt(_account, _snapshotIdTo);
        }
        uint256 averageBalance;
        for (uint256 i = _snapshotIdFrom; i <= _snapshotIdTo; i++) {
            averageBalance = averageBalance.add(stKdx.getKdxBalanceAt(_account, i));
        }
        return averageBalance / (_snapshotIdTo - _snapshotIdFrom + 1);
    }

    function getAverageFrom (address _account, uint256 _snapshotIdFrom) public view returns (uint256) {
        uint256 currentSnapshotId = stKdx.getCurrentSnapshotId();
        return _getAverageFrom((_account), _snapshotIdFrom, currentSnapshotId);
    }

    function getAverageFromTo (address _account, uint256 _snapshotIdFrom, uint256 _snapshotIdTo) public view returns (uint256) {
        return _getAverageFrom((_account), _snapshotIdFrom, _snapshotIdTo);
    }
}

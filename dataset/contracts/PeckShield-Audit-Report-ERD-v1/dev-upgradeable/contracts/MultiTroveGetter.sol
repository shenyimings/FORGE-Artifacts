// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./TroveManager.sol";
import "./Interfaces/ISortedTroves.sol";

/*  Helper contract for grabbing Trove data for the front end. Not part of the core ERD system. */
contract MultiTroveGetter is Initializable {
    struct CombinedTroveData {
        address owner;
        uint256 debt;
        address[] collaterals;
        uint256[] colls;
        uint256[] shares;
        uint256[] stakes;
        uint256[] snapshotColls;
        uint256[] snapshotEUSDDebts;
    }

    TroveManager public troveManager; // XXX Troves missing from ITroveManager?
    ISortedTroves public sortedTroves;

    function initialize(TroveManager _troveManager, ISortedTroves _sortedTroves) public initializer {
        troveManager = _troveManager;
        sortedTroves = _sortedTroves;
    }

    function getMultipleSortedTroves(int256 _startIdx, uint256 _count)
        external
        view
        returns (CombinedTroveData[] memory _troves)
    {
        uint256 startIdx;
        bool descend;

        if (_startIdx >= 0) {
            startIdx = uint256(_startIdx);
            descend = true;
        } else {
            startIdx = uint256(-(_startIdx + 1));
            descend = false;
        }

        uint256 sortedTrovesSize = sortedTroves.getSize();

        if (startIdx >= sortedTrovesSize) {
            _troves = new CombinedTroveData[](0);
        } else {
            uint256 maxCount = sortedTrovesSize - startIdx;

            if (_count > maxCount) {
                _count = maxCount;
            }

            if (descend) {
                _troves = _getMultipleSortedTrovesFromHead(startIdx, _count);
            } else {
                _troves = _getMultipleSortedTrovesFromTail(startIdx, _count);
            }
        }
    }

    function _getMultipleSortedTrovesFromHead(uint256 _startIdx, uint256 _count)
        internal
        view
        returns (CombinedTroveData[] memory _troves)
    {
        address currentTroveowner = sortedTroves.getFirst();

        for (uint256 idx = 0; idx < _startIdx; ++idx) {
            currentTroveowner = sortedTroves.getNext(currentTroveowner);
        }

        _troves = new CombinedTroveData[](_count);

        for (uint256 idx = 0; idx < _count; ++idx) {
            _troves[idx] = _getCombinedTroveData(currentTroveowner);

            currentTroveowner = sortedTroves.getNext(currentTroveowner);
        }
    }

    function _getMultipleSortedTrovesFromTail(uint256 _startIdx, uint256 _count)
        internal
        view
        returns (CombinedTroveData[] memory _troves)
    {
        address currentTroveowner = sortedTroves.getLast();

        for (uint256 idx = 0; idx < _startIdx; ++idx) {
            currentTroveowner = sortedTroves.getPrev(currentTroveowner);
        }

        _troves = new CombinedTroveData[](_count);

        for (uint256 idx = 0; idx < _count; ++idx) {
            _troves[idx] = _getCombinedTroveData(currentTroveowner);

            currentTroveowner = sortedTroves.getPrev(currentTroveowner);
        }
    }

    function _getCombinedTroveData(address _troveOwner)
        internal
        view
        returns (CombinedTroveData memory data)
    {
        data.owner = _troveOwner;
        data.debt = troveManager.getTroveDebt(data.owner);
        (data.colls, data.shares, data.collaterals) = troveManager.getTroveColls(
            data.owner
        );
        (data.stakes, , ) = troveManager.getTroveStakes(data.owner);
        data.snapshotColls = new uint256[](data.collaterals.length);
        data.snapshotEUSDDebts = new uint256[](data.collaterals.length);
        uint256 collsLen = data.collaterals.length;
        for (uint256 i; i < collsLen; ++i) {
            address collateral = data.collaterals[i];
            data.snapshotColls[i] = troveManager.getRewardSnapshotColl(
                data.owner,
                collateral
            );
            data.snapshotEUSDDebts[i] = troveManager.getRewardSnapshotEUSD(
                data.owner,
                collateral
            );
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "../Interfaces/ITroveManager.sol";
import "../Interfaces/ISortedTroves.sol";
import "../Interfaces/IPriceFeed.sol";
import "../Dependencies/ERDMath.sol";

/* Wrapper contract - used for calculating gas of read-only and internal functions.
Not part of the ERD application. */
contract FunctionCaller {
    ITroveManager troveManager;
    address public troveManagerAddress;

    ISortedTroves sortedTroves;
    address public sortedTrovesAddress;

    IPriceFeed priceFeed;
    address public priceFeedAddress;

    // --- Dependency setters ---

    function setTroveManagerAddress(address _troveManagerAddress) external {
        troveManagerAddress = _troveManagerAddress;
        troveManager = ITroveManager(_troveManagerAddress);
    }

    function setSortedTrovesAddress(address _sortedTrovesAddress) external {
        troveManagerAddress = _sortedTrovesAddress;
        sortedTroves = ISortedTroves(_sortedTrovesAddress);
    }

    function setPriceFeedAddress(address _priceFeedAddress) external {
        priceFeedAddress = _priceFeedAddress;
        priceFeed = IPriceFeed(_priceFeedAddress);
    }

    // --- Non-view wrapper functions used for calculating gas ---

    function troveManager_getCurrentICR(address _address)
        external
        view
        returns (uint256)
    {
        uint256 price = priceFeed.fetchPrice_view();
        return troveManager.getCurrentICR(_address, price);
    }

    function sortedTroves_findInsertPosition(
        uint256 _ICR,
        address _prevId,
        address _nextId
    ) external view returns (address, address) {
        return sortedTroves.findInsertPosition(_ICR, _prevId, _nextId);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface ISortedTroves {
    event BorrowerOperationsAddressChanged(address _borrowerOperationsAddress);
    event NodeAdded(address _id, uint256 _NICR);
    event NodeRemoved(address _id);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event SortedTrovesAddressChanged(address _sortedDoublyLLAddress);
    event TroveManagerAddressChanged(address _troveManagerAddress);

    function NAME() external view returns (string memory);

    function borrowerOperationsAddress() external view returns (address);

    function contains(address _id) external view returns (bool);

    function data()
        external
        view
        returns (
            address head,
            address tail,
            uint256 maxSize,
            uint256 size
        );

    function findInsertPosition(
        uint256 _NICR,
        address _prevId,
        address _nextId
    ) external view returns (address, address);

    function getFirst() external view returns (address);

    function getLast() external view returns (address);

    function getMaxSize() external view returns (uint256);

    function getNext(address _id) external view returns (address);

    function getPrev(address _id) external view returns (address);

    function getSize() external view returns (uint256);

    function insert(
        address _id,
        uint256 _NICR,
        address _prevId,
        address _nextId
    ) external;

    function isEmpty() external view returns (bool);

    function isFull() external view returns (bool);

    function isOwner() external view returns (bool);

    function owner() external view returns (address);

    function reInsert(
        address _id,
        uint256 _newNICR,
        address _prevId,
        address _nextId
    ) external;

    function remove(address _id) external;

    function setParams(
        uint256 _size,
        address _troveManagerAddress,
        address _borrowerOperationsAddress
    ) external;

    function troveManager() external view returns (address);

    function validInsertPosition(
        uint256 _NICR,
        address _prevId,
        address _nextId
    ) external view returns (bool);
}

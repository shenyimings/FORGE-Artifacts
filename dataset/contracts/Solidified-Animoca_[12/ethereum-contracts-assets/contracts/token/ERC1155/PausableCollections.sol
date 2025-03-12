// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6 <0.8.0;

abstract contract PausableCollections {
    event CollectionsPaused(uint256[] collectionIds, address pauser);
    event CollectionsUnpaused(uint256[] collectionIds, address pauser);

    mapping(uint256 => bool) internal _pausedCollections;

    modifier whenIdPaused(uint256 id) {
        require(_idPaused(id), "Collections: id is not paused");
        _;
    }

    modifier whenIdNotPaused(uint256 id) {
        require(!_idPaused(id), "Collections: id is paused");
        _;
    }

    /////////////////////////////////////////// Internal Functions ///////////////////////////////////////

    function _idPaused(uint256 id) internal view virtual returns (bool);

    function _isCollectionId(uint256 id) internal view virtual returns (bool);

    function _pauseCollection(uint256 collectionId) internal virtual {
        require(!_idPaused(collectionId), "Collections: already paused");
        require(_isCollectionId(collectionId), "Collections: not a collection");
        _pausedCollections[collectionId] = true;
    }

    function _unpauseCollection(uint256 collectionId) internal virtual {
        require(_idPaused(collectionId), "Collections: not paused");
        require(_isCollectionId(collectionId), "Collections: not a collection");
        _pausedCollections[collectionId] = false;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract AssetUpperBound is Ownable {
    event UpperBoundSet(uint256 indexed assetID,  uint256 upperBound);

    // asset => upper bound
    mapping(uint256 => uint256) private _upperBounds;

    function setUpperBound(uint256 _assetID, uint256 _upperBound) public onlyOwner {
        _upperBounds[_assetID] = _upperBound;

        emit UpperBoundSet(_assetID, _upperBound);
    }

    function getUpperBound(uint256 _assetID) public view returns (uint256) {
        return _upperBounds[_assetID];
    }
}

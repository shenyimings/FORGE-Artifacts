// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract Entities is Ownable {

    using SafeMath for uint256;
    address[] _entities;
    mapping (address => uint256) _entityPercentage;
    uint256 _totalPercentage;

    event AddEntity(address entity, uint256 percent);
    event UpdateEntity(address entity, uint256 percent);
    event RemoveEntity(address entity);

    event DistributeNative(address entity, uint256 amount);
    event DistributeToken(address indexed token, address entity, uint256 amount);

    constructor() {}

    // ---------------- only owner can call (after deploy transfer to multisign account) ------------------------

    function addEntity(address entityAddress, uint256 percent) external onlyOwner {
        _entities.push(entityAddress); 
        _entityPercentage[entityAddress] = percent;
        _calculateTotalPercentage();
        emit AddEntity(entityAddress, percent);
    }

    function updateEntity(address entityAddress, uint256 percent) external onlyOwner {
        _entityPercentage[entityAddress] = percent;
        _calculateTotalPercentage();
        emit UpdateEntity(entityAddress, percent);
    }

    function removeEntity(address entityAddress) external onlyOwner {
        delete(_entityPercentage[entityAddress]);
        address[] memory currentEntities = _entities;
        delete _entities;
        for(uint256 index = 0; index < currentEntities.length; index++) {
            if ( _entityPercentage[currentEntities[index]] > 0 ) {
                _entities.push(currentEntities[index]);
            }
        }
        _calculateTotalPercentage();
        emit RemoveEntity(entityAddress);
    }

    function listEntity() external view returns ( address[] memory entities) {
        return _entities;
    }

    // ------------------------------- only insider can call -----------------------------------------------------------

    function getPercentage(address entityAddress) external view returns ( uint256 allocation, uint256 total) {
        return (_entityPercentage[entityAddress], _totalPercentage);
    }

    // ------------------------------- private function -----------------------------------------------------------
    function _calculateTotalPercentage() internal {
        _totalPercentage = 0;
        for (uint256 idx = 0; idx < _entities.length; idx++) {
            _totalPercentage = _totalPercentage.add(_entityPercentage[_entities[idx]]);
        }
    }

}
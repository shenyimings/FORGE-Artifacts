pragma solidity 0.4.25;

import "../Common/Upgradable.sol";
import "./EggStorage.sol";

contract EggCore is Upgradable {
    EggStorage _storage_;

    function getAmount() external view returns (uint256) {
        return _storage_.totalSupply();
    }

    function getAllEggs() external view returns (uint256[]) {
        return _storage_.getAllTokens();
    }

    function isOwner(address _user, uint256 _tokenId) external view returns (bool) {
        return _user == _storage_.ownerOf(_tokenId);
    }

    function ownerOf(uint256 _tokenId) external view returns (address) {
        return _storage_.ownerOf(_tokenId);
    }

    function create(
        address _sender,
        uint256[2] _parents,
        uint8 _dragonType
    ) external onlyController returns (uint256) {
        return _storage_.push(_sender, _parents, _dragonType);
    }

    function remove(address _owner, uint256 _id) external onlyController {
        _storage_.remove(_owner, _id);
    }

    function get(uint256 _id) external view returns (uint256[2], uint8) {
        require(_storage_.exists(_id), "egg doesn't exist");
        return _storage_.get(_id);
    }

    function setInternalDependencies(address[] _newDependencies) public onlyOwner {
        super.setInternalDependencies(_newDependencies);

        _storage_ = EggStorage(_newDependencies[0]);
    }
}

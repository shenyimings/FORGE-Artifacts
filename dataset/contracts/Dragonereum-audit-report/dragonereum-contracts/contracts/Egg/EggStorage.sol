pragma solidity 0.4.25;

import "../Common/ERC721/ERC721Token.sol";

contract EggStorage is ERC721Token {
    struct Egg {
        uint256[2] parents;
        uint8 dragonType; // used for genesis only
    }

    Egg[] eggs;

    constructor(string _name, string _symbol) public ERC721Token(_name, _symbol) {
        eggs.length = 1; // to avoid some issues with 0
    }

    function push(address _sender, uint256[2] _parents, uint8 _dragonType) public onlyController returns (uint256 id) {
        Egg memory _egg = Egg(_parents, _dragonType);
        id = eggs.push(_egg).sub(1);
        _mint(_sender, id);
    }

    function get(uint256 _id) external view returns (uint256[2], uint8) {
        return (eggs[_id].parents, eggs[_id].dragonType);
    }

    function remove(address _owner, uint256 _id) external onlyController {
        delete eggs[_id];
        _burn(_owner, _id);
    }
}

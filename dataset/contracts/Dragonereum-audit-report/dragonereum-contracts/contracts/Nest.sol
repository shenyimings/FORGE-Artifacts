pragma solidity 0.4.25;

import "./Common/Upgradable.sol";
import "./Common/Random.sol";
import "./Common/SafeMath8.sol";
import "./Common/SafeMath256.sol";


contract Nest is Upgradable {
    using SafeMath8 for uint8;
    using SafeMath256 for uint256;

    Random random;

    uint256[2] eggs;
    uint256 lastBlockNumber;

    bool isFull;

    mapping (uint256 => bool) public inNest;

    function add(
        uint256 _id
    ) external onlyController returns (
        bool isHatched,
        uint256 hatchedId,
        uint256 randomForEggOpening
    ) {
        require(!inNest[_id], "egg is already in nest");
        require(block.number > lastBlockNumber, "only 1 egg in a block");

        lastBlockNumber = block.number;
        inNest[_id] = true;

        // if amount of egg = 3, then hatch one
        if (isFull) {
            isHatched = true;
            hatchedId = eggs[0];
            randomForEggOpening = random.random(2**256 - 1);
            eggs[0] = eggs[1];
            eggs[1] = _id;
            delete inNest[hatchedId];
        } else {
            uint8 _index = eggs[0] == 0 ? 0 : 1;
            eggs[_index] = _id;
            if (_index == 1) {
                isFull = true;
            }
        }
    }

    // GETTERS

    function getEggs() external view returns (uint256[2]) {
        return eggs;
    }

    // UPDATE CONTRACT

    function setInternalDependencies(address[] _newDependencies) public onlyOwner {
        super.setInternalDependencies(_newDependencies);

        random = Random(_newDependencies[0]);
    }
}

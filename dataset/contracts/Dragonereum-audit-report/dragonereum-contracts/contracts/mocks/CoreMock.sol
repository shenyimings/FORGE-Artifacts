pragma solidity 0.4.25;


import "../Core.sol";

contract CoreMock is Core {
    function _openEgg(
        address _owner,
        uint256 _eggId,
        uint256 _random
    ) public returns (uint256 newDragonId) {
        return openEgg(_owner, _eggId, _random);
    }
}

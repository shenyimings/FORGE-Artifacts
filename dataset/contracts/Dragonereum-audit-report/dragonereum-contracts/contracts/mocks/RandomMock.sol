pragma solidity 0.4.25;

import "../Common/Random.sol";

contract RandomMock is Random {
    
    function getRandom(
        uint256 _upper,
        uint256 _blockNumber
    ) internal view validBlock(_blockNumber) returns (uint256) {
        bytes32 _hash = keccak256(abi.encodePacked("31337"));
        return uint256(_hash) % _upper;
    }
}

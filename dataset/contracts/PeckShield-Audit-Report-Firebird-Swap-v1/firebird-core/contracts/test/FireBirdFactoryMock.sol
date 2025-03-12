pragma solidity 0.7.6;


import "../interfaces/IIsPair.sol";

contract FireBirdFactoryMock is IIsPair {
    mapping(address => bool) public override isPair;

    function setIsPair(address pair, bool val) external {
        isPair[pair] = val;
    }

}

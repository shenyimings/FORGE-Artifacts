pragma solidity ^0.6.0;

import "../handlers/HandlerBase.sol";

interface IFoo {
    function bar(uint256 a) external returns (uint256 result);
}

interface IFooFactory {
    function addressOf(uint256 index) external view returns (address result);

    function createFoo() external;
}

contract FooHandler is HandlerBase {
    function getContractName() public pure override returns (string memory) {
        return "Foo2Handler";
    }

    function getFooFactory() public pure returns (address target) {
        return 0xFdd454EA7BF7ca88C1B7a824c3FB0951Fb8a1318;
    }

    function getFoo(uint256 index) public view returns (address target) {
        return IFooFactory(getFooFactory()).addressOf(index);
    }

    function bar(uint256 index, uint256 a) public returns (uint256 result) {
        address target = getFoo(index);
        return IFoo(target).bar(a);
    }
}

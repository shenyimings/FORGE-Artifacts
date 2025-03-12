pragma solidity ^0.6.0;

import "../handlers/HandlerBase.sol";

interface IFoo2 {
    function bar() external payable returns (uint256 result);
}

interface IFoo2Factory {
    function addressOf(uint256 index) external view returns (address result);

    function createFoo() external;
}

contract Foo2Handler is HandlerBase {
    function getContractName() public pure override returns (string memory) {
        return "Foo2Handler";
    }

    function getFooFactory() public pure returns (address target) {
        return 0xaB7D1E16d471065629431aeABED38880170876f2;
    }

    function getFoo(uint256 index) public view returns (address target) {
        return IFoo2Factory(getFooFactory()).addressOf(index);
    }

    function bar(uint256 value, uint256 index)
        public
        payable
        returns (uint256 result)
    {
        address target = getFoo(index);
        _updateToken(target);
        return IFoo2(target).bar{value: value}();
    }
}

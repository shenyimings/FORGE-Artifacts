//SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.17;

contract Ownable {
    address public owner;
    address internal newOwner;

    //transfer the owner
    function transferOwner(address _owner) external {
        require(msg.sender == owner, "forbidden");
        newOwner = _owner;
    }

    //accept the owner
    function acceptSetter() external {
        require(msg.sender == newOwner, "forbidden");
        owner = newOwner;
        newOwner = address(0);
    }
}

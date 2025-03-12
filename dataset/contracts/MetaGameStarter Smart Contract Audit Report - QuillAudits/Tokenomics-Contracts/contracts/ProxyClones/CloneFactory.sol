pragma solidity ^0.8.0; 

import "@openzeppelin/contracts/proxy/Clones.sol";


contract CloneFactory {
    using Clones for address;

    function clone(address prototype, bytes calldata initData) external payable {
        address cloneContract = prototype.clone();
        (bool success,) = cloneContract.call{ value: msg.value }(initData);
        require(success, "initiation failed");
        emit CloneCreated(prototype, cloneContract);
    }

    event CloneCreated(address indexed prototype, address indexed cloneAddress);
}
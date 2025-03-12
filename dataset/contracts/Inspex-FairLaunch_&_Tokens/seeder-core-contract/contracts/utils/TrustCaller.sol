// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";


abstract contract TrustCaller is Ownable {
    event TrustCallerSet(address caller, bool isTrusted);

    mapping(address => bool) private _trustCallers;

    constructor() {
    }

    function isTrustCaller(address contractAddress) external view returns (bool) {
        return _trustCallers[contractAddress];
    }

    function setTrustCaller(address callerAddress, bool isTrusted) external onlyOwner {
        _trustCallers[callerAddress] = isTrusted;

        emit TrustCallerSet(callerAddress, isTrusted);
    }

    modifier onlyTrustCaller() {
        require(_trustCallers[msg.sender], "Caller is not trust");
        _;
    }
}
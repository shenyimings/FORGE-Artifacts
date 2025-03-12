// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "../Dependencies/IERC20.sol";
import "../Dependencies/Ownable.sol";
import "../Dependencies/SafeMath.sol";
import "../Interfaces/ICommunityIssuance.sol";


contract LQTYTreasury is Ownable {
    using SafeMath for uint;

    string constant public NAME = "LQTYTreasury";

    uint public issuanceStartTime;
    uint public totalSupplyCap;
    IERC20 public token;
    address[] public issuers;

    constructor(uint _issuanceStartTime) public {
        if (_issuanceStartTime == 0) _issuanceStartTime = block.timestamp;
        issuanceStartTime = _issuanceStartTime;
    }

    function setAddresses(IERC20 _token, address[] memory _issuers) external onlyOwner {
        token = _token;

        for (uint i = 0; i < _issuers.length; i++) {
            issuers.push(_issuers[i]);
            uint supplyCap = ICommunityIssuance(_issuers[i]).LQTYSupplyCap();
            _token.approve(_issuers[i], supplyCap);
            totalSupplyCap = totalSupplyCap.add(supplyCap);
        }

        _renounceOwnership();
    }

}

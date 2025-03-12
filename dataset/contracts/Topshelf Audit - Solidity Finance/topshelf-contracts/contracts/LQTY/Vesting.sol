// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "../Dependencies/SafeMath.sol";
import "../Interfaces/ICommunityIssuance.sol";

contract Vesting {
    using SafeMath for uint;

    ICommunityIssuance public immutable issuer;
    uint public immutable supplyCap;
    uint public availableSupply;
    uint public totalAllocPoints;

    mapping (address => uint) public allocPoints;
    mapping (address => uint) public claimed;

    constructor(ICommunityIssuance _issuer, address[] memory _receivers, uint[] memory _allocPoints) public {
        issuer = _issuer;
        supplyCap = _issuer.LQTYSupplyCap();
        for (uint i = 0; i < _receivers.length; i++) {
            require(allocPoints[_receivers[i]] == 0);
            allocPoints[_receivers[i]] = _allocPoints[i];
            totalAllocPoints = totalAllocPoints.add(_allocPoints[i]);
        }
    }

    function updateAvailableSupply() public {
        availableSupply = availableSupply.add(issuer.issueLQTY());
    }

    function claimable(address user) public view returns (uint256) {
        uint ap = allocPoints[user];
        uint claimable = availableSupply.mul(ap).div(totalAllocPoints);
        return claimable;
    }

    function claim(address receiver, uint amount) public {
        updateAvailableSupply();
        uint claimable = claimable(msg.sender);
        require(claimable > 0, "Nothing claimable");
        if (amount == 0) {
            amount = claimable.sub(claimed[msg.sender]);
        } else {
            require(claimable.sub(claimed[msg.sender]) >= amount);
        }
        claimed[msg.sender] = claimed[msg.sender].add(amount);
        issuer.sendLQTY(receiver, amount);
    }

}

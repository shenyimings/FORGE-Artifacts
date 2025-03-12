// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract OwnedUpgradeable is Initializable {
    event CandidateOwnerNominated(address candidate);
    event OwnershipTransferred(address owner);

    address public owner;
    address public candidateOwner;

    modifier onlyOwner {
        require(msg.sender == owner, "caller is not the owner");
        _;
    }

    function __Owned_init() internal onlyInitializing {
        owner = msg.sender;
        emit OwnershipTransferred(msg.sender);
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        require(_newOwner != address(0), "invalid owner address");
        candidateOwner = _newOwner;
        emit CandidateOwnerNominated(_newOwner);
    }

    function acceptOwnership() public {
        require(msg.sender == candidateOwner, "not candidate owner");
        owner = msg.sender;
        candidateOwner = address(0);
        emit OwnershipTransferred(msg.sender);
    }
}

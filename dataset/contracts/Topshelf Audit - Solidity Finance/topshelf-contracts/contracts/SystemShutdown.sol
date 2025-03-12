// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "./Dependencies/Ownable.sol";
import "./Interfaces/ICommunityIssuance.sol";
import "./Interfaces/ILUSDToken.sol";

contract SystemShutdown is Ownable {

    struct Contracts {
        ILUSDToken synth;
        ICommunityIssuance issuer;
    }

    Contracts[] public registeredContracts;

    event ContractsRegistered(
        ILUSDToken synth,
        ICommunityIssuance issuer,
        uint id
    );

    function registerContracts(ILUSDToken _synth, ICommunityIssuance _issuer) external onlyOwner {
        require(_synth.shutdownAdmin() == address(this));
        require(_issuer.shutdownAdmin() == address(this));
        registeredContracts.push(Contracts({synth: _synth, issuer: _issuer}));
        emit ContractsRegistered(_synth, _issuer, registeredContracts.length - 1);
    }

    function pause(uint _id) external onlyOwner {
        registeredContracts[_id].synth.setPaused(true);
        registeredContracts[_id].issuer.setPaused(true);
    }

    function unpause(uint _id) external onlyOwner {
        registeredContracts[_id].synth.setPaused(false);
        registeredContracts[_id].issuer.setPaused(false);
    }

}

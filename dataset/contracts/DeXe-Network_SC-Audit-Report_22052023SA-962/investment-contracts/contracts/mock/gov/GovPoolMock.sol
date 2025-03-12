// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract GovPoolMock {
    uint256 public userActiveProposalsCount;
    address internal _votePowerContract;

    function getUserActiveProposalsCount(address) external view returns (uint256) {
        return userActiveProposalsCount;
    }

    function setUserActiveProposalsCount(uint256 _userActiveProposalsCount) external {
        userActiveProposalsCount = _userActiveProposalsCount;
    }

    function setVotePowerContract(address votePowerContract) external {
        _votePowerContract = votePowerContract;
    }

    function getHelperContracts()
        external
        view
        returns (
            address settings,
            address userKeeper,
            address validators,
            address poolRegistry,
            address votePower
        )
    {
        return (address(0), address(0), address(0), address(0), _votePowerContract);
    }
}

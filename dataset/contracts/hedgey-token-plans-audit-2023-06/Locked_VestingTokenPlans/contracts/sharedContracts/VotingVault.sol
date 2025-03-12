// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import '../libraries/TransferHelper.sol';

interface IGovernanceToken {
    function delegate(address delegatee) external;
    function delegates(address wallet) external view returns (address delegate);
}

contract VotingVault {

    address public token;
    address public controller;

    constructor(address _token, address beneficiary) {
        controller = msg.sender;
        token = _token;
        address existingDelegate = IGovernanceToken(token).delegates(beneficiary);
        if(existingDelegate != address(0)) IGovernanceToken(token).delegate(existingDelegate);
        else IGovernanceToken(token).delegate(beneficiary);
    }

    modifier onlyController() {
        require(msg.sender == controller);
        _;
    }

    function delegateTokens(address delegatee) external onlyController {
        uint256 balanceCheck = IERC20(token).balanceOf(address(this));
        IGovernanceToken(token).delegate(delegatee);
        // check to make sure delegate function is not malicious
        require(balanceCheck == IERC20(token).balanceOf(address(this)), 'balance error');
    }

    function withdrawTokens(address to, uint256 amount) external onlyController {
        TransferHelper.withdrawTokens(token, to, amount);
        if (IERC20(token).balanceOf(address(this)) == 0) selfdestruct;
    }

}
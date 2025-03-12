// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./IMSSpaceToken.sol";

contract MSSpaceToken is IMSSpaceToken, ERC20, AccessControl {

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    constructor (string memory _name, string memory _symbol) 
                ERC20(_name, _symbol)
    {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function msIsApprove(address owner, address spender) override external view returns(bool)
    {
        return allowance(owner, spender) > 0;
    }
    
    function msMint(address recipient, uint256 amount) override  external returns (bool)
    {
        require(hasRole(OPERATOR_ROLE, _msgSender()), "Caller is not a operator");
        _mint(recipient, amount);
        return true;
    }
    
    function msBurn(address _who,uint256 _amount) override external {
        require(hasRole(OPERATOR_ROLE, _msgSender()), "Caller is not a operator");
        _burn(_who, _amount);
    }

    function msGetBalanceOf(address ofuser_) override view external returns(uint256){
        return balanceOf(ofuser_);
    }

    function msTransfer(address recipient, uint256 amount) override external returns (bool){
        return transfer(recipient, amount);
    }

    function msTransferFrom(address sender,address recipient, uint256 amount) override external returns (bool){
        return transferFrom(sender, recipient, amount);
    }
}

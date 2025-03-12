//SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import "../../pause/interfaces/IPauseable.sol";
import "../../blacklist/interfaces/IBlacklist.sol";
import "../../committee/interfaces/IKAP20Committee.sol";
import "../../kyc/interfaces/IKAP20KYC.sol";

interface IKAP20 is IPauseable, IBlacklist, IKAP20Committee, IKAP20KYC {
    event Transfer(address indexed from, address indexed to, uint256 tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint256 tokens);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);
    
    function balanceOf(address tokenOwner) external view returns (uint256 balance);

    function allowance(address tokenOwner, address spender) external view returns (uint256 remaining);

    function transfer(address to, uint256 tokens) external returns (bool success);

    function approve(address spender, uint256 tokens) external returns (bool success);

    function transferFrom(address from, address to, uint256 tokens) external returns (bool success);
    
    function adminTransfer(address _from, address _to, uint256 _value) external returns (bool success);
    
}
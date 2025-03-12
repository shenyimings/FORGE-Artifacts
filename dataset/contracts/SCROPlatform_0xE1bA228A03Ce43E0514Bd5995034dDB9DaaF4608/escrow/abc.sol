//SPDX-License-Identifier:UNLICENSED
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract abc{

    mapping(address => bool) public isAdmin;

    address public ownerAddress;
    address internal originalOwnerAddress;
    address internal creatorAddress;

    mapping(address => mapping(uint256 => uint256)) public signatures;
    // signatures[address][processID]=sha1hash

    modifier adminOnly{
        require(isAdmin[msg.sender]);
        _;
    }

    modifier ownerOnly{
        require(msg.sender==ownerAddress);
        _;
    }

    function setOriginalOwner(address _ownerAddress) internal { // call in constructor
        creatorAddress=msg.sender;
        isAdmin[msg.sender]=true;
        
        ownerAddress=_ownerAddress;
        originalOwnerAddress=_ownerAddress;
        isAdmin[ownerAddress]=true;
    }

    function makeAdmin(address _newAdminAddress) external adminOnly {
        isAdmin[_newAdminAddress]=true;
    }

    function removeAdmin(address _admin) external ownerOnly {
        isAdmin[_admin]=false;
    }

    function transferOwnership(address _newOwnerAddress) external ownerOnly {
        ownerAddress=_newOwnerAddress;
    }

    function signProcess(uint256 _processID,uint256 _sha1) external {
        signatures[msg.sender][_processID]=_sha1;
    }
}

library math{
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
      assert(b <= a);
      return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
      uint256 c = a + b;
      assert(c >= a);
      return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if(a==0){
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0);
        uint256 c = a / b;
        return c;
    }
}
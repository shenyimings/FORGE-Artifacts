// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


contract AirdropBoost {

    using SafeERC20 for IERC20;

    address public owner;
    address public ve;
    IERC20 public token;

    mapping (address => bool) depositors;

    modifier onlyOwner {
        require(msg.sender == owner, 'not owner');
        _;
    }

    event Deposit(uint256 amount);
    event Withdraw(uint256 amount);

    constructor(address _token, address _ve) {
        owner = msg.sender;
        token = IERC20(_token);
        ve = _ve;
    }

    /* 
        OWNER FUNCTIONS
    */

    function setDepositor(address depositor, bool _status) external onlyOwner {
        require(depositors[depositor] == !_status);
        depositors[depositor] = _status;
    }

    function setOwner(address _owner) external onlyOwner{
        require(_owner != address(0));
        owner = _owner;
    }

    /// @notice set the veCHR address
    function setVe(address _ve) external onlyOwner{
        require(_ve != address(0));
        ve = _ve;
    }


    function deposit(uint256 amount) external {
        require(depositors[msg.sender] == true || msg.sender == owner);
        token.safeTransferFrom(msg.sender, address(this), amount);
        token.approve(ve, 0);
        token.approve(ve, token.balanceOf(address(this)));
        
        emit Deposit(amount);
    }
    
    function withdraw(uint256 amount) external {
        require(msg.sender == owner);
        uint available = token.balanceOf(address(this));
        require(available >= amount, "Not enough balance in this wallet");
        token.safeTransfer(msg.sender, amount);
        token.approve(ve, 0);
        token.approve(ve, token.balanceOf(address(this)));
        
        emit Withdraw(amount);
    }



    
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DuneLocker is Ownable{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    
    struct Items {
        IERC20 token;
        address withdrawer;
        uint256 amount;
        uint256 unlockTimestamp;
        bool withdrawn;
    }
    
    uint256 public depositsCount;
    mapping (address => uint256[]) private depositsByTokenAddress;
    mapping (address => uint256[]) public depositsByWithdrawer;
    mapping (uint256 => Items) public lockedToken;
    mapping (address => mapping(address => uint256)) public walletTokenBalance;
    
    uint256 public lockFee = 0.1 ether;
    address public feeAddress;
    
    event Withdraw(address withdrawer, uint256 amount);
    event Lock(address token, uint256 amount, uint256 id);
    
    constructor() {
        feeAddress = msg.sender;
    }
    
    function lockTokens(IERC20 _token, address _withdrawer, uint256 _amount, uint256 _unlockTimestamp) payable external returns (uint256 _id) {
        require(_amount > 0, 'Token amount too low!');
        require(_unlockTimestamp < 10000000000, 'Unlock timestamp is not in seconds!');
        require(_unlockTimestamp > block.timestamp, 'Unlock timestamp is not in the future!');
        require(_token.allowance(msg.sender, address(this)) >= _amount, 'Approve tokens first!');
        require(msg.value >= lockFee, 'Need to pay lock fee!');

        uint256 beforeDeposit = _token.balanceOf(address(this));
        _token.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 afterDeposit = _token.balanceOf(address(this));
        
        _amount = afterDeposit.sub(beforeDeposit); 

        payable(feeAddress).transfer(msg.value);
                
        walletTokenBalance[address(_token)][_withdrawer] = walletTokenBalance[address(_token)][_withdrawer].add(_amount);
        
        _id = ++depositsCount;
        lockedToken[_id].token = _token;
        lockedToken[_id].withdrawer = _withdrawer;
        lockedToken[_id].amount = _amount;
        lockedToken[_id].unlockTimestamp = _unlockTimestamp;
        lockedToken[_id].withdrawn = false;

        depositsByTokenAddress[address(_token)].push(_id);
        depositsByWithdrawer[_withdrawer].push(_id);

        emit Lock(address(_token), _amount, _id);
        
        return _id;
    }
        
    function withdrawTokens(uint256 _id) external {
        require(block.timestamp >= lockedToken[_id].unlockTimestamp, 'Tokens are still locked!');
        require(msg.sender == lockedToken[_id].withdrawer, 'You are not the withdrawer!');
        require(!lockedToken[_id].withdrawn, 'Tokens are already withdrawn!');
        
        lockedToken[_id].withdrawn = true;
        
        walletTokenBalance[address(lockedToken[_id].token)][msg.sender] = walletTokenBalance[address(lockedToken[_id].token)][msg.sender].sub(lockedToken[_id].amount);
        
        emit Withdraw(msg.sender, lockedToken[_id].amount);
        lockedToken[_id].token.safeTransfer(msg.sender, lockedToken[_id].amount);
    }
    
    function setFeeAddress(address _feeAddress) external onlyOwner {
        feeAddress = _feeAddress;
    }
    
    function setLockFee(uint256 _lockFee) external onlyOwner {
        lockFee = _lockFee;
    }
    
    function getDepositsByTokenAddress(address _token) view external returns (uint256[] memory) {
        return depositsByTokenAddress[_token];
    }
    
    function getDepositsByWithdrawer(address _withdrawer) view external returns (uint256[] memory) {
        return depositsByWithdrawer[_withdrawer];
    }
    
    
    function getTokenTotalLockedBalance(address _token) view external returns (uint256) {
       return IERC20(_token).balanceOf(address(this));
    }
}
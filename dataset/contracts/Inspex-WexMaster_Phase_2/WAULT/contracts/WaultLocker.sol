// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.4/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.4/contracts/token/ERC20/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.4/contracts/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.4/contracts/access/Ownable.sol";

contract WaultLocker is Ownable{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    
    struct Items {
        IERC20 token;
        address withdrawer;
        uint256 amount;
        uint256 unlockTimestamp;
        bool withdrawn;
        uint256 taxPermille;
        bool isCustom;
        bool deposited;
    }
    
    uint256 public depositsCount;
    mapping (address => uint256[]) public depositsByTokenAddress;
    mapping (uint256 => Items) public lockedToken;
    mapping (address => mapping(address => uint256)) public walletTokenBalance;
    
    uint256 public taxPermille = 2;
    address public waultMarkingAddress;
    
    event Withdraw(address withdrawer, uint256 amount);
    
    constructor(address _waultMarkingAddress) {
        waultMarkingAddress = _waultMarkingAddress;
    }
    
    function lockTokens(IERC20 _token, address _withdrawer, uint256 _amount, uint256 _unlockTimestamp) external returns (uint256 _id) {
        require(_amount > 500, 'Token amount too low!');
        require(_unlockTimestamp < 10000000000, 'Unlock timestamp is not in seconds!');
        require(_unlockTimestamp > block.timestamp, 'Unlock timestamp is not in the future!');
        require(_token.allowance(msg.sender, address(this)) >= _amount, 'Approve tokens first!');
        _token.safeTransferFrom(msg.sender, address(this), _amount);
        
        uint256 tax = _amount.mul(taxPermille).div(1000);
        _token.safeTransfer(waultMarkingAddress, tax);
        
        walletTokenBalance[address(_token)][msg.sender] = walletTokenBalance[address(_token)][msg.sender].add(_amount.sub(tax));
        
        _id = ++depositsCount;
        lockedToken[_id].token = _token;
        lockedToken[_id].withdrawer = _withdrawer;
        lockedToken[_id].amount = _amount.sub(tax);
        lockedToken[_id].unlockTimestamp = _unlockTimestamp;
        lockedToken[_id].withdrawn = false;
        lockedToken[_id].taxPermille = taxPermille;
        lockedToken[_id].isCustom = false;
        lockedToken[_id].deposited = true;
        
        depositsByTokenAddress[address(_token)].push(_id);
    }
    
    function addCustomLock(IERC20 _token, address _withdrawer, uint256 _amount, uint256 _unlockTimestamp, uint256 _taxPermille) external onlyOwner returns (uint256 _id) {
        require(_amount > 500, 'Token amount too low!');
        require(_unlockTimestamp < 10000000000, 'Unlock timestamp is not in seconds!');
        require(_unlockTimestamp > block.timestamp, 'Unlock timestamp is not in the future!');
        
        _id = ++depositsCount;
        lockedToken[_id].token = _token;
        lockedToken[_id].withdrawer = _withdrawer;
        lockedToken[_id].amount = _amount;
        lockedToken[_id].unlockTimestamp = _unlockTimestamp;
        lockedToken[_id].withdrawn = false;
        lockedToken[_id].taxPermille = _taxPermille;
        lockedToken[_id].isCustom = true;
        lockedToken[_id].deposited = false;
    }
    
    function customLockTokens(uint256 _id) external {
        require(lockedToken[_id].isCustom, 'This is not a custom lock!');
        require(!lockedToken[_id].deposited, 'Tokens already locked!');
        require(msg.sender == lockedToken[_id].withdrawer, 'You are not the withdrawer!');
        require(lockedToken[_id].token.allowance(msg.sender, address(this)) >= lockedToken[_id].amount, 'Approve tokens first!');
        lockedToken[_id].token.safeTransferFrom(msg.sender, address(this), lockedToken[_id].amount);
        
        uint256 tax = lockedToken[_id].amount.mul(lockedToken[_id].taxPermille).div(1000);
        lockedToken[_id].token.safeTransfer(waultMarkingAddress, tax);
        
        walletTokenBalance[address(lockedToken[_id].token)][msg.sender] = walletTokenBalance[address(lockedToken[_id].token)][msg.sender].add(lockedToken[_id].amount.sub(tax));
        
        lockedToken[_id].amount = lockedToken[_id].amount.sub(tax);
        lockedToken[_id].deposited = true;
        
        depositsByTokenAddress[address(lockedToken[_id].token)].push(_id);
    }
    
    function withdrawTokens(uint256 _id) external {
        require(block.timestamp >= lockedToken[_id].unlockTimestamp, 'Tokens are still locked!');
        require(msg.sender == lockedToken[_id].withdrawer, 'You are not the withdrawer!');
        require(lockedToken[_id].deposited, 'Tokens are not yet deposited!');
        require(!lockedToken[_id].withdrawn, 'Tokens are already withdrawn!');
        
        lockedToken[_id].withdrawn = true;
        
        walletTokenBalance[address(lockedToken[_id].token)][msg.sender] = walletTokenBalance[address(lockedToken[_id].token)][msg.sender].sub(lockedToken[_id].amount);
        
        emit Withdraw(msg.sender, lockedToken[_id].amount);
        lockedToken[_id].token.safeTransfer(msg.sender, lockedToken[_id].amount);
    }
    
    function setWaultMarkingAddress(address _waultMarkingAddress) external onlyOwner {
        waultMarkingAddress = _waultMarkingAddress;
    }
    
    function getDepositsByTokenAddress(address _token) view external returns (uint256[] memory) {
        return depositsByTokenAddress[_token];
    }
    
    function getTokenTotalLockedBalance(address _token) view external returns (uint256) {
       return IERC20(_token).balanceOf(address(this));
    }
}

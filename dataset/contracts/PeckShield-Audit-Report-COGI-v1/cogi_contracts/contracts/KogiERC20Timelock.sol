// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./common/interfaces/IERC20Mintable.sol";

/**
 * @title KOGI ERC20 Time Lock
 * @author KOGI Inc
 */
contract KogiERC20Timelock is
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    event onDeposit(
        address indexed sender,
        uint256 amount,
        uint256 now
    );

    event onWithdraw(
        address indexed sender,
        uint256 amount,
        uint256 now
    );

    IERC20Mintable public token;
    mapping (address => uint256) public balances;
    uint256 public lockEnd;

    function initialize(
        address _tokenAddress,
        uint _lockDays
    ) external initializer {
        __Ownable_init();
        token = IERC20Mintable(_tokenAddress);
        lockEnd = _now() + _lockDays * 1 days;
    }

    //internal view
    function _now() internal view returns (uint256) {
        return block.timestamp;
    }

    function _deposit(address _sender, uint256 _amount) internal nonReentrant {
        require(_amount > 0, "deposit amount should be more than 0");
        require(token.transferFrom(_sender, address(this), _amount), "transfer failed");  
        balances[_sender] = balances[_sender] + _amount;
        emit onDeposit(_sender, _amount, _now());
    }

    function _withdraw(address _sender, uint256 _amount) internal nonReentrant {    
        require(_amount > 0, "withdraw amount should be more than 0");
        require(_now() >= lockEnd, "too early");
        require(_amount <= balances[_sender], "withdraw amount not enough");
        require(token.transferFrom(address(this), _sender, _amount), "transfer failed");
        balances[_sender] = balances[_sender] - _amount;
        emit onWithdraw(_sender, _amount, _now());
    }

    //owner view
    function depositFrom(address _from, uint256 _amount) public onlyOwner() {
        _deposit(_from, _amount);
    }

    function withdrawFrom(address _from, uint256 _amount) public onlyOwner() {
        _withdraw(_from, _amount);
    }

    //anon view
    function deposit(uint256 _amount) public {
        _deposit(_msgSender(), _amount);
    }

    function withdraw(uint256 _amount) public {
        _deposit(_msgSender(), _amount);
    }
    
    function balanceOf(address _sender) public view returns (uint256){
        require(balances[_sender] >= 0, "too early");
        return balances[_sender];
    }

    function getEstimateLocked() public view returns (uint256){
        uint256 ret = lockEnd - _now();
        if(ret < 0) ret = 0;
        return ret;
    }
}

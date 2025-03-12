// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../interface/IMintBurn.sol";
import "../lib/SafeDecimalMath.sol";
import "../interface/ITunnel.sol";

contract MigratePool is Ownable, Pausable{

    using SafeMath for uint;
    using SafeDecimalMath for uint;
    using SafeERC20 for IERC20;

    mapping(address => uint256) public balanceOf;
    IERC20 public depositToken;
    address public withdrawToken;
    uint public feeRate;
    uint public decimalDiff;
    ITunnel public tunnel;
    uint public conversionRatio=1e18;
    
    constructor(address _depositToken, address _withdrawToken, uint _feeRate, uint _decimalDiff, address _tunnel) public {
        depositToken = IERC20(_depositToken);
        withdrawToken = _withdrawToken;
        feeRate = _feeRate;
        decimalDiff = 10 ** _decimalDiff;
        tunnel = ITunnel(_tunnel);
    }

    function deposit(uint amount) public whenNotPaused{
        uint issueAmount = amount.mul(decimalDiff).multiplyDecimal(feeRate).multiplyDecimal(conversionRatio);
        // pledge ratio require
        require(IERC20(withdrawToken).totalSupply().add(issueAmount) <= tunnel.canIssueAmount(), "MigratePool::deposit:NotEnoughPledgeValue");
        balanceOf[msg.sender] = balanceOf[msg.sender].add(amount); 
        depositToken.safeTransferFrom(msg.sender, address(this), amount);
        IMintBurn(withdrawToken).mint(msg.sender, issueAmount);
        emit MigrateToken(msg.sender, amount, issueAmount, feeRate);
    }

    function canDeposit(uint amount) public view returns(bool) {
        uint issueAmount = amount.mul(decimalDiff).multiplyDecimal(feeRate).multiplyDecimal(conversionRatio);
        if(IERC20(withdrawToken).totalSupply().add(issueAmount) <= tunnel.canIssueAmount()) {
            return true;
        } else {
            return false;
        }
    }

    function modifyFeeRate(uint _feeRate) public onlyOwner {
        feeRate = _feeRate;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function setConversionRatio(uint _ratio) public onlyOwner {
        conversionRatio = _ratio;
    }

    event MigrateToken(address user, uint amount, uint issueAmount, uint feeRate);
}
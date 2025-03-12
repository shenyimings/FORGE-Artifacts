//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VonderGameExchange is Ownable {
    using SafeMath for uint256;

    address public treasury;
    address public feeAddress;
    address public feeTokenAddress;
    uint256 public feeTokenAmount;

    uint256 public denominator = 100;

    struct TokenRate {
        address tokenAddress;
        uint256 balance;
        uint256 bonus;
    }

    mapping(address => TokenRate) private tokenRates;
    event BuyChip(address indexed buyer, address indexed tokenAddress, uint256 amount);
    event SellChip(address indexed seller, uint256 amount);

    constructor(address _treasury, address _feeAddress, address _feeTokenAddress, uint256 _feeTokenAmount) {
        treasury = _treasury;
        feeAddress = _feeAddress;
        feeTokenAddress = _feeTokenAddress;
        feeTokenAmount = _feeTokenAmount;
    }

    function setTreasury(address _treasury) public onlyOwner {
        require(_treasury != address(0), "Don't allow to set zero address");
        treasury =  _treasury;
    }

    function buyChip(address tokenAddress, uint256 amount) public {
        ERC20 token = ERC20(tokenAddress);
        token.transferFrom(msg.sender, treasury, amount);
        emit BuyChip(msg.sender, tokenAddress, amount);
    }

    function sellChip(uint256 amount) public {
        ERC20 token = ERC20(feeTokenAddress);
        require(token.balanceOf(msg.sender) >= feeTokenAmount, "Fee token not enough");
        token.transferFrom(msg.sender, treasury, feeTokenAmount);
        emit SellChip(msg.sender, amount);
    }

    function setTokenRate(address tokenAddress, uint256 balance, uint256 bonus) public onlyOwner {
        TokenRate memory tokenRate = TokenRate(tokenAddress, balance, bonus);
        tokenRate.balance = balance;
        tokenRate.bonus = bonus;
        tokenRates[tokenAddress] = tokenRate;
    }

    function setFeeTokenAmount(address _feeTokenAddress, uint256 _feeTokenAmount) public onlyOwner {
        feeTokenAddress = _feeTokenAddress;
        feeTokenAmount = _feeTokenAmount;
    }

    function getTokenRate(address tokenAddress) public view returns (TokenRate memory) {
        return tokenRates[tokenAddress];
    }

    function getChipByToken(address tokenAddress, uint256 amount) public view returns (uint256) {
        TokenRate memory tokenRate = getTokenRate(tokenAddress);
        uint256 balance = amount.mul(tokenRate.balance).div(denominator);
        uint256 bonus = amount.mul(tokenRate.bonus).div(denominator);
        return balance.add(bonus);
    }

}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./lib/roles/OwnerRole.sol";
import "./lib/SafeMath.sol";
import "./Token.sol";

contract Presale is OwnerRole {
    using SafeMath for uint256;

    event Purchase(address indexed _address, uint256 _bnbAmount, uint256 _tokensAmount);
    event TransferBnb(address indexed _address, uint256 _bnbAmount);
    event Paused();
    event Started();

    uint256 public totalBnb;
    uint256 public totalToken;

    Token public token;
    uint256 public rate;
    address payable public transferAddress;

    bool public mintable = false;
    bool public paused = false;

    uint256 public minPurchase;
    uint256 public maxPurchasePerWallet = 20 ether;

    mapping(address => uint256) private balances;
    address[] private investers;

    constructor(Token _token, uint256 _rate) public {
        token = _token;
        rate = _rate;
        transferAddress = msg.sender;

        minPurchase = _rate;
    }

    receive() external payable {
        purchase();
    }

    function purchase() public payable {
        require(!paused, "Presale: paused");
        require(minPurchase <= msg.value && balances[msg.sender] + msg.value <= maxPurchasePerWallet, "Presale: purchase amount limit");

        uint256 tokensAmount = calculateTokensAmount(msg.value);

        deliverTokens(msg.sender, tokensAmount);

        totalBnb = totalBnb.add(msg.value);
        totalToken = totalToken.add(tokensAmount);

        balances[msg.sender] = balances[msg.sender].add(msg.value);

        emit Purchase(msg.sender, msg.value, tokensAmount);
    }

    function calculateTokensAmount(uint256 _amount) public view returns (uint256)  {
        return _amount.div(rate.div(10000)).mul(10 ** 18).div(10000);
    }

    function tokensBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function balanceOf(address _address) external view returns (uint256) {
        return balances[_address];
    }

    function bnbBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function transferBnb() external onlyOwner {
        uint256 balance = address(this).balance;

        require(balance > 0, "Presale: balance must be greater than zero");

        transferAddress.transfer(balance);

        emit TransferBnb(transferAddress, balance);
    }

    function updateMinPurchase(uint256 _minPurchase) external onlyOwner {
        require(_minPurchase >= rate, "Presale: the minimum purchase amount must be no less than the rate");
        require(maxPurchasePerWallet >= _minPurchase, "Presale: the minimum purchase amount cannot be more than the maximum amount");

        minPurchase = _minPurchase;
    }

    function updateMaxPurchase(uint256 _maxPurchasePerWallet) external onlyOwner {
        require(_maxPurchasePerWallet >= minPurchase, "Presale: the maximum purchase amount cannot be less than the minimum amount");

        maxPurchasePerWallet = _maxPurchasePerWallet;
    }

    function updateRate(uint256 _rate) external onlyOwner {
        rate = _rate;
    }

    function updateTransferAddress(address payable _transferAddress) external onlyOwner {
        transferAddress = _transferAddress;
    }

    function pause() external onlyOwner {
        paused = true;
        emit Paused();
    }

    function start() external onlyOwner {
        paused = false;
        emit Started();
    }

    function updateMintable(bool _mintable) external onlyOwner {
        if (_mintable) {
            require(token.isIMinter(), "Presale: the contract has no right to mint");
        }
        mintable = _mintable;
    }

    function deliverTokens(address _to, uint256 _amount) internal {
        if (mintable) {
            token.mint(_to, _amount);
        } else {
            token.transfer(_to, _amount);
        }
    }
}

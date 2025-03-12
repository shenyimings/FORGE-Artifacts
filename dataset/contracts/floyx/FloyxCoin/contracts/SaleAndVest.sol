// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./access/AccessProtected.sol";
import "./IFloyx.sol";

// 2866, 3333, "0x3Cb593f713d8359aB8ee14994B28ad23E7d9fAd1", 9999000000000000000000000, "0x6D3cF7CeF2f6BEff2e1e68D7e9f87CbE5aD258d1","0x94645A8571e6230cE4Bb51F1a0af656Db6d079C9","0x4d23c8E0e601C5e37b062832427b2D62777fAEF9",1677305407,3333000000000000000000000

contract SaleAndVest is ReentrancyGuard, AccessProtected {
    
    IFloyx internal _token;
    IERC20 internal _usdc;
    IERC20 internal _usdt;
    
    bool public crowdsaleFinalized;     // token sale status
    uint256 private _icoCap;            // ico max limit
    uint256 public soldTokens;          // Amount of tokens sold
    uint256 public weiRaised;           // Amount of wei raised
    uint256 public usdRaised;           // Amount of usd raised    

    address payable private _wallet;    // Address where funds are collected
    uint256 public weiRate;             // wei rate of token    
    uint256 public usdRate;             // usd rate of token
    uint256 public lockPeriod;          // token Lock period
    uint256 public userTokenLimit;      // max tokens a user can buy 
    
    mapping(address => uint256) public totalTokensPurchased;
    mapping(address => uint256) public claimCount;

    event TokensPurchased(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
    event PaymentProccessed(address receiver, uint256 amount, bytes info);
    event RateUpdated(uint256 rate, string currency);
    
    constructor (uint256 rate_,uint256 usdRate_ ,address token_, uint256 icocap_, 
        address usdc, address usdt, address adminWallet, uint256 lockPeriod_, uint256 tokenLimit) Ownable()
    {
        weiRate = rate_;
        usdRate = usdRate_;
        _wallet = payable(adminWallet);
        _token = IFloyx(token_);
        _usdc = IERC20(usdc);
        _usdt = IERC20(usdt);
        crowdsaleFinalized = false;
        _icoCap = icocap_;
        lockPeriod = lockPeriod_;
        userTokenLimit = tokenLimit;
    }

    /**
     * @return the token being sold.
     */
    function token() public view returns (IFloyx) {
        return _token;
    }

    /**
     * @return bool after setting the address where funds are collected.
     */ 
    function setWallet(address payable wallet_)public onlyOwner returns(bool) {
        require(wallet_ != address(0),"Invalid minter address!");
        _wallet = wallet_;
        return true;
    }
    
    /**
     * @return the address where funds are collected.
     */
    function wallet() public view returns (address payable) {
        return _wallet;
    }


    function updateWeiRate(uint256 rate_)public onlyOwner{
        require(rate_ > 0, "Rate can not be zero");
        weiRate = rate_;
        emit RateUpdated(rate_, "Native");
    }

    function updateUsdRate(uint256 rate_)public onlyOwner{
        require(rate_ > 0, "Rate can not be zero");
        usdRate = rate_;
        emit RateUpdated(rate_, "Usd");
    }

    function updateLockPeriod(uint256 lockPeriod_)public onlyOwner{
        require(block.timestamp < lockPeriod, "Can not update lock period once it is passed");
        lockPeriod = lockPeriod_;
    }

    function updateTokenLimit(uint256 tokenLimit_)public onlyOwner{
        userTokenLimit = tokenLimit_ ;
    }
    /**
     * @dev This function has a non-reentrancy guard, so it shouldn't be called by
     * another `nonReentrant` function.
     */
    function buyTokens() public nonReentrant payable {
        
        require(!crowdsaleFinalized,"Crowdsale is finalized!");
        require(msg.value != 0, "Crowdsale: weiAmount is 0");
        
        uint256 weiAmount = msg.value;
        uint256 tokens = _getTokenAmount(weiAmount, true);

        weiRaised = weiRaised + weiAmount;
        _processPayment(_wallet, msg.value);
        _processPurchase(msg.sender, tokens);
        
        emit TokensPurchased(msg.sender, msg.sender, weiAmount, tokens);

    }

    /**
     * @dev This function has a non-reentrancy guard, so it shouldn't be called by
     * another `nonReentrant` function.
     * @param usdAmount_ amount of usdc or usdt tokens used to buy floyx.
     * @param usdc boolean variable to check payment will be in usdc or usdt
     */
    function buyTokenswithUsd(uint256 usdAmount_,bool usdc) public nonReentrant {
        require(usdAmount_ > 0 , "Crowdsale: UsdAmount is 0");
        require(!crowdsaleFinalized,"Crowdsale is finalized!");

        uint256 tokens = _getTokenAmount(usdAmount_, false);
        usdRaised = usdRaised + usdAmount_;

        usdc ? require(_usdc.transferFrom(msg.sender, address(this), usdAmount_)) : require(_usdt.transferFrom(msg.sender, address(this), usdAmount_));
        _processPurchase(msg.sender, tokens);
        
        emit TokensPurchased(msg.sender, msg.sender, usdAmount_, tokens);
    }

    function allocateFloyxadmin(address beneficiary_, uint256 floyxAmount_)public onlyOwner{
        require(beneficiary_ != address(0), "invalid address");
        require(floyxAmount_ > 0 , "Invalid floyx amount");
        _processPurchase(beneficiary_, floyxAmount_);
    } 

    function claimTokens()public{
        require(block.timestamp > lockPeriod, "Crowdsale: Can not claim during lock period");
        require(claimCount[msg.sender] < 13, "Crowdsale: No more claims left");

        // uint256 monthDiff = (block.timestamp.sub(lockPeriod)).div(30 days);
        uint256 monthDiff = (block.timestamp - lockPeriod) / 3600;
        require(monthDiff > claimCount[msg.sender], "Crowdsale: Nothing to claim yet");
        if (monthDiff > 13){ monthDiff = 13;}

        if (claimCount[msg.sender] == 0){
            _token.mint(msg.sender, (totalTokensPurchased[msg.sender] * 10)/100);
            claimCount[msg.sender] = 1;
        }

        for(uint i = claimCount[msg.sender]; i < monthDiff; i ++){
            claimCount[msg.sender] += 1;
            uint256 tokenAmount = (totalTokensPurchased[msg.sender] * 75)/ 1000;      // release 7.5% of the tokens
            tokenAmount = tokenAmount + (tokenAmount * 2)/100;                 // extra 2% reward on every claim
            _token.mint(msg.sender, tokenAmount);
        }
        
    }
    
    function updateCrowdsaleStatus(bool status_) public onlyOwner{
        crowdsaleFinalized = status_;
    }
    
    /**
     * @dev Executed when a purchase has been validated and is ready to be executed. Doesn't necessarily emit/send
     * tokens.
     * @param beneficiary Address receiving the tokens
     * @param tokenAmount Number of tokens to be purchased
     */
    function _processPurchase(address beneficiary, uint256 tokenAmount) internal {
        require(soldTokens + tokenAmount <= _icoCap , "ICO limit reached");
        require(totalTokensPurchased[beneficiary] + tokenAmount <= userTokenLimit, "User max allocation limit reached");
        
        soldTokens = soldTokens + tokenAmount;
        totalTokensPurchased[beneficiary] = totalTokensPurchased[beneficiary] + tokenAmount;
    }
    
    /**
     * @dev Override to extend the way in which ether is converted to tokens.
     * @param amount Value in wei to be converted into tokens
     * @return Number of tokens that can be purchased with the specified _weiAmount
     */
    function _getTokenAmount(uint256 amount, bool eth) internal view returns (uint256) {
        
        return eth ? amount * weiRate : amount * usdRate; 
    }
    
    /**
     * @dev Determines how MATIC is forwarded to admin.
     */
    function adminMaticWithdrawal(uint256 amount_) public onlyOwner {
        _processPayment(_wallet, amount_);
    }

    function adminFloyxWithdrawal(uint256 _amount)public onlyOwner {
        require(_token.balanceOf(address(this)) >= _amount, "Contract does not have enough balance");
        require(_token.transfer(msg.sender, _amount), "Transfer failed");
    }

    function adminUsdcWithdrawal(uint256 _amount)public onlyOwner {
        require(_usdc.balanceOf(address(this)) >= _amount, "Contract does not have enough balance");
        require(_usdc.transfer(msg.sender, _amount), "Transfer failed");
    }

    function adminUsdtWithdrawal(uint256 _amount)public onlyOwner {
        require(_usdt.balanceOf(address(this)) >= _amount, "Contract does not have enough balance");
        require(_usdt.transfer(msg.sender, _amount), "Transfer failed");
    }
    /**
     * @dev function to transfer matic to recepient account
     */
    function _processPayment(address payable recepient, uint256 amount_)private{
        
        (bool sent, bytes memory data) = recepient.call{value: amount_}("");
        require(sent, "Failed to send Ether");
        
        emit PaymentProccessed(recepient, amount_, data);
    }
    
}



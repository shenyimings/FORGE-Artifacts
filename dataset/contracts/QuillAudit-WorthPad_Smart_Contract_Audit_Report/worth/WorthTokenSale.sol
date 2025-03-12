import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

/* Token Interface */
interface Token {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
}

/* WORTH Token Sale Contract */
contract WorthTokenSale is ReentrancyGuard, Context, Ownable {

    using SafeMath for uint256;

    address public tokenAddr;
    address public usdtAddr;
    address public busdAddr;
    
    uint256 public tokenPriceUsd = 35000000000000; 
    uint256 public tokenDecimal = 18;
    uint256 public totalTransaction;
    uint256 public totalHardCap;
    uint256 public minContribution;
    uint256 public maxContribution;
    uint256 public hardCap;
    uint256 public startAt;
    uint256 public endAt;

    //Keep track of whether contract is up or not
    bool public contractUp;
      
    //Keep track of whether the sale has ended or not
    bool public saleEnded;
    
    //Event to trigger Sale stop
    event SaleStopped(address _owner, uint256 time);

    event TokenTransfer(address beneficiary, uint amount);
    event amountTransfered(address indexed fromAddress,address contractAddress,address indexed toAddress, uint256 indexed amount);
    event TokenDeposited(address indexed beneficiary, uint amount);
    event UsdDeposited(address indexed beneficiary, uint amount);
    
    mapping(address => uint256) public balances;
    mapping(address => bool) public whitelisted;
    mapping(address => uint256) public tokenExchanged;

    bool public whitelist = true;
    uint256 public claimDate;

    //modifiers    
    modifier _contractUp(){
        require(contractUp);
        _;
    }
  
     modifier nonZeroAddress(address _to) {
        require(_to != address(0));
        _;
    }
    
    modifier _saleEnded() {
        require(saleEnded);
        _;
    }
    
    modifier _saleNotEnded() {
        require(!saleEnded);
        _;
    }

    /* Constructor Arguments : */
    /* 1. WorthToken token contract Address */
    /* 2. Start date (in UNIX Timestamp) */
    /* 3. End date (in UNIX Timestamp) */
    /* 4. Min Contribution (in WEI) */
    /* 5. Max Contribution (in WEI) */
    /* 6. Hard Cap (in WEI) */
    /* 7. Claim Date (in UNIX Timestamp) */
    /* 8. USDT token address */
    /* 9. BUSD token address */
    /* 10. Token ICO Price (in WEI) USD */
    constructor(address _tokenAddr, uint256 _startDate, 
                uint256 _endDate,uint256 _minContribution,
                uint256 _maxContribution,uint256 _hardCap,
                uint256 _claimDate, address _usdtAddr,
                address _busdAddr, uint256 _tokenPriceUsd) nonZeroAddress(_tokenAddr) {
        tokenAddr = _tokenAddr;
        startAt = _startDate;
        endAt = _endDate;
        minContribution =_minContribution;
        maxContribution = _maxContribution;
        hardCap =_hardCap;
        claimDate = _claimDate;
        usdtAddr = _usdtAddr;
        busdAddr = _busdAddr;
        tokenPriceUsd = _tokenPriceUsd;
    }

    /* Function     : This function is used to Whitelist address for Sale */
    /* Parameters   : Array Address of all users */
    /* Public Function */
    function whitelistAddress(address[] memory _recipients) public onlyOwner _contractUp() _saleNotEnded() returns (bool) {
        for (uint i = 0; i < _recipients.length; i++) {
            whitelisted[_recipients[i]] = true;
        }
        return true;
    } 
    
    /* Function     : This function is used to deposit tokens for liquidity manually */
    /* Parameters   : Total amount needed to be added as liquidity */
    /* Public Function */    
    function depositTokens(uint256  _amount) public returns (bool) {
        require(_amount <= Token(tokenAddr).balanceOf(msg.sender),"Token Balance of user is less");
        require(Token(tokenAddr).transferFrom(msg.sender,address(this), _amount));
        emit TokenDeposited(msg.sender, _amount);
        return true;
    }

    /* Function     : This function is used to claim token brought */
    /* Parameters   : -- */
    /* Public Function */
    function claimToken() public nonReentrant _saleEnded() returns (bool) {
        address userAdd = msg.sender;
        uint256 amountToClaim = tokenExchanged[userAdd];
        require(block.timestamp>claimDate,"Cannot Claim Now");
        require(amountToClaim>0,"There is no amount to claim");
        require(amountToClaim <= Token(tokenAddr).balanceOf(address(this)),"Token Balance of contract is less");
        Token(tokenAddr).transfer(userAdd, amountToClaim);
        emit TokenTransfer(userAdd, amountToClaim);
        tokenExchanged[userAdd] = 0;
        return true;
    }
    
    /* This function will accept BUSD/USDT directly sent to the address */
    receive() payable external {
    }

    /* Function     : This function is used to buy token using USDT */
    /* Parameters   : Total token to buy (in WEI) */
    /* Public Function */
    function ExchangeUSDTforToken(uint256 _amount) public nonReentrant _contractUp _saleNotEnded {
        require(Token(usdtAddr).transferFrom(msg.sender,address(this), _amount));
        uint256 amount = _amount;
        address userAdd = msg.sender;
        uint256 tokenAmount = 0;
        balances[msg.sender] = balances[msg.sender].add(_amount);
        
        if(whitelist){
            require(whitelisted[userAdd],"User is not Whitelisted");
        }
        require(totalHardCap < hardCap, "USD Hardcap Reached");
        require(balances[msg.sender] >= minContribution && balances[msg.sender] <= maxContribution,"Contribution should satisfy min max case");
        totalTransaction = totalTransaction.add(1);
        totalHardCap = totalHardCap.add(amount);
        tokenAmount = ((amount.mul(10 ** uint256(tokenDecimal)).div(tokenPriceUsd)).mul(10 ** uint256(tokenDecimal))).div(10 ** uint256(tokenDecimal));
        tokenExchanged[userAdd] += tokenAmount;
        
        emit UsdDeposited(msg.sender,_amount);
    }

    /* Function     : This function is used to buy token using BUSD */
    /* Parameters   : Total token to buy (in WEI) */
    /* Public Function */
    function ExchangeBUSDforToken(uint256 _amount) public nonReentrant _contractUp _saleNotEnded {
        require(Token(busdAddr).transferFrom(msg.sender,address(this), _amount));
        uint256 amount = _amount;
        address userAdd = msg.sender;
        uint256 tokenAmount = 0;
        balances[msg.sender] = balances[msg.sender].add(_amount);
        
        if(whitelist){
            require(whitelisted[userAdd],"User is not Whitelisted");
        }
        require(totalHardCap < hardCap, "USD Hardcap Reached");
        require(balances[msg.sender] >= minContribution && balances[msg.sender] <= maxContribution,"Contribution should satisfy min max case");
        totalTransaction = totalTransaction.add(1);
        totalHardCap = totalHardCap.add(amount);
        tokenAmount = ((amount.mul(10 ** uint256(tokenDecimal)).div(tokenPriceUsd)).mul(10 ** uint256(tokenDecimal))).div(10 ** uint256(tokenDecimal));
        tokenExchanged[userAdd] += tokenAmount;
        
        emit UsdDeposited(msg.sender,_amount);
    }

    
    /* ONLY OWNER FUNCTIONS */

    /**
    *     @dev Check if sale contract is powered up
    */
    function powerUpContract() external onlyOwner {
        // Contract should not be powered up previously
        require(!contractUp);
        //activate the sale process
        contractUp = true;
    }

    //for Emergency/Hard stop of the sale
    function emergencyStop() external onlyOwner _contractUp _saleNotEnded {
        saleEnded = true;    
        emit SaleStopped(msg.sender, block.timestamp);
    }

    /* Function     : Updates Whitelisting feature ON/OFF */
    /* Parameters   : -- */
    /* Only Owner Function */
    function toggleWhitelistStatus() public onlyOwner returns (bool success)  {
        if (whitelist) {
            whitelist = false;
        } else {
            whitelist = true;
        }
        return true;     
    }

    /* Function     : Update new Token Price */
    /* Parameters   : New token price */
    /* Only Owner Function */    
    function updateTokenPrice(uint256 newTokenValue) public onlyOwner {
        tokenPriceUsd = newTokenValue;
    }

    /* Function     : Update Hard cap of sale (in WEI) */
    /* Parameters   : New Hard cap */
    /* Only Owner Function */
    function updateHardCap(uint256 newHardcapValue) public onlyOwner {
        hardCap = newHardcapValue;
    }

    /* Function     : Update Min Max tokens to buy (in WEI) */
    /* Parameters 1 : Min Token */
    /* Parameters 2 : Max Token */
    /* Only Owner Function */
    function updateTokenContribution(uint256 min, uint256 max) public onlyOwner {
        minContribution = min;
        maxContribution = max;
    }

    /* Function     : Update USDT and BUSD tokens address */
    /* Parameters 1 : Update USDT Address */
    /* Parameters 2 : Update BUSD Address */
    /* Only Owner Function */
    function updateUSDTBUSDaddress(address usdt, address busd) public onlyOwner {
        usdtAddr = usdt;
        busdAddr = busd;
    }
    
    /* Function     : Update Token decimals */
    /* Parameters   : New token decimals */
    /* Only Owner Function */
    function updateTokenDecimal(uint256 newDecimal) public onlyOwner {
        tokenDecimal = newDecimal;
    }

    /* Function     : Updates the token address */
    /* Parameters   : New Token Address */
    /* Only Owner Function */
    function updateTokenAddress(address newTokenAddr) public onlyOwner {
        tokenAddr = newTokenAddr;
    }

    /* Function     : Withdraw Tokens remaining after the sale */
    /* Parameters 1 : Address where token should be sent */
    /* Parameters 2 : Token Address */
    /* Only Owner Function */
    function withdrawTokens(address beneficiary,address _tokenAddr) public onlyOwner {
        require(Token(_tokenAddr).transfer(beneficiary, Token(_tokenAddr).balanceOf(address(this))));
    }

    /* Function     : Withdraws BNB after sale */
    /* Parameters   : Address where BNB should be sent */
    /* Only Owner Function */
    function withdrawCrypto(address payable beneficiary) public onlyOwner {
        beneficiary.transfer(address(this).balance);
    }
    
    /* Function     : Changes the Claim date for ICO */
    /* Parameters   : Claim date in UNIX Timestamp */
    /* Only Owner Function */
    function changeClaimDate(uint256 _claimDate) public onlyOwner {
        claimDate = _claimDate;
    }

    /* ONLY OWNER FUNCTION ENDS HERE */

    /* VIEW FUNCTIONS */

    /* Function     : Returns Token Balance inside contract */
    /* Parameters   : -- */
    /* Public View Function */
    function getTokenBalance(address _tokenAddr) public view nonZeroAddress(_tokenAddr) returns (uint256){
        return Token(_tokenAddr).balanceOf(address(this));
    }

    /* Function     : Returns Crypto Balance inside contract */
    /* Parameters   : -- */
    /* Public View Function */
    function getCryptoBalance() public view returns (uint256){
        return address(this).balance;
    }
}

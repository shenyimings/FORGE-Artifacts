pragma solidity ^0.4.21;


//import '../node_modules/zeppelin-solidity/contracts/math/SafeMath.sol';
import './LuckchemyToken.sol';


/*
 *Crowdsale contract for Luckchemy Token
*/
contract LuckchemyCrowdsale {
    using SafeMath for uint256;

    //  Token for selling
    LuckchemyToken public token;

    /*
    *  Start and End date of investment process
    */

    // 2018-04-30 00:00:00 GMT - start time for public sale
    uint256 public constant START_TIME_SALE = 1525046400;

    // 2018-07-20 23:59:59 GMT - end time for public sale
    uint256 public constant END_TIME_SALE = 1532131199;

    // 2018-04-02 00:00:00 GMT - start time for private sale
    uint256 public constant START_TIME_PRESALE = 1522627200;

    // 2018-04-24 23:59:59 GMT - end time for private sale
    uint256 public constant END_TIME_PRESALE = 1524614399;


    // amount of already sold tokens
    uint256 public tokensSold = 0;

    //supply for crowdSale
    uint256 public totalSupply = 0;
    // hard cap
    uint256 public constant hardCap = 45360 ether;
    // soft cap
    uint256 public constant softCap = 2000 ether;

    // wei representation of collected fiat
    uint256 public fiatBalance = 0;
    // ether collected in wei
    uint256 public ethBalance = 0;

    //address of serviceAgent (it can calls  payFiat function)
    address public serviceAgent;

    // owner of the contract
    address public owner;

    //default token rate
    uint256 public constant RATE = 12500; // Token price in ETH - 0.00008 ETH  1 ETHER = 12500 tokens

    // 2018/04/30 - 2018/07/22  
    uint256 public constant DISCOUNT_PRIVATE_PRESALE = 80; // 80 % discount

    // 2018/04/30 - 2018/07/20
    uint256 public constant DISCOUNT_STAGE_ONE = 40;  // 40% discount

    // 2018/04/02 - 2018/04/24   
    uint256 public constant DISCOUNT_STAGE_TWO = 20; // 20% discount

    // 2018/04/30 - 2018/07/22  
    uint256 public constant DISCOUNT_STAGE_THREE = 0;




    //White list of addresses that are allowed to by a token
    mapping(address => bool) public whitelist;


    /**
     * List of addresses for ICO fund with shares in %
     * 
     */
    uint256 public constant LOTTERY_FUND_SHARE = 40;
    uint256 public constant OPERATIONS_SHARE = 50;
    uint256 public constant PARTNERS_SHARE = 10;

    address public constant LOTTERY_FUND_ADDRESS = 0x84137CB59076a61F3f94B2C39Da8fbCb63B6f096;
    address public constant OPERATIONS_ADDRESS = 0xEBBeAA0699837De527B29A03ECC914159D939Eea;
    address public constant PARTNERS_ADDRESS = 0x820502e8c80352f6e11Ce036DF03ceeEBE002642;

    /**
     * event for token ETH purchase  logging
     * @param purchaser who paid for the tokens
     * @param beneficiary who got the tokens
     * @param value weis paid for purchase
     * @param amount amount of tokens purchased
     */
    event TokenETHPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);


    /**
     * event for token FIAT purchase  logging
     * @param purchaser who paid for the tokens
     * @param beneficiary who got the tokens
     * @param amount amount of tokens purchased
     */
    event TokenFiatPurchase(address indexed purchaser, address indexed beneficiary, uint256 amount);

    /*
     * modifier which gives specific rights to owner
     */
    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }
    /*
     * modifier which gives possibility to call payFiat function
     */
    modifier onlyServiceAgent(){
        require(msg.sender == serviceAgent);
        _;
    }

    /*
    *
    *modifier which gives possibility to purchase
    *
    */
    modifier onlyWhiteList(address _address){
        require(whitelist[_address] == true);
        _;
    }
    /*
     * Enum which defines stages of ICO
    */

    enum Stage {
        Private,
        Discount40,
        Discount20,
        NoDiscount
    }

    //current stage
    Stage public  currentStage;

    //pools of token for each stage
    mapping(uint256 => uint256) public tokenPools;

    //number of tokens per 1 ether for each stage
    mapping(uint256 => uint256) public stageRates;

    /*
    * deposit is amount in wei , which was sent to the contract
    * @ address - address of depositor
    * @ uint256 - amount
    */
    mapping(address => uint256) public deposits;

    /* 
    * constructor of contract 
    *  @ _service- address which has rights to call payFiat
    */
    function LuckchemyCrowdsale(address _service) public {
        require(START_TIME_SALE >= now);
        require(START_TIME_SALE > END_TIME_PRESALE);
        require(END_TIME_SALE > START_TIME_SALE);

        require(_service != 0x0);

        owner = msg.sender;
        serviceAgent = _service;
        token = new LuckchemyToken();
        totalSupply = token.CROWDSALE_SUPPLY();

        currentStage = Stage.Private;

        uint256 decimals = uint256(token.decimals());

        tokenPools[uint256(Stage.Private)] = 70000000 * (10 ** decimals);
        tokenPools[uint256(Stage.Discount40)] = 105000000 * (10 ** decimals);
        tokenPools[uint256(Stage.Discount20)] = 175000000 * (10 ** decimals);
        tokenPools[uint256(Stage.NoDiscount)] = 350000000 * (10 ** decimals);

        stageRates[uint256(Stage.Private)] = RATE.mul(10 ** decimals).mul(100).div(100 - DISCOUNT_PRIVATE_PRESALE);
        stageRates[uint256(Stage.Discount40)] = RATE.mul(10 ** decimals).mul(100).div(100 - DISCOUNT_STAGE_ONE);
        stageRates[uint256(Stage.Discount20)] = RATE.mul(10 ** decimals).mul(100).div(100 - DISCOUNT_STAGE_TWO);
        stageRates[uint256(Stage.NoDiscount)] = RATE.mul(10 ** decimals).mul(100).div(100 - DISCOUNT_STAGE_THREE);

    }

    /*
     * function to get amount ,which invested by depositor
     * @depositor - address ,which bought tokens
    */
    function depositOf(address depositor) public constant returns (uint256) {
        return deposits[depositor];
    }
    /*
     * fallback function can be used to buy  tokens
     */
    function() public payable {
        payETH(msg.sender);
    }


    /*
    * function for tracking ethereum purchases
    * @beneficiary - address ,which received tokens
    */
    function payETH(address beneficiary) public onlyWhiteList(beneficiary) payable {

        require(msg.value >= 0.1 ether);
        require(beneficiary != 0x0);
        require(validPurchase());
        if (isPrivateSale()) {
            processPrivatePurchase(msg.value, beneficiary);
        } else {
            processPublicPurchase(msg.value, beneficiary);
        }


    }

    /*
     * function for processing purchase in private sale
     * @weiAmount - amount of wei , which send to the contract
     * @beneficiary - address for receiving tokens
     */
    function processPrivatePurchase(uint256 weiAmount, address beneficiary) private {

        uint256 stage = uint256(Stage.Private);

        require(currentStage == Stage.Private);
        require(tokenPools[stage] > 0);

        //calculate number tokens
        uint256 tokensToBuy = (weiAmount.mul(stageRates[stage])).div(1 ether);
        if (tokensToBuy <= tokenPools[stage]) {
            //pool has enough tokens
            payoutTokens(beneficiary, tokensToBuy, weiAmount);

        } else {
            //pool doesn't have enough tokens
            tokensToBuy = tokenPools[stage];
            //left wei
            uint256 usedWei = (tokensToBuy.mul(1 ether)).div(stageRates[stage]);
            uint256 leftWei = weiAmount.sub(usedWei);

            payoutTokens(beneficiary, tokensToBuy, usedWei);

            //change stage to Public Sale
            currentStage = Stage.Discount40;

            //return left wei to beneficiary and change stage
            beneficiary.transfer(leftWei);
        }
    }
    /*
    * function for processing purchase in public sale
    * @weiAmount - amount of wei , which send to the contract
    * @beneficiary - address for receiving tokens
    */
    function processPublicPurchase(uint256 weiAmount, address beneficiary) private {

        if (currentStage == Stage.Private) {
            currentStage = Stage.Discount40;
            tokenPools[uint256(Stage.Discount40)] = tokenPools[uint256(Stage.Discount40)].add(tokenPools[uint256(Stage.Private)]);
            tokenPools[uint256(Stage.Private)] = 0;
        }

        for (uint256 stage = uint256(currentStage); stage <= 3; stage++) {

            //calculate number tokens
            uint256 tokensToBuy = (weiAmount.mul(stageRates[stage])).div(1 ether);

            if (tokensToBuy <= tokenPools[stage]) {
                //pool has enough tokens
                payoutTokens(beneficiary, tokensToBuy, weiAmount);

                break;
            } else {
                //pool doesn't have enough tokens
                tokensToBuy = tokenPools[stage];
                //left wei
                uint256 usedWei = (tokensToBuy.mul(1 ether)).div(stageRates[stage]);
                uint256 leftWei = weiAmount.sub(usedWei);

                payoutTokens(beneficiary, tokensToBuy, usedWei);

                if (stage == 3) {
                    //return unused wei when all tokens sold
                    beneficiary.transfer(leftWei);
                    break;
                } else {
                    weiAmount = leftWei;
                    //change current stage
                    currentStage = Stage(stage + 1);
                }
            }
        }
    }
    /*
     * function for actual payout in public sale
     * @beneficiary - address for receiving tokens
     * @tokenAmount - amount of tokens to payout
     * @weiAmount - amount of wei used
     */
    function payoutTokens(address beneficiary, uint256 tokenAmount, uint256 weiAmount) private {
        uint256 stage = uint256(currentStage);
        tokensSold = tokensSold.add(tokenAmount);
        tokenPools[stage] = tokenPools[stage].sub(tokenAmount);
        deposits[beneficiary] = deposits[beneficiary].add(weiAmount);
        ethBalance = ethBalance.add(weiAmount);

        token.transfer(beneficiary, tokenAmount);
        TokenETHPurchase(msg.sender, beneficiary, weiAmount, tokenAmount);
    }
    /*
     * function for change btc agent
     * can be called only by owner of the contract
     * @_newServiceAgent - new serviceAgent address
     */
    function setServiceAgent(address _newServiceAgent) public onlyOwner {
        serviceAgent = _newServiceAgent;
    }
    /*
     * function for tracking bitcoin purchases received by bitcoin wallet
     * each transaction and amount of tokens according to rate can be validated on public bitcoin wallet
     * public key - #
     * @beneficiary - address, which received tokens
     * @amount - amount tokens
     * @stage - number of the stage (80% 40% 20% 0% discount)
     * can be called only by serviceAgent address
     */
    function payFiat(address beneficiary, uint256 amount, uint256 stage) public onlyServiceAgent onlyWhiteList(beneficiary) {

        require(beneficiary != 0x0);
        require(tokenPools[stage] >= amount);
        require(stage == uint256(currentStage));

        //calculate fiat amount in wei
        uint256 fiatWei = amount.mul(1 ether).div(stageRates[stage]);
        fiatBalance = fiatBalance.add(fiatWei);
        require(validPurchase());

        tokenPools[stage] = tokenPools[stage].sub(amount);
        tokensSold = tokensSold.add(amount);

        token.transfer(beneficiary, amount);
        TokenFiatPurchase(msg.sender, beneficiary, amount);
    }


    /*
     * function for  checking if crowdsale is finished
     */
    function hasEnded() public constant returns (bool) {
        return now > END_TIME_SALE || tokensSold >= totalSupply;
    }

    /*
     * function for  checking if hardCapReached
     */
    function hardCapReached() public constant returns (bool) {
        return tokensSold >= totalSupply || fiatBalance.add(ethBalance) >= hardCap;
    }
    /*
     * function for  checking if crowdsale goal is reached
     */
    function softCapReached() public constant returns (bool) {
        return fiatBalance.add(ethBalance) >= softCap;
    }

    function isPrivateSale() public constant returns (bool) {
        return now >= START_TIME_PRESALE && now <= END_TIME_PRESALE;
    }

    /*
     * function that call after crowdsale is ended
     *          releaseTokenTransfer - enable token transfer between users.
     *          burn tokens which are left on crowsale contract balance
     *          transfer balance of contract to wallets according to shares.
     */
    function forwardFunds() public onlyOwner {
        require(hasEnded());
        require(softCapReached());

        token.releaseTokenTransfer();
        token.burn(token.balanceOf(this));

        //transfer token ownership to this owner of crowdsale
        token.transferOwnership(msg.sender);

        //transfer funds here
        uint256 totalBalance = this.balance;
        LOTTERY_FUND_ADDRESS.transfer((totalBalance.mul(LOTTERY_FUND_SHARE)).div(100));
        OPERATIONS_ADDRESS.transfer((totalBalance.mul(OPERATIONS_SHARE)).div(100));
        PARTNERS_ADDRESS.transfer(this.balance); // send the rest to partners (PARTNERS_SHARE)
    }
    /*
     * function that call after crowdsale is ended
     *          conditions : ico ended and goal isn't reached. amount of depositor > 0.
     *
     *          refund eth deposit (fiat refunds will be done manually)
     */
    function refund() public {
        require(hasEnded());
        require(!softCapReached() || ((now > END_TIME_SALE + 30 days) && !token.released()));
        uint256 amount = deposits[msg.sender];
        require(amount > 0);
        deposits[msg.sender] = 0;
        msg.sender.transfer(amount);

    }

    /*
        internal functions
    */

    /*
     *  function for checking period of investment and investment amount restriction for ETH purchases
     */
    function validPurchase() internal constant returns (bool) {
        bool withinPeriod = (now >= START_TIME_PRESALE && now <= END_TIME_PRESALE) || (now >= START_TIME_SALE && now <= END_TIME_SALE);
        return withinPeriod && !hardCapReached();
    }
    /*
     * function for adding address to whitelist
     * @_whitelistAddress - address to add
     */
    function addToWhiteList(address _whitelistAddress) public onlyServiceAgent {
        whitelist[_whitelistAddress] = true;
    }

    /*
     * function for removing address from whitelist
     * @_whitelistAddress - address to remove
     */
    function removeWhiteList(address _whitelistAddress) public onlyServiceAgent {
        delete whitelist[_whitelistAddress];
    }


}
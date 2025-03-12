pragma solidity ^0.4.17;

import "./ERC20MiniMe.sol";
import "./CappedCrowdsale.sol";
import "./RefundableCrowdsale.sol";
import "./TokenController.sol";
import "./Pausable.sol";


/**
 * @title EthealPreSale
 * @author thesved
 * @notice Etheal Token Sale round one presale contract, with mincap (goal), softcap and hardcap (cap)
 * @dev This contract has to be finalized before refund or token claims are enabled
 */
contract EthealPreSale is Pausable, CappedCrowdsale, RefundableCrowdsale {
    // the token is here
    TokenController public ethealController;

    // after reaching {weiRaised} >= {softCap}, there is {softCapTime} seconds until the sale closes
    // {softCapClose} contains the closing time
    uint256 public rate = 1250;
    uint256 public goal = 333 ether;
    uint256 public softCap = 3600 ether;
    uint256 public softCapTime = 120 hours;
    uint256 public softCapClose;
    uint256 public cap = 7200 ether;

    // how many token is sold and not claimed, used for refunding to token controller
    uint256 public tokenBalance;

    // total token sold
    uint256 public tokenSold;

    // contributing above {maxGasPrice} results in 
    // calculating stakes on {maxGasPricePenalty} / 100
    // eg. 80 {maxGasPricePenalty} means 80%, sending 5 ETH with more than 100gwei gas price will be calculated as 4 ETH
    uint256 public maxGasPrice = 100 * 10**9;
    uint256 public maxGasPricePenalty = 80;

    // minimum contribution, 0.1ETH
    uint256 public minContribution = 0.1 ether;

    // first {whitelistDayCount} days of token sale is exclusive for whitelisted addresses
    // {whitelistDayMaxStake} contains the max stake limits per address for each whitelist sales day
    // {whitelist} contains who can contribute during whitelist period
    uint8 public whitelistDayCount;
    mapping (address => bool) public whitelist;
    mapping (uint8 => uint256) public whitelistDayMaxStake;
    
    // stakes contains contribution stake in wei
    // contributed ETH is calculated on 80% when sending funds with gasprice above maxGasPrice
    mapping (address => uint256) public stakes;

    // addresses of contributors to handle finalization after token sale end (refunds or token claims)
    address[] public contributorsKeys; 

    // events for token purchase during sale and claiming tokens after sale
    event TokenClaimed(address indexed _claimer, address indexed _beneficiary, uint256 _stake, uint256 _amount);
    event TokenPurchase(address indexed _purchaser, address indexed _beneficiary, uint256 _value, uint256 _stake, uint256 _amount, uint256 _participants, uint256 _weiRaised);
    event TokenGoalReached();
    event TokenSoftCapReached(uint256 _closeTime);

    // whitelist events for adding days with maximum stakes and addresses
    event WhitelistAddressAdded(address indexed _whitelister, address indexed _beneficiary);
    event WhitelistAddressRemoved(address indexed _whitelister, address indexed _beneficiary);
    event WhitelistSetDay(address indexed _whitelister, uint8 _day, uint256 _maxStake);


    ////////////////
    // Constructor and inherited function overrides
    ////////////////

    /// @notice Constructor to create PreSale contract
    /// @param _ethealController Address of ethealController
    /// @param _startTime The start time of token sale in seconds.
    /// @param _endTime The end time of token sale in seconds.
    /// @param _minContribution The minimum contribution per transaction in wei (0.1 ETH)
    /// @param _rate Number of HEAL tokens per 1 ETH
    /// @param _goal Minimum funding in wei, below that EVERYONE gets back ALL their
    ///  contributions regardless of maxGasPrice penalty. 
    ///  Eg. someone contributes with 5 ETH, but gets only 4 ETH stakes because
    ///  sending funds with gasprice over 100Gwei, he will still get back >>5 ETH<<
    ///  in case of unsuccessful token sale
    /// @param _softCap Softcap in wei, reaching it ends the sale in _softCapTime seconds
    /// @param _softCapTime Seconds until the sale remains open after reaching _softCap
    /// @param _cap Maximum cap in wei, we can't raise more funds
    /// @param _gasPrice Maximum gas price
    /// @param _gasPenalty Penalty in percentage points for calculating stakes, eg. 80 means calculating 
    ///  stakes on 80% if gasprice was higher than _gasPrice
    /// @param _wallet Address of multisig wallet, which will get all the funds after successful sale
    function EthealPreSale(
        address _ethealController,
        uint256 _startTime, 
        uint256 _endTime, 
        uint256 _minContribution, 
        uint256 _rate, 
        uint256 _goal, 
        uint256 _softCap, 
        uint256 _softCapTime, 
        uint256 _cap, 
        uint256 _gasPrice, 
        uint256 _gasPenalty, 
        address _wallet
    )
        CappedCrowdsale(_cap)
        FinalizableCrowdsale()
        RefundableCrowdsale(_goal)
        Crowdsale(_startTime, _endTime, _rate, _wallet)
    {
        // ethealController must be valid
        require(_ethealController != address(0));
        ethealController = TokenController(_ethealController);

        // caps have to be consistent with each other
        require(_goal <= _softCap && _softCap <= _cap);

        
        softCap = _softCap;
        softCapTime = _softCapTime;

        // this is needed since super constructor wont overwite overriden variables
        cap = _cap;
        goal = _goal;
        rate = _rate;

        maxGasPrice = _gasPrice;
        maxGasPricePenalty = _gasPenalty;

        minContribution = _minContribution;
    }

    /// @dev Overriding Crowdsale#buyTokens to add partial refund and softcap logic 
    /// @param _beneficiary Beneficiary of the token purchase
    function buyTokens(address _beneficiary) public payable whenNotPaused {
        require(_beneficiary != address(0));

        uint256 weiToCap = howMuchCanXContributeNow(_beneficiary);
        uint256 weiAmount = uint256Min(weiToCap, msg.value);

        // goal is reached
        if (weiRaised < goal && weiRaised.add(weiAmount) >= goal)
            TokenGoalReached();

        // call the Crowdsale#buyTokens internal function
        buyTokens(_beneficiary, weiAmount);

        // close sale in softCapTime seconds after reaching softCap
        if (weiRaised >= softCap && softCapClose == 0) {
            softCapClose = now.add(softCapTime);
            TokenSoftCapReached(uint256Min(softCapClose, endTime));
        }

        // handle refund
        uint256 refund = msg.value.sub(weiAmount);
        if (refund > 0) {
            msg.sender.transfer(refund);
        }
    }

    /// @dev Overriding Crowdsale#transferToken, which keeps track of contributions DURING token sale
    /// @param _beneficiary Address of the recepient of the tokens
    /// @param _weiAmount Contribution in wei
    function transferToken(address _beneficiary, uint256 _weiAmount) internal {
        require(_beneficiary != address(0));

        uint256 weiAmount = _weiAmount;
        // check maxGasPricePenalty
        if (maxGasPrice > 0 && tx.gasprice > maxGasPrice) {
            weiAmount = weiAmount.mul(maxGasPricePenalty).div(100);
        }

        // calculate tokens, so we can refund excess tokens to EthealController after token sale
        uint256 tokens = weiAmount.mul(rate);
        tokenBalance = tokenBalance.add(tokens);

        if (stakes[_beneficiary] == 0)
            contributorsKeys.push(_beneficiary);

        stakes[_beneficiary] = stakes[_beneficiary].add(weiAmount);

        TokenPurchase(msg.sender, _beneficiary, _weiAmount, weiAmount, tokens, contributorsKeys.length, weiRaised);
    }

    /// @dev Overriding Crowdsale#validPurchase to add min contribution logic
    /// @param _weiAmount Contribution amount in wei
    /// @return true if contribution is okay
    function validPurchase(uint256 _weiAmount) internal constant returns (bool) {
        return super.validPurchase(_weiAmount) && _weiAmount >= minContribution;
    }

    /// @dev Overriding Crowdsale#hasEnded to add soft cap logic
    /// @return true if crowdsale event has ended or a softCapClose time is set and passed
    function hasEnded() public constant returns (bool) {
        return super.hasEnded() || softCapClose > 0 && now > softCapClose;
    }

    /// @dev Overriding RefundableCrowdsale#claimRefund to enable anyone to call for any address
    ///  which enables us to refund anyone and also anyone can refund themselves
    function claimRefund() public {
        claimRefundFor(msg.sender);
    }

    /// @dev Extending RefundableCrowdsale#finalization sending back excess tokens to ethealController
    function finalization() internal {
        uint256 _balance = getHealBalance();

        // if token sale was successful send back excess funds
        if (goalReached()) {
            // saving token balance for future reference
            tokenSold = tokenBalance; 

            // send back the excess token to ethealController
            if (_balance > tokenBalance) {
                ethealController.ethealToken().transfer(ethealController.SALE(), _balance.sub(tokenBalance));
            }
        } else if (!goalReached() && _balance > 0) {
            // if token sale is failed, then send back all tokens to ethealController's sale address
            tokenBalance = 0;
            ethealController.ethealToken().transfer(ethealController.SALE(), _balance);
        }

        super.finalization();
    }


    ////////////////
    // BEFORE token sale
    ////////////////

    /// @notice Modifier for before sale cases
    modifier beforeSale() {
        require(!hasStarted());
        _;
    }

    /// @notice Sets whitelist
    /// @dev The length of _whitelistLimits says that the first X days of token sale is 
    ///  closed, meaning only for whitelisted addresses.
    /// @param _add Array of addresses to add to whitelisted ethereum accounts
    /// @param _remove Array of addresses to remove to whitelisted ethereum accounts
    /// @param _whitelistLimits Array of limits in wei, where _whitelistLimits[0] = 10 ETH means
    ///  whitelisted addresses can contribute maximum 10 ETH stakes on the first day
    ///  After _whitelistLimits.length days, there will be no limits per address (besides hard cap)
    function setWhitelist(address[] _add, address[] _remove, uint256[] _whitelistLimits) public onlyOwner beforeSale {
        uint256 i = 0;
        uint8 j = 0; // access max daily stakes

        // we override whiteListLimits only if it was supplied as an argument
        if (_whitelistLimits.length > 0) {
            // saving whitelist max stake limits for each day -> uint256 maxStakeLimit
            whitelistDayCount = uint8(_whitelistLimits.length);

            for (i = 0; i < _whitelistLimits.length; i++) {
                j = uint8(i.add(1));
                if (whitelistDayMaxStake[j] != _whitelistLimits[i]) {
                    whitelistDayMaxStake[j] = _whitelistLimits[i];
                    WhitelistSetDay(msg.sender, j, _whitelistLimits[i]);
                }
            }
        }

        // adding whitelist addresses
        for (i = 0; i < _add.length; i++) {
            require(_add[i] != address(0));
            
            if (!whitelist[_add[i]]) {
                whitelist[_add[i]] = true;
                WhitelistAddressAdded(msg.sender, _add[i]);
            }
        }

        // removing whitelist addresses
        for (i = 0; i < _remove.length; i++) {
            require(_remove[i] != address(0));
            
            if (whitelist[_remove[i]]) {
                whitelist[_remove[i]] = false;
                WhitelistAddressRemoved(msg.sender, _remove[i]);
            }
        }
    }

    /// @notice Sets max gas price and penalty before sale
    function setMaxGas(uint256 _maxGas, uint256 _penalty) public onlyOwner beforeSale {
        maxGasPrice = _maxGas;
        maxGasPricePenalty = _penalty;
    }

    /// @notice Sets min contribution before sale
    function setMinContribution(uint256 _minContribution) public onlyOwner beforeSale {
        minContribution = _minContribution;
    }

    /// @notice Sets minimum goal, soft cap and max cap
    function setCaps(uint256 _goal, uint256 _softCap, uint256 _softCapTime, uint256 _cap) public onlyOwner beforeSale {
        goal = _goal;
        softCap = _softCap;
        softCapTime = _softCapTime;
        cap = _cap;
    }

    /// @notice Sets crowdsale start and end time
    function setTimes(uint256 _startTime, uint256 _endTime) public onlyOwner beforeSale {
        startTime = _startTime;
        endTime = _endTime;
    }

    /// @notice Set rate
    function setRate(uint256 _rate) public onlyOwner beforeSale {
        rate = _rate;
    }


    ////////////////
    // AFTER token sale
    ////////////////

    /// @notice Modifier for cases where sale is failed
    /// @dev It checks whether we haven't reach the minimum goal AND whether the contract is finalized
    modifier afterSaleFail() {
        require(!goalReached() && isFinalized);
        _;
    }

    /// @notice Modifier for cases where sale is closed and was successful.
    /// @dev It checks whether
    ///  the sale has ended 
    ///  and we have reached our goal
    ///  AND whether the contract is finalized
    modifier afterSaleSuccess() {
        require(goalReached() && isFinalized);
        _;
    }

    /// @notice Modifier for after sale finalization
    modifier afterSale() {
        require(isFinalized);
        _;
    }

    
    /// @notice Refund an ethereum address
    /// @param _beneficiary Address we want to refund
    function claimRefundFor(address _beneficiary) public afterSaleFail whenNotPaused {
        require(_beneficiary != address(0));
        vault.refund(_beneficiary);
    }

    /// @notice Refund several addresses with one call
    /// @param _beneficiaries Array of addresses we want to refund
    function claimRefundsFor(address[] _beneficiaries) external afterSaleFail {
        for (uint256 i = 0; i < _beneficiaries.length; i++)
            claimRefundFor(_beneficiaries[i]);
    }

    /// @notice Claim token for msg.sender after token sale based on stake.
    function claimToken() public afterSaleSuccess {
        claimTokenFor(msg.sender);
    }

    /// @notice Claim token after token sale based on stake.
    /// @dev Anyone can call this function and distribute tokens after successful token sale
    /// @param _beneficiary Address of the beneficiary who gets the token
    function claimTokenFor(address _beneficiary) public afterSaleSuccess whenNotPaused {
        uint256 stake = stakes[_beneficiary];
        require(stake > 0);

        // set the stake 0 for beneficiary
        stakes[_beneficiary] = 0;

        // calculate token count
        uint256 tokens = stake.mul(rate);

        // decrease tokenBalance, to make it possible to withdraw excess HEAL funds
        tokenBalance = tokenBalance.sub(tokens);

        // distribute hodlr stake
        ethealController.addHodlerStake(_beneficiary, tokens);

        // distribute token
        require(ethealController.ethealToken().transfer(_beneficiary, tokens));
        TokenClaimed(msg.sender, _beneficiary, stake, tokens);
    }

    /// @notice claimToken() for multiple addresses
    /// @dev Anyone can call this function and distribute tokens after successful token sale
    /// @param _beneficiaries Array of addresses for which we want to claim tokens
    function claimTokensFor(address[] _beneficiaries) external afterSaleSuccess {
        for (uint256 i = 0; i < _beneficiaries.length; i++)
            claimTokenFor(_beneficiaries[i]);
    }

    /// @notice Get back accidentally sent token from the vault
    function extractVaultTokens(address _token, address _claimer) public onlyOwner afterSale {
        require(_claimer != address(0));

        vault.extractTokens(_token, _claimer);
    }


    ////////////////
    // Constant, helper functions
    ////////////////

    /// @notice How many wei can the msg.sender contribute now.
    function howMuchCanIContributeNow() view public returns (uint256) {
        return howMuchCanXContributeNow(msg.sender);
    }

    /// @notice How many wei can an ethereum address contribute now.
    /// @dev This function can return 0 when the crowdsale is stopped
    ///  or the address has maxed the current day's whitelist cap,
    ///  it is possible, that next day he can contribute
    /// @param _beneficiary Ethereum address
    /// @return Number of wei the _beneficiary can contribute now.
    function howMuchCanXContributeNow(address _beneficiary) view public returns (uint256) {
        require(_beneficiary != address(0));

        if (!hasStarted() || hasEnded()) 
            return 0;

        // wei to hard cap
        uint256 weiToCap = cap.sub(weiRaised);

        // if this is a whitelist limited period
        uint8 _saleDay = getSaleDayNow();
        if (_saleDay <= whitelistDayCount) {
            // address can't contribute if
            //  it is not whitelisted
            if (!whitelist[_beneficiary])
                return 0;

            // personal cap is the daily whitelist limit minus the stakes the address already has
            uint256 weiToPersonalCap = whitelistDayMaxStake[_saleDay].sub(stakes[_beneficiary]);

            // calculate for maxGasPrice penalty
            if (msg.value > 0 && maxGasPrice > 0 && tx.gasprice > maxGasPrice)
                weiToPersonalCap = weiToPersonalCap.mul(100).div(maxGasPricePenalty);

            weiToCap = uint256Min(weiToCap, weiToPersonalCap);
        }

        return weiToCap;
    }

    /// @notice For a give date how many 24 hour blocks have ellapsed since token sale start
    /// @dev _time has to be bigger than the startTime of token sale, otherwise SafeMath's div will throw.
    ///  Within 24 hours of token sale it will return 1, 
    ///  between 24 and 48 hours it will return 2, etc.
    /// @param _time Date in seconds for which we want to know which sale day it is
    /// @return Number of 24 hour blocks ellapsing since token sale start starting from 1
    function getSaleDay(uint256 _time) view public returns (uint8) {
        return uint8(_time.sub(startTime).div(60*60*24).add(1));
    }

    /// @notice How many 24 hour blocks have ellapsed since token sale start
    /// @return Number of 24 hour blocks ellapsing since token sale start starting from 1
    function getSaleDayNow() view public returns (uint8) {
        return getSaleDay(now);
    }

    /// @notice Minimum between two uint8 numbers
    function uint8Min(uint8 a, uint8 b) pure internal returns (uint8) {
        return a > b ? b : a;
    }

    /// @notice Minimum between two uint256 numbers
    function uint256Min(uint256 a, uint256 b) pure internal returns (uint256) {
        return a > b ? b : a;
    }


    ////////////////
    // Test and contribution web app, NO audit is needed
    ////////////////

    /// @notice Was this token sale successful?
    /// @return true if the sale is over and we have reached the minimum goal
    function wasSuccess() view public returns (bool) {
        return hasEnded() && goalReached();
    }

    /// @notice How many contributors we have.
    /// @return Number of different contributor ethereum addresses
    function getContributorsCount() view public returns (uint256) {
        return contributorsKeys.length;
    }

    /// @notice Get contributor addresses to manage refunds or token claims.
    /// @dev If the sale is not yet successful, then it searches in the RefundVault.
    ///  If the sale is successful, it searches in contributors.
    /// @param _pending If true, then returns addresses which didn't get refunded or their tokens distributed to them
    /// @param _claimed If true, then returns already refunded or token distributed addresses
    /// @return Array of addresses of contributors
    function getContributors(bool _pending, bool _claimed) view public returns (address[] contributors) {
        uint256 i = 0;
        uint256 results = 0;
        address[] memory _contributors = new address[](contributorsKeys.length);

        // if we have reached our goal, then search in contributors, since this is what we want to monitor
        if (goalReached()) {
            for (i = 0; i < contributorsKeys.length; i++) {
                if (_pending && stakes[contributorsKeys[i]] > 0 || _claimed && stakes[contributorsKeys[i]] == 0) {
                    _contributors[results] = contributorsKeys[i];
                    results++;
                }
            }
        } else {
            // otherwise search in the refund vault
            for (i = 0; i < contributorsKeys.length; i++) {
                if (_pending && vault.deposited(contributorsKeys[i]) > 0 || _claimed && vault.deposited(contributorsKeys[i]) == 0) {
                    _contributors[results] = contributorsKeys[i];
                    results++;
                }
            }
        }

        contributors = new address[](results);
        for (i = 0; i < results; i++) {
            contributors[i] = _contributors[i];
        }

        return contributors;
    }

    /// @notice How many HEAL tokens do this contract have
    function getHealBalance() view public returns (uint256) {
        return ethealController.ethealToken().balanceOf(address(this));
    }
}
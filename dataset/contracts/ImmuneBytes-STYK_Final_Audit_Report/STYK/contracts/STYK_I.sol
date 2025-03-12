pragma solidity ^0.6.0;

import "./SafeMath.sol";
import "./PriceConsumerV3.sol";
import "./DateTime.sol";

contract STYK_I is SafeMath, DateTime, PriceConsumerV3 {
    constructor(
        address _pricefeed,
        uint256 _lockTime,
        uint256 _auctionExpiryTime,
        uint256 _auctionLimit
    ) public PriceConsumerV3(_pricefeed) {
        STYK_REWARD_TOKENS = safeMul(200000, 1e18);
        MONTHLY_REWARD_TOKENS = safeMul(100000, 1e18);

        tokenBalanceLedger_[address(this)] = safeAdd(
            STYK_REWARD_TOKENS,
            MONTHLY_REWARD_TOKENS
        );
        // time lock for 100 years
        lockTime = _lockTime;
        auctionExpiryTime = _auctionExpiryTime;
        auctionEthLimit = _auctionLimit;
    }

    /*=================================
    =            MODIFIERS            =
    =================================*/
    // only people with tokens
    modifier onlybelievers() {
        require(myTokens() > 0);
        _;
    }

    // only people with profits
    modifier onlyhodler() {
        require(myDividends(true) > 0);
        _;
    }

    /*==============================
    =            EVENTS            =
    ==============================*/
    event onTokenPurchase(
        address indexed customerAddress,
        uint256 incomingEthereum,
        uint256 tokensMinted,
        address indexed referredBy
    );

    event onTokenSell(
        address indexed customerAddress,
        uint256 tokensBurned,
        uint256 ethereumEarned
    );

    event onReinvestment(
        address indexed customerAddress,
        uint256 ethereumReinvested,
        uint256 tokensMinted
    );

    event onWithdraw(
        address indexed customerAddress,
        uint256 ethereumWithdrawn
    );

    // ERC20
    event Transfer(address indexed from, address indexed to, uint256 tokens);

    /*=====================================
    =            CONFIGURABLES            =
    =====================================*/
    string public name = "STYK I";
    string public symbol = "STYK";
    uint256 public constant decimals = 18;
    uint8 internal constant dividendFee_ = 10;
    uint256 internal constant tokenPriceInitial_ = 0.0000001 ether;
    uint256 internal constant tokenPriceIncremental_ = 0.00000001 ether;
    uint256 internal constant magnitude = 2**64;
    uint256 STYK_REWARD_TOKENS;

    uint256 MONTHLY_REWARD_TOKENS;

    uint256 internal inflationTime;

    uint256 internal lockTime;
    uint56 internal userCount = 0;

    // proof of stake (defaults at 1 token)
    uint256 public stakingRequirement = 1e18;

    /*================================
    =            DATASETS            =
    ================================*/

    mapping(address => uint256) internal tokenBalanceLedger_;
    mapping(address => uint256) internal referralBalance_;
    mapping(address => bool) public rewardQualifier;
    mapping(address => uint256) internal stykRewards;
    mapping(address => address[]) internal referralUsers;
    mapping(address => mapping(address => bool)) internal userExists;
    mapping(address => bool) internal earlyadopters;
    mapping(address => bool) internal userAdded;
    mapping(address => uint256) internal userIndex;
    mapping(address => mapping(uint256 => uint256)) public monthlyRewards;
    mapping(address => int256) internal payoutsTo_;
    mapping(address => uint256) internal totalMonthRewards;
    mapping(address => uint256) internal earlyadopterBonus;
    mapping(address => uint256) internal userDeposit;

    address[] internal userAddress;
    uint256 internal tokenSupply_ = 0;
    uint256 public auctionEthLimit;
    uint256 public auctionExpiryTime;
    uint256 internal profitPerShare_;

    /**
     * Converts all incoming Ethereum to tokens for the caller, and passes down the referral address (if any)
     */
    function buy(address _referredBy) public payable returns (uint256) {
        purchaseTokens(msg.value, _referredBy);
    }

    //Cannot directly deposit ethers
    fallback() external payable {
        revert("ERR_CANNOT_FORCE_ETHERS");
    }

    //Cannot directly deposit ethers
    receive() external payable {
        revert("ERR_CANNOT_FORCE_ETHERS");
    }

    /**
     * Converts all of caller's dividends to tokens.
     */
    function reinvest() public onlyhodler() {
        // pay out the dividends virtually
        address _customerAddress = msg.sender;
        // fetch dividends
        uint256 _dividends = totalDividends(_customerAddress);
        userDeposit[_customerAddress] = 0;
        payoutsTo_[_customerAddress] += (int256)(
            _dividendsOf(_customerAddress) * magnitude
        );
        referralBalance_[_customerAddress] = 0;

        //determine whether user qualify for early adopter bonus or not
        if (earlyadopters[_customerAddress] && now > auctionExpiryTime) {
            if (balanceOf(_customerAddress) == 0) {
                earlyadopterBonus[_customerAddress] = 0;
            }
            earlyadopters[_customerAddress] = false;
        }

        //determine whether user qualify for styk bonus or not
        if (
            rewardQualifier[_customerAddress] &&
            _calculateInflationMinutes() > 4320
        ) {
            stykRewards[_customerAddress] = 0;
            rewardQualifier[_customerAddress] = false;
        }
        if (totalMonthRewards[_customerAddress] != 0) {
            totalMonthRewards[_customerAddress] = 0;
        }

        // dispatch a buy order with the virtualized "withdrawn dividends"
        uint256 _tokens = purchaseTokens(_dividends, address(0));

        // fire event
        emit onReinvestment(_customerAddress, _dividends, _tokens);
    }

    /**
     * Alias of sell() and withdraw().
     */
    function exit() public {
        // get token count for caller & sell them all
        address _customerAddress = msg.sender;
        uint256 _tokens = tokenBalanceLedger_[_customerAddress];

        if (_tokens > 0) sell(_tokens);

        withdraw();
        userAdded[_customerAddress] = false;

        uint256 index = getUserAddressIndex(_customerAddress);
        userAddress[index] = address(0);
    }

    /**
     * Withdraws all of the callers earnings.
     */
    function withdraw() public onlyhodler() {
        // setup data
        address payable _customerAddress = msg.sender;
        uint256 _dividends = totalDividends(_customerAddress);

        userDeposit[_customerAddress] = 0;
        // update dividend tracker
        payoutsTo_[_customerAddress] += (int256)(
            _dividendsOf(_customerAddress) * magnitude
        );
        referralBalance_[_customerAddress] = 0;

        //determine whether user qualify for early adopter bonus or not
        if (earlyadopters[_customerAddress] && now > auctionExpiryTime) {
            if (balanceOf(_customerAddress) == 0) {
                earlyadopterBonus[_customerAddress] = 0;
            }
            earlyadopters[_customerAddress] = false;
        }

        //determine whether user qualify for styk bonus or not
        if (
            rewardQualifier[_customerAddress] &&
            _calculateInflationMinutes() > 4320
        ) {
            stykRewards[_customerAddress] = 0;
            rewardQualifier[_customerAddress] = false;
        }
        if (totalMonthRewards[_customerAddress] != 0) {
            totalMonthRewards[_customerAddress] = 0;
        }
        // delivery service
        _customerAddress.transfer(_dividends);

        // fire event
        emit onWithdraw(_customerAddress, _dividends);
    }

    /**
     * Liquifies tokens to ethereum.
     */
    function sell(uint256 _amountOfTokens) public onlybelievers() {
        address _customerAddress = msg.sender;

        // require(now > auctionExpiryTime,"ERR_CANNOT_SELL_TOKENS_BEFORE_AUCTION");

        require(_amountOfTokens <= tokenBalanceLedger_[_customerAddress]);

        uint256 _tokens = _amountOfTokens;
        uint256 _ethereum = tokensToEthereum_(_tokens);
        uint256 _dividends = safeDiv(_ethereum, dividendFee_);
        uint256 _taxedEthereum = safeSub(_ethereum, _dividends);

        if (balanceOf(_customerAddress) == _amountOfTokens) {
            if (earlyadopters[_customerAddress]) {
                earlyadopterBonus[_customerAddress] = earlyAdopterBonus(
                    _customerAddress
                );
            }
            if (rewardQualifier[_customerAddress]) {
                stykRewards[_customerAddress] = STYKRewards(_customerAddress);
            }
        }

        // burn the sold tokens
        tokenSupply_ = safeSub(tokenSupply_, _tokens);
        tokenBalanceLedger_[_customerAddress] = safeSub(
            tokenBalanceLedger_[_customerAddress],
            _tokens
        );
        // update dividends tracker
        int256 _updatedPayouts = (int256)(profitPerShare_ * _tokens);
        payoutsTo_[_customerAddress] -= _updatedPayouts;

        // dividing by zero is a bad idea
        if (tokenSupply_ > 0) {
            // update the amount of dividends per token
            profitPerShare_ = safeAdd(
                profitPerShare_,
                (_dividends * magnitude) /
                    safeAdd(tokenSupply_, balanceOf(address(this)))
            );
        }

        if (_calculateMonthlyRewards(_customerAddress) > 0) {
            monthlyRewards[_customerAddress][
                getMonth(now)
            ] = _calculateMonthlyRewards(_customerAddress);
        }

        userDeposit[_customerAddress] = safeAdd(
            userDeposit[_customerAddress],
            _taxedEthereum
        );

        setInflationTime();

        // fire events
        emit onTokenSell(_customerAddress, _tokens, _taxedEthereum);
    }

    function setStakingRequirement(uint256 _amountOfTokens) public {
        stakingRequirement = _amountOfTokens;
    }

    function setName(string memory _name) public {
        name = _name;
    }

    function setSymbol(string memory _symbol) public {
        symbol = _symbol;
    }

    /*----------  HELPERS AND CALCULATORS  ----------*/
    /**
     * Method to view the current Ethereum stored in the contract
     * Example: totalEthereumBalance()
     */
    function totalEthereumBalance() public view returns (uint256) {
        return address(this).balance;
    }

    /**
     * Retrieve the total token supply.
     */
    function totalSupply() public view returns (uint256) {
        return tokenSupply_;
    }

    /**
     * Retrieve the tokens owned by the caller.
     */
    function myTokens() public view returns (uint256) {
        address _customerAddress = msg.sender;
        return balanceOf(_customerAddress);
    }

    /**
     * Retrieve the dividends owned by the caller.
     */
    function myDividends(bool _includeReferralBonus)
        public
        view
        returns (uint256)
    {
        address _customerAddress = msg.sender;
        return
            _includeReferralBonus
                ? _dividendsOf(_customerAddress) +
                    referralBalance_[_customerAddress]
                : _dividendsOf(_customerAddress);
    }

    /**
     * Retrieve the token balance of any single address.
     */
    function balanceOf(address _customerAddress) public view returns (uint256) {
        return tokenBalanceLedger_[_customerAddress];
    }

    /**
     * Retrieve the dividend balance of any single address.
     */
    function _dividendsOf(address _customerAddress)
        public
        view
        returns (uint256)
    {
        return
            safeAdd(
                (uint256)(
                    (int256)(
                        profitPerShare_ *
                            (tokenBalanceLedger_[_customerAddress])
                    ) - payoutsTo_[_customerAddress]
                ) / magnitude,
                userDeposit[_customerAddress]
            );
    }

    /**
     * Return the buy price of 1 individual token.
     */
    function sellPrice() external view returns (uint256) {
        if (tokenSupply_ == 0) {
            return tokenPriceInitial_ - tokenPriceIncremental_;
        } else {
            uint256 _ethereum = tokensToEthereum_(1e18);
            uint256 _dividends = safeDiv(_ethereum, dividendFee_);
            uint256 _taxedEthereum = safeSub(_ethereum, _dividends);
            return _taxedEthereum;
        }
    }

    /**
     * Return the sell price of 1 individual token.
     */
    function buyPrice() public view returns (uint256) {
        if (tokenSupply_ == 0) {
            return tokenPriceInitial_ + tokenPriceIncremental_;
        } else {
            uint256 _ethereum = tokensToEthereum_(1e18);
            uint256 _dividends = safeDiv(_ethereum, dividendFee_);
            uint256 _taxedEthereum = safeAdd(_ethereum, _dividends);
            return _taxedEthereum;
        }
    }

    function calculateTokensReceived(uint256 _ethereumToSpend)
        external
        view
        returns (uint256)
    {
        uint256 _dividends = safeDiv(_ethereumToSpend, dividendFee_);
        uint256 _taxedEthereum = safeSub(_ethereumToSpend, _dividends);
        uint256 _amountOfTokens = ethereumToTokens_(_taxedEthereum);
        return _amountOfTokens;
    }

    function calculateEthereumReceived(uint256 _tokensToSell)
        external
        view
        returns (uint256)
    {
        require(_tokensToSell <= tokenSupply_);
        uint256 _ethereum = tokensToEthereum_(_tokensToSell);
        uint256 _dividends = safeDiv(_ethereum, dividendFee_);
        uint256 _taxedEthereum = safeSub(_ethereum, _dividends);
        return _taxedEthereum;
    }

    /*==========================================
    =            Methods Developed By Minddeft    =
    ==========================================*/

    function _inflation() internal view returns (uint256) {
        uint256 buyPrice_ = buyPrice();
        uint256 ethPrice = safeMul(getLatestPrice(), 1e10);
        uint256 inflation_factor = safeDiv(safeMul(buyPrice_, 10000), ethPrice);
        return inflation_factor;
    }

    // chainlink already give data as 10**8 so convert to 18 decimal
    function checkInflation() external view returns (uint256) {
        return _inflation();
    }

    //To set inflationTime when inflation factor reaches 2% of ethereum
    function setInflationTime() internal {
        if (_inflation() >= 200) {
            inflationTime = now;
        }
    }

    //To calculate Inflation minutes (72 hours converted into minutes)
    function _calculateInflationMinutes() internal view returns (uint256) {
        if (inflationTime == 0) {
            return 0;
        }
        return safeDiv(safeSub(now, inflationTime), 60);
    }

    function calculateInflationMinutes() external view returns (uint256) {
        return _calculateInflationMinutes();
    }

    //To calculate Token Percentage
    function _calculateTokenPercentage(address _customerAddress)
        internal
        view
        returns (uint256)
    {
        if (balanceOf(_customerAddress) > 0) {
            uint256 token_percent =
                safeDiv(
                    safeMul(balanceOf(_customerAddress), 1000000),
                    totalSupply()
                );
            return token_percent;
        }
        return 0;
    }

    //To calculate Token Percentage
    function calculateTokenPercentage(address _customerAddress)
        external
        view
        returns (uint256)
    {
        return _calculateTokenPercentage(_customerAddress);
    }

    //To calculate user's STYK rewards
    function _calculateSTYKReward(address _customerAddress)
        internal
        view
        returns (uint256)
    {
        if (now > auctionExpiryTime) {
            uint256 token_percent = _calculateTokenPercentage(_customerAddress);
            if (token_percent > 0) {
                uint256 rewards =
                    safeDiv(
                        safeMul(
                            _dividendsOfPremintedTokens(STYK_REWARD_TOKENS),
                            token_percent
                        ),
                        1000000
                    );
                return rewards;
            }
            return 0;
        }
        return 0;
    }

    function calculateSTYKReward(address _customerAddress)
        external
        view
        returns (uint256)
    {
        return _calculateSTYKReward(_customerAddress);
    }

    //To activate deflation
    function deflationSell() external {
        uint256 inflationMinutes = _calculateInflationMinutes();
        require(
            inflationMinutes <= 4320,
            "ERR_INFLATION_MINUTES_SHOULD_BE_LESS_THAN_4320"
        );

        require(!rewardQualifier[msg.sender], "ERR_REWARD_ALREADY_CLAIMED");

        if (_calculateSTYKReward(msg.sender) > 0) {
            uint256 rewards = _calculateSTYKReward(msg.sender);

            stykRewards[msg.sender] = safeAdd(stykRewards[msg.sender], rewards);

            uint256 userToken =
                safeDiv(safeMul(balanceOf(msg.sender), 25), 100);
            rewardQualifier[msg.sender] = true;
            sell(userToken);
        }
    }

    //To accumulate rewards of non qualifying after deflation sell
    function _deflationAccumulatedRewards() internal view returns (uint256) {
        uint256 stykRewardPoolBalance = 0;

        for (uint256 i = 0; i < userAddress.length; i++) {
            if (userAddress[i] != address(0)) {
                address _user = userAddress[i];
                if (!rewardQualifier[_user]) {
                    stykRewardPoolBalance = safeAdd(
                        _calculateSTYKReward(_user),
                        stykRewardPoolBalance
                    );
                }
            }
        }
        return stykRewardPoolBalance;
    }

    //To pay STYK Rewards
    function STYKRewards(address _to) internal view returns (uint256) {
        if (_calculateTokenPercentage(_to) > 0) {
            uint256 _rewards = stykRewards[_to];
            uint256 accumulatedRewards =
                safeMul(
                    _deflationAccumulatedRewards(),
                    _calculateTokenPercentage(_to)
                );
            uint256 finalRewards = safeAdd(_rewards, accumulatedRewards);
            return finalRewards;
        }
        return 0;
    }

    //To calculate team token holder percent
    function _teamTokenHolder(address _to) internal view returns (uint256) {
        uint256 useractivecount = 0;
        uint256 usertotaltokens = 0;

        for (uint256 i = 0; i < referralUsers[_to].length; i++) {
            address _userAddress = referralUsers[_to][i];
            if (_checkUserActiveStatus(_userAddress)) {
                ++useractivecount;
            }
        }

        if (useractivecount >= 3) {
            for (uint256 i = 0; i < referralUsers[_to].length; i++) {
                address _addr = referralUsers[_to][i];
                usertotaltokens = safeAdd(balanceOf(_addr), usertotaltokens);
            }
            return safeDiv(safeMul(usertotaltokens, 1000000), totalSupply());
        } else {
            return 0;
        }
    }

    function teamTokenHolder(address _to) external view returns (uint256) {
        return _teamTokenHolder(_to);
    }

    // To calculate monthly  rewards
    function _calculateMonthlyRewards(address _to)
        internal
        view
        returns (uint256)
    {
        uint256 token_percent = _teamTokenHolder(_to);
        if (token_percent != 0) {
            uint256 rewards =
                safeDiv(
                    safeMul(
                        _dividendsOfPremintedTokens(MONTHLY_REWARD_TOKENS),
                        token_percent
                    ),
                    1000000
                );

            return rewards;
        }
        return 0;
    }

    function calculateMonthlyRewards(address _to)
        external
        view
        returns (uint256)
    {
        return _calculateMonthlyRewards(_to);
    }

    // To check the user's  status
    function _checkUserActiveStatus(address _user)
        internal
        view
        returns (bool)
    {
        if (balanceOf(_user) > safeMul(10, 1e18)) {
            return true;
        } else {
            return false;
        }
    }

    //To distribute rewards to early adopters
    function earlyAdopterBonus(address _user) internal view returns (uint256) {
        if (balanceOf(_user) > 0) {
            uint256 token_percent = _calculateTokenPercentage(_user);
            uint256 rewards =
                safeDiv(
                    safeMul(
                        _dividendsOfPremintedTokens(
                            tokenBalanceLedger_[address(this)]
                        ),
                        token_percent
                    ),
                    1000000
                );
            return rewards;
        }
        return 0;
    }

    //To get user affiliate rewards
    function getUserAffiliateBalance(address _user)
        external
        view
        returns (uint256)
    {
        return referralBalance_[_user];
    }

    //To retrieve the index of user's address
    function getUserAddressIndex(address _customerAddress)
        internal
        view
        returns (uint256)
    {
        uint256 index = userIndex[_customerAddress];
        if (userAddress[index] == _customerAddress) {
            return index;
        }
    }

    /**
     * Retrieve the dividends from pre-minted tokens.
     */
    function _dividendsOfPremintedTokens(uint256 _tokens)
        internal
        view
        returns (uint256)
    {
        return (uint256)((int256)(profitPerShare_ * _tokens)) / magnitude;
    }

    //To calculate total dividends of user
    function totalDividends(address _customerAddress)
        public
        view
        returns (uint256)
    {
        uint256 _dividends = _dividendsOf(_customerAddress);

        uint256 qualifying_rewards;
        if (earlyadopters[_customerAddress] && now > auctionExpiryTime) {
            if (balanceOf(_customerAddress) > 0) {
                qualifying_rewards = safeAdd(
                    qualifying_rewards,
                    earlyAdopterBonus(_customerAddress)
                );
            } else {
                qualifying_rewards = safeAdd(
                    qualifying_rewards,
                    earlyadopterBonus[_customerAddress]
                );
            }
        }
        if (
            rewardQualifier[_customerAddress] &&
            _calculateInflationMinutes() > 4320
        ) {
            if (balanceOf(_customerAddress) > 0) {
                qualifying_rewards = safeAdd(
                    qualifying_rewards,
                    STYKRewards(_customerAddress)
                );
            } else {
                qualifying_rewards = safeAdd(
                    qualifying_rewards,
                    stykRewards[_customerAddress]
                );
            }
        }

        if (totalMonthRewards[_customerAddress] != 0) {
            qualifying_rewards = safeAdd(
                qualifying_rewards,
                totalMonthRewards[_customerAddress]
            );
        }

        return (
            safeAdd(
                safeAdd(_dividends, qualifying_rewards),
                referralBalance_[_customerAddress]
            )
        );
    }

    //To Claim Monthly Rewards
    function claimMonthlyRewards() external {
        address _customerAddress = msg.sender;
        uint256 month = safeSub(getMonth(now), 1);
        if (month == 0) month = 12;
        if (monthlyRewards[_customerAddress][month] != 0) {
            totalMonthRewards[_customerAddress] = safeAdd(
                totalMonthRewards[_customerAddress],
                monthlyRewards[_customerAddress][month]
            );
            monthlyRewards[_customerAddress][month] = 0;
        }
        if ((getDay(now) == getDaysInMonth(getMonth(now), getYear(now)))) {
            if (monthlyRewards[_customerAddress][getMonth(now)] != 0) {
                totalMonthRewards[_customerAddress] = safeAdd(
                    totalMonthRewards[_customerAddress],
                    monthlyRewards[_customerAddress][getMonth(now)]
                );
                monthlyRewards[_customerAddress][getMonth(now)] = 0;
            }
        }
    }

    /*==========================================
    =            INTERNAL FUNCTIONS            =
    ==========================================*/
    function purchaseTokens(uint256 _incomingEthereum, address _referredBy)
        internal
        returns (uint256)
    {
        // data setup
        address _customerAddress = msg.sender;
        uint256 _undividedDividends = safeDiv(_incomingEthereum, dividendFee_);
        uint256 _referralBonus = safeDiv(_undividedDividends, 2);
        uint256 _dividends = safeSub(_undividedDividends, _referralBonus);
        uint256 _taxedEthereum =
            safeSub(_incomingEthereum, _undividedDividends);
        uint256 _amountOfTokens = ethereumToTokens_(_taxedEthereum);
        uint256 _fee = _dividends * magnitude;

        require(
            _amountOfTokens > 0 &&
                (safeAdd(_amountOfTokens, tokenSupply_) > tokenSupply_)
        );

        // is the user referred by a karmalink?
        if (
            _referredBy != address(0) &&
            // no cheating!
            _referredBy != _customerAddress &&
            tokenBalanceLedger_[_referredBy] >= stakingRequirement
        ) {
            // wealth redistribution
            referralBalance_[_referredBy] = safeAdd(
                referralBalance_[_referredBy],
                _referralBonus
            );
        } else {
            // no ref purchase
            // add the referral bonus back to the global dividends cake
            _dividends = safeAdd(_dividends, _referralBonus);
            _fee = _dividends * magnitude;
        }

        // add tokens to the pool
        tokenSupply_ = safeAdd(tokenSupply_, _amountOfTokens);

        // take the amount of dividends gained through this transaction, and allocates them evenly to each shareholder
        profitPerShare_ += ((_dividends * magnitude) /
            safeAdd(tokenSupply_, balanceOf(address(this))));

        // calculate the amount of tokens the customer receives over his purchase
        _fee =
            _fee -
            (_fee -
                (_amountOfTokens *
                    ((_dividends * magnitude) /
                        safeAdd(tokenSupply_, balanceOf(address(this))))));

        // update circulating supply & the ledger address for the customer
        tokenBalanceLedger_[_customerAddress] = safeAdd(
            tokenBalanceLedger_[_customerAddress],
            _amountOfTokens
        );

        int256 _updatedPayouts =
            (int256)((profitPerShare_ * _amountOfTokens) - _fee);
        payoutsTo_[_customerAddress] += _updatedPayouts;

        if (
            now > auctionExpiryTime || totalEthereumBalance() >= auctionEthLimit
        ) {
            if (
                !userExists[_referredBy][_customerAddress] &&
                _referredBy != address(0) &&
                _referredBy != _customerAddress
            ) {
                userExists[_referredBy][_customerAddress] = true;
                referralUsers[_referredBy].push(_customerAddress);
            }
        }

        if (now <= auctionExpiryTime) {
            if (
                totalEthereumBalance() <= auctionEthLimit &&
                safeAdd(totalEthereumBalance(), _incomingEthereum) <=
                auctionEthLimit
            ) {
                if (!earlyadopters[_customerAddress]) {
                    earlyadopters[_customerAddress] = true;
                }
            }
        }

        if (!userAdded[_customerAddress]) {
            userAddress.push(_customerAddress);
            userAdded[_customerAddress] = true;
            userIndex[_customerAddress] = userCount;
            userCount++;
        }

        if (_calculateMonthlyRewards(_referredBy) > 0) {
            monthlyRewards[_referredBy][
                getMonth(now)
            ] = _calculateMonthlyRewards(_referredBy);
        }

        // fire event
        emit onTokenPurchase(
            _customerAddress,
            _incomingEthereum,
            _amountOfTokens,
            _referredBy
        );
        setInflationTime();
        emit Transfer(address(this), _customerAddress, _amountOfTokens);

        return _amountOfTokens;
    }

    /**
     * Calculate Token price based on an amount of incoming ethereum
     * It's an algorithm, hopefully we gave you the whitepaper with it in scientific notation;
     * Some conversions occurred to prevent decimal errors or underflows / overflows in solidity code.
     */
    function ethereumToTokens_(uint256 _ethereum)
        internal
        view
        returns (uint256)
    {
        uint256 _tokenPriceInitial = tokenPriceInitial_ * 1e18;
        uint256 _tokensReceived =
            ((
                // underflow attempts BTFO
                safeSub(
                    (
                        sqrt(
                            (_tokenPriceInitial**2) +
                                (2 *
                                    (tokenPriceIncremental_ * 1e18) *
                                    (_ethereum * 1e18)) +
                                (((tokenPriceIncremental_)**2) *
                                    (tokenSupply_**2)) +
                                (2 *
                                    (tokenPriceIncremental_) *
                                    _tokenPriceInitial *
                                    tokenSupply_)
                        )
                    ),
                    _tokenPriceInitial
                )
            ) / (tokenPriceIncremental_)) - (tokenSupply_);

        return _tokensReceived;
    }

    /**
     * Calculate token sell value.
     */
    function tokensToEthereum_(uint256 _tokens)
        internal
        view
        returns (uint256)
    {
        uint256 tokens_ = (_tokens + 1e18);
        uint256 _tokenSupply = (tokenSupply_ + 1e18);
        uint256 _etherReceived =
            (// underflow attempts BTFO
            safeSub(
                (((tokenPriceInitial_ +
                    (tokenPriceIncremental_ * (_tokenSupply / 1e18))) -
                    tokenPriceIncremental_) * (tokens_ - 1e18)),
                (tokenPriceIncremental_ * ((tokens_**2 - tokens_) / 1e18)) / 2
            ) / 1e18);
        return _etherReceived;
    }

    function sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}

/*==============================================================================================================
                                       CREDITS        
    
     credit goes to POWH, GANDHIJI & HEX smart contracts" All charity work is inspired by BI Phakathi (Youtuber)
     
==============================================================================================================*/

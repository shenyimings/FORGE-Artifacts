// SPDX-License-Identifier: MIT
pragma solidity =0.8.11;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title JamonShareVault
 * @notice Profit sharing pool on the JamonShare tokens deposited in stake. It distributes the tokens received based on the number of tokens staked in each wallet.
 */
contract JamonShareVault is ReentrancyGuard, Pausable, Ownable {
    //---------- Libraries ----------//
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.AddressSet;

    //---------- Contracts ----------//
    IERC20 private JamonShare; // JamonShare token contract.

    //---------- Variables ----------//
    Counters.Counter public totalHolders; // Total wallets in stake.
    EnumerableSet.AddressSet internal validTokens; // Address map of valid tokens.
    address private JamonV2; // Address of JamonV2 contract.
    address public Governor; // Addres of Governor contract.
    uint256 constant month = 2629743; // 1 Month Timestamp.
    uint256 public totalStaked; // Total balance in stake.
    uint256 public lastUpdated; // Date in timestamp of the last balances update.

    //---------- Storage -----------//
    struct Wallet {
        // Tokens amount staked.
        uint256 stakedBal;
        // Dame in timestamp of the stake started.
        uint256 startTime;
        // Uint256 map of shared points.
        mapping(address => uint256) tokenPoints;
        // Uint256 map of pending rewards.
        mapping(address => uint256) pendingTokenbal;
        // Boolean to know if in stake.
        bool inStake;
    }

    mapping(address => Wallet) private stakeHolders; // Struct map of wallets in stake.
    mapping(address => uint256) private TokenPoints; // Uint256 map of shared points per tokens.
    mapping(address => uint256) private UnclaimedToken; // Uint256 map for store the tokens not claimed.
    mapping(address => uint256) private ProcessedToken; // Uit256 map for store the processed tokens.

    //---------- Events -----------//
    event Deposit(address indexed payee, uint256 amount, uint256 totalStaked);
    event Withdrawn(address indexed payee, uint256 amount);
    event Staked(address indexed wallet, uint256 amount);
    event UnStaked(address indexed wallet, uint256 amount);

    //---------- Constructor ----------//
    constructor(
        address jamonShare_,
        address jamonV2_,
        address governor_
    ) {
        JamonShare = IERC20(jamonShare_);
        JamonV2 = jamonV2_;
        Governor = governor_;
        validTokens.add(jamonShare_);
        validTokens.add(jamonV2_);
    }

    //---------- Deposits -----------//
    /**
     * @dev Deposit and distribute permitted tokens.
     * @param token_ address of the token contract.
     * @param from_ address of the spender.
     * @param amount_ amount of tokens to distribute.
     */
    function depositTokens(
        address token_,
        address from_,
        uint256 amount_
    ) external nonReentrant {
        require(amount_ > 0, "Tokens too low");
        require(validTokens.contains(token_), "Invalid token");
        require(
            IERC20(token_).transferFrom(from_, address(this), amount_),
            "Transfer tokens error"
        );
        _disburseToken(token_, amount_);
    }

    //----------- Internal Functions -----------//
    /**
     * @dev Distribute permitted tokens.
     * @param token_ address of the token contract.
     * @param amount_ amount of tokens to distribute.
     */
    function _disburseToken(address token_, uint256 amount_) internal {
        if (totalStaked > 1000000 && amount_ >= 1000000) {
            TokenPoints[token_] = TokenPoints[token_].add(
                (amount_.mul(10e18)).div(totalStaked)
            );
            UnclaimedToken[token_] = UnclaimedToken[token_].add(amount_);
            emit Deposit(_msgSender(), amount_, totalStaked);
        }
    }

    /**
     * @dev Calculates the tokens pending distribution and distributes them if there is an undistributed amount.
     */
    function _recalculateBalances() internal virtual {
        uint256 tokensCount = validTokens.length();
        for (uint256 i = 0; i < tokensCount; i++) {
            address token = validTokens.at(i);
            uint256 balance = token == address(JamonShare)
                ? IERC20(token).balanceOf(address(this)).sub(totalStaked)
                : IERC20(token).balanceOf(address(this));
            uint256 processed = UnclaimedToken[token].add(
                ProcessedToken[token]
            );
            if (balance > processed) {
                uint256 pending = balance.sub(processed);
                if (pending > 1000000) {
                    _disburseToken(token, pending);
                }
            }
        }
    }

    /**
     * @dev Calculates a specific token pending distribution and distributes it if there is an undistributed amount.
     * @param token_ address of the token to calculate.
     */
    function _recalculateTokenBalance(address token_) internal virtual {
        uint256 balance = IERC20(token_).balanceOf(address(this));
        uint256 processed = UnclaimedToken[token_].add(ProcessedToken[token_]);
        if (balance > processed) {
            uint256 pending = balance.sub(processed);
            if (pending > 1000000) {
                _disburseToken(token_, pending);
            }
        }
    }

    /**
     * @dev Process pending rewards from a wallet.
     * @param wallet_ address of the wallet to be processed.
     */
    function _processWalletTokens(address wallet_) internal virtual {
        uint256 tokensCount = validTokens.length();
        for (uint256 i = 0; i < tokensCount; i++) {
            address token = validTokens.at(i);
            _processRewardsToken(token, wallet_);
        }
    }

    /**
     * @dev Process pending rewards from a wallet in a particular token.
     * @param token_ address of the token to process.
     * @param wallet_ address of the wallet to be processed.
     */
    function _processRewardsToken(address token_, address wallet_)
        internal
        virtual
    {
        uint256 rewards = getRewardsToken(token_, wallet_);
        if (rewards > 0) {
            UnclaimedToken[token_] = UnclaimedToken[token_].sub(rewards);
            ProcessedToken[token_] = ProcessedToken[token_].add(rewards);
            stakeHolders[wallet_].tokenPoints[token_] = TokenPoints[token_];
            stakeHolders[wallet_].pendingTokenbal[token_] = stakeHolders[
                wallet_
            ].pendingTokenbal[token_].add(rewards);
        }
    }

    /**
     * @dev Withdraw pending rewards of a specific token from a wallet.
     * @param token_ address of the token to withdraw.
     * @param wallet_ address of the wallet to withdraw.
     */
    function _harvestToken(address token_, address wallet_) internal virtual {
        _processRewardsToken(token_, wallet_);
        uint256 amount = stakeHolders[wallet_].pendingTokenbal[token_];
        if (amount > 0) {
            stakeHolders[wallet_].pendingTokenbal[token_] = 0;
            ProcessedToken[token_] = ProcessedToken[token_].sub(amount);
            IERC20(token_).transfer(wallet_, amount);
            emit Withdrawn(wallet_, amount);
        }
    }

    /**
     * @dev Withdraw pending rewards of all tokens from a wallet.
     * @param wallet_ address of the wallet to withdraw.
     */
    function _harvestAll(address wallet_) internal virtual {
        _processWalletTokens(wallet_);
        uint256 tokensCount = validTokens.length();
        for (uint256 i = 0; i < tokensCount; i++) {
            address token = validTokens.at(i);
            uint256 amount = stakeHolders[wallet_].pendingTokenbal[token];
            if (amount > 0) {
                stakeHolders[wallet_].pendingTokenbal[token] = 0;
                ProcessedToken[token] = ProcessedToken[token].sub(amount);
                IERC20(token).transfer(wallet_, amount);
                emit Withdrawn(wallet_, amount);
            }
        }
    }

    /**
     * @dev Initialize a wallet joined with the current participation points.
     * @param wallet_ address of the wallet to initialize.
     */
    function _initWalletPoints(address wallet_) internal virtual {
        uint256 tokensCount = validTokens.length();
        Wallet storage w = stakeHolders[wallet_];
        for (uint256 i = 0; i < tokensCount; i++) {
            address token = validTokens.at(i);
            w.tokenPoints[token] = TokenPoints[token];
        }
    }

    /**
     * @dev Add a wallet to stake for the first time.
     * @param wallet_ address of the wallet to add.
     * @param amount_ amount to add.
     */
    function _initStake(address wallet_, uint256 amount_)
        internal
        virtual
        returns (bool)
    {
        _recalculateBalances();
        _initWalletPoints(wallet_);
        bool success = JamonShare.transferFrom(wallet_, address(this), amount_);
        stakeHolders[wallet_].startTime = block.timestamp;
        stakeHolders[wallet_].inStake = true;
        stakeHolders[wallet_].stakedBal = amount_;
        totalStaked = totalStaked.add(amount_);
        totalHolders.increment();
        return success;
    }

    /**
     * @dev Add more tokens to stake from an existing wallet.
     * @param wallet_ address of the wallet.
     * @param amount_ amount to add.
     */
    function _addStake(address wallet_, uint256 amount_)
        internal
        virtual
        returns (bool)
    {
        _recalculateBalances();
        _processWalletTokens(wallet_);
        bool success = JamonShare.transferFrom(wallet_, address(this), amount_);
        stakeHolders[wallet_].stakedBal = stakeHolders[wallet_].stakedBal.add(
            amount_
        );
        totalStaked = totalStaked.add(amount_);

        return success;
    }

    /**
     * @dev Calculates the penalty for unstake based on the time you have in stake. Being a penalty of 1% on the balance per month in advance before a year.
     * @param wallet_ address of the wallet.
     * @return the amount of tokens to receive.
     */
    function _unStakeBal(address wallet_) internal virtual returns (uint256) {
        uint256 accumulated = block.timestamp.sub(
            stakeHolders[wallet_].startTime
        );
        uint256 balance = stakeHolders[wallet_].stakedBal;
        uint256 minPercent = 88;
        if (accumulated >= month.mul(12)) {
            return balance;
        }
        balance = balance.mul(10e18);
        if (accumulated < month) {
            balance = (balance.mul(minPercent)).div(100);
            return balance.div(10e18);
        }
        for (uint256 m = 1; m < 12; m++) {
            if (accumulated >= month.mul(m) && accumulated < month.mul(m + 1)) {
                minPercent = minPercent.add(m);
                balance = (balance.mul(minPercent)).div(100);
                return balance.div(10e18);
            }
        }
        return 0;
    }

    //----------- External Functions -----------//
    /**
     * @notice Check if a wallet address is in stake.
     * @return Boolean if in stake or not.
     */
    function isInStake(address wallet_) external view returns (bool) {
        return stakeHolders[wallet_].inStake;
    }

    /**
     * @notice Check the reward amount of a specific token.
     * @param token_ Address of token to check.
     * @param wallet_ Address of the wallet to check.
     * @return Amount of reward for that token.
     */
    function getRewardsToken(address token_, address wallet_)
        public
        view
        returns (uint256)
    {
        uint256 newTokenPoints = TokenPoints[token_].sub(
            stakeHolders[wallet_].tokenPoints[token_]
        );
        return (stakeHolders[wallet_].stakedBal.mul(newTokenPoints)).div(10e18);
    }

    /**
     * @notice Check the reward amount of a specific token plus the processed balance.
     * @param token_ Address of token to check.
     * @param wallet_ Address of the wallet to check.
     * @return Amount of reward plus the processed for that token.
     */
    function getPendingBal(address token_, address wallet_)
        external
        view
        returns (uint256)
    {
        uint256 newTokenPoints = TokenPoints[token_].sub(
            stakeHolders[wallet_].tokenPoints[token_]
        );
        uint256 pending = stakeHolders[wallet_].pendingTokenbal[token_];
        return
            (stakeHolders[wallet_].stakedBal.mul(newTokenPoints))
                .div(10e18)
                .add(pending);
    }

    /**
     * @notice Check the info of stake for a wallet.
     * @param wallet_ Address of the wallet to check.
     * @return stakedBal amount of tokens staked.
     * @return startTime date in timestamp of the stake started.
     */
    function getWalletInfo(address wallet_)
        public
        view
        returns (uint256 stakedBal, uint256 startTime)
    {
        Wallet storage w = stakeHolders[wallet_];
        return (w.stakedBal, w.startTime);
    }

    /**
     * @notice Check if you have rewards for claiming or not.
     * @return If have rewards.
     */
    function pendingBalances() public view returns (bool) {
        uint256 tokensCount = validTokens.length();
        for (uint256 i = 0; i < tokensCount; i++) {
            address token = validTokens.at(i);
            uint256 balance = token == address(JamonShare)
                ? IERC20(token).balanceOf(address(this)).sub(totalStaked)
                : IERC20(token).balanceOf(address(this));
            uint256 processed = UnclaimedToken[token].add(
                ProcessedToken[token]
            );
            if (balance > processed) {
                uint256 pending = balance.sub(processed);
                if (pending > 1000000) {
                    return true;
                }
            }
        }
        return false;
    }

    /**
     * @notice Stake tokens to receive rewards.
     * @param amount_ Amount of tokens to deposit.
     */
    function stake(uint256 amount_) external whenNotPaused nonReentrant {
        require(amount_ > 1000000, "Amount too low");
        require(
            JamonShare.allowance(_msgSender(), address(this)) >= amount_,
            "Amount not allowed"
        );

        if (stakeHolders[_msgSender()].inStake) {
            require(_addStake(_msgSender(), amount_), "Add stake error");
        } else {
            require(_initStake(_msgSender(), amount_), "Init stake error");
        }
        emit Staked(_msgSender(), amount_);
    }

    /**
     * @notice Withdraw rewards from a specific token.
     * @param token_ address of tokens to withdraw.
     */
    function harvestToken(address token_) external whenNotPaused nonReentrant {
        require(stakeHolders[_msgSender()].inStake, "Not in stake");
        require(validTokens.contains(token_), "Invalid token");
        _harvestToken(token_, _msgSender());
    }

    /**
     * @notice Withdraw rewards from all tokens.
     */
    function harvestAll() external whenNotPaused nonReentrant {
        require(stakeHolders[_msgSender()].inStake, "Not in stake");
        _harvestAll(_msgSender());
    }

    /**
     * @notice Withdraw stake tokens and collect rewards.
     */
    function unStake() external whenNotPaused nonReentrant {
        require(stakeHolders[_msgSender()].inStake, "Not in stake");
        _harvestAll(_msgSender());
        uint256 stakedBal = stakeHolders[_msgSender()].stakedBal;
        uint256 balance = _unStakeBal(_msgSender());
        uint256 balanceDiff = stakedBal.sub(balance);
        if (balance > 0) {
            require(
                JamonShare.transfer(_msgSender(), balance),
                "Transfer error"
            );
        }
        totalStaked = totalStaked.sub(stakedBal);
        delete stakeHolders[_msgSender()];
        totalHolders.decrement();
        if (balanceDiff > 0) {
            require(
                JamonShare.transfer(Governor, balanceDiff),
                "Transfer error"
            ); 
        }
        emit UnStaked(_msgSender(), balance);
    }

    /**
     * @notice Safely withdraw staking tokens without collecting rewards.
     */
    function safeUnStake() external whenPaused nonReentrant {
        require(stakeHolders[_msgSender()].inStake, "Not in stake");
        uint256 stakedBal = stakeHolders[_msgSender()].stakedBal;
        delete stakeHolders[_msgSender()];
        require(JamonShare.transfer(_msgSender(), stakedBal), "Transfer error");
        totalStaked = totalStaked.sub(stakedBal);
        totalHolders.decrement();
    }

    /**
     * @notice Update balances pending distribution if any.
     */
    function updateBalances() external whenNotPaused nonReentrant {
        if (lastUpdated.add(1 days) < block.timestamp) {
            _recalculateBalances();
            lastUpdated = block.timestamp;
        }
    }

    /**
     * @notice Updates the balances pending distribution of a specific token in case there are any.
     * @param token_ address of token for update the pending balance.
     */
    function updateTokenBalance(address token_) external onlyOwner {
        require(validTokens.contains(token_), "Invalid token");
        _recalculateTokenBalance(token_);
    }

    /**
     * @notice Modify the list of valid tokens.
     * @param token_ address of token to add on list.
     * @param add_ boolean to enable or disable the token.
     */
    function setTokenList(address token_, bool add_) external onlyOwner {
        require(
            token_ != address(0) &&
                token_ != address(JamonShare) &&
                token_ != JamonV2,
            "Invalid token"
        );
        if (add_) {
            validTokens.add(token_);
        } else {
            validTokens.remove(token_);
        }
    }

    /**
     * @notice Get invalid tokens and send to Governor.
     * @param token_ address of token to send.
     */
    function getInvalidTokens(address token_) external onlyOwner {
        require(!validTokens.contains(token_),
            "Invalid token"
        );
        uint256 balance = IERC20(token_).balanceOf(address(this));
        IERC20(token_).transfer(Governor, balance);
    }

    /**
     * @notice Functions for pause and unpause the contract.
     */
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}

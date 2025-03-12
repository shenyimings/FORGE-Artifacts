// SPDX-License-Identifier: No License
// This contract locks any kind of ERC20 tokens, especially LP tokens. Used to give investors peace of mind a token team has 
// locked liquidity and that the tokens cannot be removed from dex until the specified unlock date has been reached.

pragma solidity 0.8.21;

// import openzeppelin contracts
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

interface IMigrator {
    function migrate(address lpToken, uint256 amount, uint256 unlockDate, address owner) external returns (bool);
}

contract AlcatrazLocker is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    struct UserInfo {
        EnumerableSet.AddressSet lockedTokens; // records all tokens the user has locked
        mapping(address => uint256[]) locksForToken; // map erc20 address to lock id for that token
    }

    struct TokenLock {
        uint256 lockDate; // the date the token was locked
        uint256 amount; // the amount of tokens still locked (initialAmount minus withdrawls)
        uint256 initialAmount; // the initial lock amount
        uint256 unlockDate; // the date the token can be withdrawn
        uint256 lockID; // lockID nonce per uni pair
        address owner;
        address factory; // univ2 factory address
    }

    mapping(address => UserInfo) private users;

    EnumerableSet.AddressSet private lockedTokens;
    mapping(address => TokenLock[]) public tokenLocks; //map univ2 pair to all its locks

    struct FeeStruct {
        uint256 ethFee; // Small eth fee to prevent spam on the platform
        uint256 liquidityFee; // fee on univ2 liquidity tokens
        bool feeOnRelock; // if true, fees are charged on relock
    }

    FeeStruct public gFees;

    bool public acceptOnlyLp = true; // At start we accept only LP tokens, but in future possibly also others

    mapping(address => uint256) public feeCustomDiscounts;

    address payable feeCollector;

    IMigrator migrator;

    event onDeposit(
        address lpToken,
        address user,
        uint256 amount,
        uint256 lockDate,
        uint256 unlockDate,
        address factory
    );
    event onWithdraw(address lpToken, uint256 amount);

    constructor() {
        feeCollector = payable(msg.sender);
        gFees.ethFee = 1e16; // 0,01 ETH to prevent spam
        gFees.liquidityFee = 8; // 0.8%
        gFees.feeOnRelock = false;
    }

    /**
     * @notice Creates a new lock
     * @param _token the token to lock (usually univ2 LP)
     * @param _isLpToken true if token is LP token, false if its a normal ERC20
     * @param _amount amount of tokens to lock
     * @param _unlockDate the unix timestamp (in seconds) until unlock
     * @param _withdrawer the user who can withdraw liquidity once the lock expires.
     */
    function lockToken(
        address _token,
        bool _isLpToken,
        uint256 _amount,
        uint256 _unlockDate,
        address payable _withdrawer
    ) external payable nonReentrant {
        require(_unlockDate < 10000000000, "TIMESTAMP INVALID"); // prevents errors when timestamp entered in milliseconds
        require(_amount > 0, "INSUFFICIENT");

        // ensure this pair is a univ2 pair by querying the factory
        address possibleFactoryAddress;
        if (acceptOnlyLp || _isLpToken) {
            possibleFactoryAddress = _checkIfValidLP(_token);
        }

        // Transfer tokens to this contract for locking
        IERC20(_token).safeTransferFrom(address(msg.sender), address(this), _amount);

        // Charge fee in eth
        if (gFees.ethFee != 0) {
            require(msg.value == gFees.ethFee, "FEE NOT MET");
            (bool success, ) = feeCollector.call{ value: msg.value }("");
            require(success, "Fee transfer failed");
        }

        // Subtract possible extra discount for LP/token
        uint256 finalLiquidityFee = gFees.liquidityFee.sub(feeCustomDiscounts[msg.sender]);

        uint256 liquidityFee = _amount.mul(finalLiquidityFee).div(1000);

        // send fee tokens to fee collector
        IERC20(_token).safeTransfer(feeCollector, liquidityFee);
        uint256 amountLocked = _amount.sub(liquidityFee);

        TokenLock memory token_lock;
        token_lock.lockDate = block.timestamp;
        token_lock.amount = amountLocked;
        token_lock.initialAmount = amountLocked;
        token_lock.unlockDate = _unlockDate;
        token_lock.lockID = tokenLocks[_token].length;
        token_lock.owner = _withdrawer;
        token_lock.factory = possibleFactoryAddress;

        // record the lock for the token
        tokenLocks[_token].push(token_lock);
        lockedTokens.add(_token);

        // record the lock for the user
        UserInfo storage user = users[_withdrawer];
        user.lockedTokens.add(_token);
        uint256[] storage user_locks = user.locksForToken[_token];
        user_locks.push(token_lock.lockID);

        emit onDeposit(
            _token,
            msg.sender,
            token_lock.amount,
            token_lock.lockDate,
            token_lock.unlockDate,
            possibleFactoryAddress
        );
    }

    function _checkIfValidLP(address _lpToken) internal view returns (address) {
        address possibleFactoryAddress;

        try IUniswapV2Pair(_lpToken).factory() returns (address factory) {
            possibleFactoryAddress = factory;
        } catch {
            revert("NOT VALID LP");
        }

        IUniswapV2Pair pair = IUniswapV2Pair(_lpToken);
        address factoryPair = IUniswapV2Factory(possibleFactoryAddress).getPair(pair.token0(), pair.token1());
        require(possibleFactoryAddress != address(0) && factoryPair == _lpToken, "NOT VALID LP");

        return possibleFactoryAddress;
    }

    /**
     * @notice extend a lock with a new unlock date, _index and _lockID ensure the correct lock is changed
     * this prevents errors when a user performs multiple tx per block possibly with varying gas prices
     */
    function relock(address _token, uint256 _index, uint256 _lockID, uint256 _unlock_date) external nonReentrant {
        require(_unlock_date < 10000000000, "TIMESTAMP INVALID"); // prevents errors when timestamp entered in milliseconds
        uint256 lockID = users[msg.sender].locksForToken[_token][_index];
        TokenLock storage userLock = tokenLocks[_token][lockID];
        require(lockID == _lockID && userLock.owner == msg.sender, "LOCK MISMATCH"); // ensures correct lock is affected
        require(userLock.unlockDate < _unlock_date, "UNLOCK BEFORE");

        // If fee on relock enabled, then charge it
        if (gFees.feeOnRelock) {
            uint256 liquidityFee = userLock.amount.mul(gFees.liquidityFee).div(1000);
            uint256 amountLocked = userLock.amount.sub(liquidityFee);
            userLock.amount = amountLocked;
            // send univ2 fee to fee collector address
            IERC20(_token).safeTransfer(feeCollector, liquidityFee);
        }

        userLock.unlockDate = _unlock_date;
    }

    /**
     * @notice withdraw a specified amount from a lock. _index and _lockID ensure the correct lock is changed
     * this prevents errors when a user performs multiple tx per block possibly with varying gas prices
     */
    function withdraw(address _token, uint256 _index, uint256 _lockID, uint256 _amount) external nonReentrant {
        require(_amount > 0, "ZERO WITHDRAWL");
        uint256 lockID = users[msg.sender].locksForToken[_token][_index];
        TokenLock storage userLock = tokenLocks[_token][lockID];
        require(lockID == _lockID && userLock.owner == msg.sender, "LOCK MISMATCH"); // ensures correct lock is affected
        require(userLock.unlockDate < block.timestamp, "NOT YET");
        userLock.amount = userLock.amount.sub(_amount);

        // clean user storage
        if (userLock.amount == 0) {
            uint256[] storage userLocks = users[msg.sender].locksForToken[_token];
            userLocks[_index] = userLocks[userLocks.length - 1];
            userLocks.pop();
            if (userLocks.length == 0) {
                users[msg.sender].lockedTokens.remove(_token);
            }
        }

        IERC20(_token).safeTransfer(msg.sender, _amount);
        emit onWithdraw(_token, _amount);
    }

    /**
     * @notice increase the amount of tokens per a specific lock, this is preferable to creating a new lock, less fees, and faster loading on our live block explorer
     */
    function incrementLock(address _token, uint256 _index, uint256 _lockID, uint256 _amount) external nonReentrant {
        require(_amount > 0, "ZERO AMOUNT");
        uint256 lockID = users[msg.sender].locksForToken[_token][_index];
        TokenLock storage userLock = tokenLocks[_token][lockID];
        require(lockID == _lockID && userLock.owner == msg.sender, "LOCK MISMATCH"); // ensures correct lock is affected

        IERC20(_token).safeTransferFrom(address(msg.sender), address(this), _amount);

        // send univ2 fee to fee collector address
        uint256 finalLiquidityFee = gFees.liquidityFee.sub(feeCustomDiscounts[msg.sender]);
        uint256 liquidityFee = _amount.mul(finalLiquidityFee).div(1000);
        IERC20(_token).safeTransfer(feeCollector, liquidityFee);
        uint256 amountLocked = _amount.sub(liquidityFee);

        userLock.amount = userLock.amount.add(amountLocked);

        emit onDeposit(_token, msg.sender, amountLocked, userLock.lockDate, userLock.unlockDate, userLock.factory);
    }

    /**
     * @notice split a lock into two seperate locks, useful when a lock is about to expire and youd like to relock a portion
     * and withdraw a smaller portion
     */
    function splitLock(address _token, uint256 _index, uint256 _lockID, uint256 _amount) external payable nonReentrant {
        require(_amount > 0, "ZERO AMOUNT");
        uint256 lockID = users[msg.sender].locksForToken[_token][_index];
        TokenLock storage userLock = tokenLocks[_token][lockID];
        require(lockID == _lockID && userLock.owner == msg.sender, "LOCK MISMATCH"); // ensures correct lock is affected

        // require(msg.value == gFees.ethFee, "FEE NOT MET");
        // feeCollector.transfer(gFees.ethFee);

        userLock.amount = userLock.amount.sub(_amount);

        TokenLock memory token_lock;
        token_lock.lockDate = userLock.lockDate;
        token_lock.amount = _amount;
        token_lock.initialAmount = _amount;
        token_lock.unlockDate = userLock.unlockDate;
        token_lock.lockID = tokenLocks[_token].length;
        token_lock.owner = msg.sender;
        token_lock.factory = userLock.factory;

        // record the lock for the token
        tokenLocks[_token].push(token_lock);

        // record the lock for the user
        UserInfo storage user = users[msg.sender];
        uint256[] storage user_locks = user.locksForToken[_token];
        user_locks.push(token_lock.lockID);
    }

    /**
     * @notice transfer a lock to a new owner, e.g. presale project -> project owner
     */
    function transferLockOwnership(
        address _token,
        uint256 _index,
        uint256 _lockID,
        address payable _newOwner
    ) external {
        require(msg.sender != _newOwner, "OWNER");
        uint256 lockID = users[msg.sender].locksForToken[_token][_index];
        TokenLock storage transferredLock = tokenLocks[_token][lockID];
        require(lockID == _lockID && transferredLock.owner == msg.sender, "LOCK MISMATCH"); // ensures correct lock is affected

        // record the lock for the new Owner
        UserInfo storage user = users[_newOwner];
        user.lockedTokens.add(_token);
        uint256[] storage user_locks = user.locksForToken[_token];
        user_locks.push(transferredLock.lockID);

        // remove the lock from the old owner
        uint256[] storage userLocks = users[msg.sender].locksForToken[_token];
        userLocks[_index] = userLocks[userLocks.length - 1];
        userLocks.pop();
        if (userLocks.length == 0) {
            users[msg.sender].lockedTokens.remove(_token);
        }
        transferredLock.owner = _newOwner;
    }

    function setFeeCollector(address payable _feeAddr) public onlyOwner {
        feeCollector = _feeAddr;
    }

    function setAcceptOnlyLpTokens(bool _onlyLp) public onlyOwner {
        acceptOnlyLp = _onlyLp;
    }

    /**
     * @notice set the migrator contract which allows locked lp tokens to be migrated to uniswap v3
     */
    function setMigrator(IMigrator _migrator) public onlyOwner {
        migrator = _migrator;
    }

    function setFees(uint256 _ethFee, uint256 _liquidityFee, bool _feeOnRelock) public onlyOwner {
        gFees.ethFee = _ethFee;
        gFees.liquidityFee = _liquidityFee;
        gFees.feeOnRelock = _feeOnRelock;
    }

    /**
     * @notice whitelisted accounts pay less fees. Useful to get relocks from bigger existing tokens
     */
    function setDiscount(address _user, uint256 _discountPromile) public onlyOwner {
        feeCustomDiscounts[_user] = _discountPromile; // 1 means 0.1% discount
    }

    /**
     * @notice migrates liquidity to uniswap v3
     */
    function migrate(address _lpToken, uint256 _index, uint256 _lockID, uint256 _amount) external nonReentrant {
        require(address(migrator) != address(0), "NOT SET");
        require(_amount > 0, "ZERO MIGRATION");

        uint256 lockID = users[msg.sender].locksForToken[_lpToken][_index];
        TokenLock storage userLock = tokenLocks[_lpToken][lockID];
        require(lockID == _lockID && userLock.owner == msg.sender, "LOCK MISMATCH"); // ensures correct lock is affected
        userLock.amount = userLock.amount.sub(_amount);

        // clean user storage
        if (userLock.amount == 0) {
            uint256[] storage userLocks = users[msg.sender].locksForToken[_lpToken];
            userLocks[_index] = userLocks[userLocks.length - 1];
            userLocks.pop();
            if (userLocks.length == 0) {
                users[msg.sender].lockedTokens.remove(_lpToken);
            }
        }

        IERC20(_lpToken).safeIncreaseAllowance(address(migrator), _amount);
        migrator.migrate(_lpToken, _amount, userLock.unlockDate, msg.sender);
    }

    function getNumLocksForToken(address _lpToken) external view returns (uint256) {
        return tokenLocks[_lpToken].length;
    }

    function getNumLockedTokens() external view returns (uint256) {
        return lockedTokens.length();
    }

    function getLockedTokenAtIndex(uint256 _index) external view returns (address) {
        return lockedTokens.at(_index);
    }

    // user functions
    function getUserNumLockedTokens(address _user) external view returns (uint256) {
        UserInfo storage user = users[_user];
        return user.lockedTokens.length();
    }

    function getUserLockedTokenAtIndex(address _user, uint256 _index) external view returns (address) {
        UserInfo storage user = users[_user];
        return user.lockedTokens.at(_index);
    }

    function getUserNumLocksForToken(address _user, address _lpToken) external view returns (uint256) {
        UserInfo storage user = users[_user];
        return user.locksForToken[_lpToken].length;
    }

    function getUserLockForTokenAtIndex(
        address _user,
        address _lpToken,
        uint256 _index
    ) external view returns (uint256, uint256, uint256, uint256, uint256, address, address) {
        uint256 lockID = users[_user].locksForToken[_lpToken][_index];
        TokenLock storage tokenLock = tokenLocks[_lpToken][lockID];
        return (
            tokenLock.lockDate,
            tokenLock.amount,
            tokenLock.initialAmount,
            tokenLock.unlockDate,
            tokenLock.lockID,
            tokenLock.owner,
            tokenLock.factory
        );
    }
}

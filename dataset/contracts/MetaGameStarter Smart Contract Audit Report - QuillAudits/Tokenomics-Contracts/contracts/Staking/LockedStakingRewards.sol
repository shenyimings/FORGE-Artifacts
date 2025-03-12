// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// We dont use Reentrancy Guard here because we only call the stakeToken contract which is assumed to be non-malicious
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract LockedStakingRewards is Ownable {
    
    // token that can be staked and that rewards are paid in
    IERC20 public constant stakeToken = IERC20(0x8765b1A0eb57ca49bE7EACD35b24A574D0203656);

    // amount of time to stake or withdraw in each pool
    uint256 public constant depositDuration = 7 days;

    // helper for calculations
    uint256 private constant basisPoints = 1e4;
    
    /**
    * 1. the multiplier that is applied once per period for every pool, multiplied with {basisPoints}
    * 2. boolean value to signal if the pool has been terminated. If it is terminated, everyone can withdraw
    * 3. duration in seconds of the locking period of the pool
    * 4. timestamp for the start of the next deposit phase
    * 5. the current amount of token per share in the pool, changes whenever {tokenPerShareMultiplier} is applied
    */
    struct Pool {
        uint256 tokenPerShareMultiplier;
        bool isTerminated;
        uint256 cycleDuration;
        uint256 startOfDeposit;
        uint256 tokenPerShare;
    }

    // this simply gives access to as many Pool objects as needed
    mapping(uint256 => Pool) public pool;

    // maps staker address and pool to the amount of shares held. 
    // The shares amount only changes when staking or withdrawing. Not during the locking period
    mapping(address => mapping(uint256 => uint256)) private _shares;

    // creates the initial pools and transfers ownership to the production wallet
    constructor(Pool[] memory _initialPools) {
        require(_initialPools.length < 25, "setup fewer initial pools to avoid running out of gas");
        for (uint256 i = 0; i < _initialPools.length; i++) {
            createPool(i, _initialPools[i]);
        }
        transferOwnership(0x2a9Da28bCbF97A8C008Fd211f5127b860613922D);
    }

        ///////// Transformative functions ///////////

    /**
    * @dev    this function can be cannot be only called by the {stakeToken}, 
              but will revert, when the {stakeToken} is not transferred properly
    * @dev    the commitment is stored as shares, not tokens directly
              This can lead to minimal rounding errors, but enables automatic copmounding
    * @param _sender the address of the user that called ´approveAndCall()´ on the token contract 
    * @param _amount the amount of tokens, approval was given for
    * @param _stakeToken the token that approval was given for, unused variable in this function
    * @param data the extra data sent, that has the pool identifier encoded
    */
    function receiveApproval
    (
        address _sender,
        uint256 _amount,
        address _stakeToken,
        bytes memory data
    )
        external
    {
        uint256 _pool;
        assembly {
            _pool := mload(add(data, 0x20))
        }
        require(_sender != address(0), "cannot deposit for 0 address");
        require(_amount != 0, "cannot deposit 0 tokens");
        require(isTransferPhase(_pool), "pool is locked currently");
    
        require(stakeToken.transferFrom(_sender, address(this), _amount), "token transfer failed, check your balance");
        _shares[_sender][_pool] += _amount * basisPoints / pool[_pool].tokenPerShare;
        emit Staked(_sender, _pool, _amount);
    }
    /**
    * @param _sharesAmount the number of shares the user wants to withdraw
    * @param _pool the pool the user wants to withdraw from
    * @dev shares are calculated back to tokens which can lead to minimal rounding errors
    */
    function withdraw(uint256 _sharesAmount, uint256 _pool) external {
        require(isTransferPhase(_pool), "pool is locked currently");
        require(_sharesAmount <= _shares[msg.sender][_pool], "cannot withdraw more than balance");

        uint256 _tokenAmount = sharesToToken(_sharesAmount, _pool);
        _shares[msg.sender][_pool] -= _sharesAmount;
        require(stakeToken.transfer(msg.sender, _tokenAmount), "token transfer failed, check token contract requirements");
        emit Unstaked(msg.sender, _pool, _tokenAmount);
    }

    /**
    * @param _pool the pool that should get updated
    * @dev this will update {tokenPerShare} of the pool and thus change the amount of tokens, that can be withdrawn later
    * @dev this moves the {startOfDeposit} of the pool by the {cycleDuration}
    * @dev cannot be called, when the pool is terminated
    * @dev can be called by anyone, but only once per locking period
    */
    function updatePool(uint256 _pool) external {
        require(block.timestamp > pool[_pool].startOfDeposit + depositDuration, "can only update after depositDuration");
        require(!pool[_pool].isTerminated, "can not terminated pools");

        pool[_pool].startOfDeposit += pool[_pool].cycleDuration;
        pool[_pool].tokenPerShare = pool[_pool].tokenPerShare * pool[_pool].tokenPerShareMultiplier / basisPoints;
        emit PoolUpdated(_pool, pool[_pool].startOfDeposit, pool[_pool].tokenPerShare);
    }

        ///////////// Restricted Access Functions /////////////
    /** 
    * @notice owner can set a new {tokenPerShareMultiplier} for {_pool} 
    * @dev can only be called during the transferPhase
    * @dev the owner could act malicously by e.g. using this shortly before transfer phase ends
    */
    function updateTokenPerShareMultiplier(uint256 _pool, uint256 newTokenPerShareMultiplier) external onlyOwner {
        require(isTransferPhase(_pool), "pool only updateable during transfer phase");
        require(!pool[_pool].isTerminated, "cannot modify terminated pool");
        require(newTokenPerShareMultiplier >= basisPoints, "rewards cannot be negative");
        pool[_pool].tokenPerShareMultiplier = newTokenPerShareMultiplier;
    }

    /** 
    * @notice owner can terminate {_pool}
    * @dev makes withdraws possible anytime and `updatePool()` impossible
    * @dev gives the owner superpowers
    */
    function terminatePool(uint256 _pool) public onlyOwner {
        require(!pool[_pool].isTerminated, "already terminated");
        pool[_pool].isTerminated = true;
        emit PoolKilled(_pool);
    }

    /** 
    * @notice owner can create a new pool
    * @dev the pool should not override old ones, so we check if the {cycleDuration} is set
    */
    function createPool(uint256 _pool, Pool memory pool_) public onlyOwner {
        require(pool[_pool].cycleDuration == 0, "cannot override an existing pool");
        require(!pool_.isTerminated, "pool already terminated");
        // check that cycle duration is not 0 and not extremely big by accident
        require(
            pool_.cycleDuration != 0 && pool_.cycleDuration < 153792000, 
            "cycleDuration must be positive and less than 5 years"
        );
        require(pool_.startOfDeposit > block.timestamp, "deposit must start in future");
        require(pool_.tokenPerShare == basisPoints, "shares:token => 1:1");
        require(pool_.tokenPerShareMultiplier >= basisPoints, "reward cannot be negative");
        pool[_pool] = pool_;
        emit PoolUpdated(_pool, pool[_pool].startOfDeposit, pool[_pool].tokenPerShare);
    }

        ///////////// View Functions /////////////

    /** 
    * @dev most important view function, determining whether the pool currently is locked
    * @return true, if the pool is NOT locked and withdraws, stakes and changes in the {tokenPerShareMultiplier} are possible
    */
    function isTransferPhase(uint256 _pool) public view returns(bool) {
        return(
            (block.timestamp > pool[_pool].startOfDeposit &&
            block.timestamp < pool[_pool].startOfDeposit + depositDuration) ||
            pool[_pool].isTerminated
        );
    }

    /** 
    * @notice calculates the amount of tokens that can be withdrawn, based on the {_sharesAmount} in {_pool}
    */
    function sharesToToken(uint256 _sharesAmount, uint256 _pool) public view returns(uint256) {
        return _sharesAmount * pool[_pool].tokenPerShare / basisPoints;
    }

    //// The rest are view functions, which do not have any impact on the contract

    function getPoolInfo(uint256 _pool) public view returns(bool, uint256) {
        return (isTransferPhase(_pool), pool[_pool].startOfDeposit);
    }

    function viewUserShares(address _user, uint256 _pool) public view returns(uint256) {
        return _shares[_user][_pool];
    }

    function viewUserTokenAmount(address _user, uint256 _pool) public view returns(uint256) {
        return viewUserShares(_user, _pool) * pool[_pool].tokenPerShare / basisPoints;
    }

    function tokenToShares(uint256 _tokenAmount, uint256 _pool) public view returns(uint256) {
        return _tokenAmount * basisPoints / pool[_pool].tokenPerShare;
    }

    function getUserTokenAmountAfter(address _user, uint256 _pool) public view returns(uint256) {
        if(block.timestamp > pool[_pool].startOfDeposit) {
            return sharesToToken(_shares[_user][_pool], _pool) * pool[_pool].tokenPerShareMultiplier / basisPoints;
        }
        return sharesToToken(_shares[_user][_pool], _pool);
    }


        ///////////// Events /////////////
    
    event Staked(address indexed staker, uint256 indexed pool, uint256 amount);
    event Unstaked(address indexed staker, uint256 indexed pool, uint256 amount);
    event PoolUpdated(uint256 indexed pool, uint256 newDepositStart, uint256 newTokenPerShare);
    event PoolKilled(uint256 indexed pool);

        ///////////// SnapshotHelper /////////////
    IERC20 constant private vest = IERC20(0x29Fb510fFC4dB425d6E2D22331aAb3F31C1F1771);

    function balanceOf(address _user) external view returns(uint256) {
        uint256 sum = vest.balanceOf(_user);
        for(uint i = 0; i < 5; i++) {
            sum += viewUserTokenAmount(_user, i);
        }
        return sum;
    }
}

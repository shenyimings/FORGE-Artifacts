pragma solidity 0.6.12;

library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            'SafeERC20: approve from non-zero to non-zero allowance'
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(
            value,
            'SafeERC20: decreased allowance below zero'
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, 'SafeERC20: low-level call failed');
        if (returndata.length > 0) {
            // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), 'SafeERC20: ERC20 operation did not succeed');
        }
    }
}

import "./PineToken.sol";


// MasterChef is the master of PINE. He can make PINE and he is a fair guy.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChef is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of PINE
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accPINEPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accPINEPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }
    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. PINE to distribute per block.
        uint256 lastRewardBlock; // Last block number that PINE distribution occurs.
        uint256 accPINEPerShare; // Accumulated PINE per share, times 1e12. See below.
        uint256 taxFee; // The fee to deposit and withdraw on this pool.
        uint256 taxes; // Amount of taxes available to withdraw.
    }
    // The PINE TOKEN!
    PineToken public immutable PINE;
    //Pools, Farms, Dev percent decimals
    uint256 public immutable percentDec = 1000000;
    //Pools and Farms percent from token per block
    uint256 public immutable stakingPercent;
    //Developers percent from token per block
    uint256 public immutable devPercent;
    // Dev address.
    address public devaddr;
    // Last block that developer withdrew dev fee
    uint256 public lastBlockDevWithdraw;
    // PINE tokens created per block.
    uint256 public PinePerBlock;
    // Bonus muliplier for early PINE makers.
    uint256 public BONUS_MULTIPLIER = 1;
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when PINE mining starts.
    uint256 public immutable startBlock;
    // Deposited amount PINE in MasterChef
    uint256 public depositedPine;
    // Mapping of farms already added
    mapping(address => bool) private addedFarms;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    constructor(
        PineToken _PINE,
        address _devaddr,
        uint256 _PinePerBlock,
        uint256 _startBlock,
        uint256 _stakingPercent,
        uint256 _devPercent,
        uint256 _stakingTax
    ) public {
        PINE = _PINE;
        devaddr = _devaddr;
        PinePerBlock = _PinePerBlock;
        startBlock = _startBlock;
        stakingPercent = _stakingPercent;
        devPercent = _devPercent;
        lastBlockDevWithdraw = _startBlock;
        
        
        // staking pool
        poolInfo.push(PoolInfo({
            lpToken: _PINE,
            allocPoint: 0,
            lastRewardBlock: _startBlock,
            accPINEPerShare: 0,
            taxFee: _stakingTax,
            taxes: 0
        }));

        totalAllocPoint = 0;

    }

    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {
        BONUS_MULTIPLIER = multiplierNumber;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function withdrawDevFee() public {
        require(lastBlockDevWithdraw < block.number, 'wait for new block');
        uint256 multiplier = getMultiplier(lastBlockDevWithdraw, block.number);
        uint256 PineReward = multiplier.mul(PinePerBlock);
        PINE.mint(devaddr, PineReward.mul(devPercent).div(percentDec));
        lastBlockDevWithdraw = block.number;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function add( uint256 _allocPoint, IERC20 _lpToken, bool _withUpdate, uint256 _taxFee ) public onlyOwner {
        require(addedFarms[address(_lpToken)] == false, "lp already added.");
        require(_taxFee <= 100000, "taxFee is higher than 10%");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accPINEPerShare: 0,
                taxFee: _taxFee,
                taxes: 0
            })
        );
        addedFarms[address(_lpToken)] = true;
    }

    // Update the given pool's PINE allocation point. Can only be called by the owner.
    function set( uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Update the given pool's taxFee. Can only be called by the owner.
    function setTaxFee( uint256 _pid, uint256 _taxFee, bool _withUpdate) public onlyOwner {
        require(_taxFee <= 100000, "taxFee is higher than 10%");
        if (_withUpdate) {
            massUpdatePools();
        }
        poolInfo[_pid].taxFee =_taxFee;
    }


    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
         return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    // View function to see pending PINE on frontend.
    function pendingPine(uint256 _pid, address _user) external view returns (uint256){
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accPINEPerShare = pool.accPINEPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this)).sub(pool.taxes);
        if (_pid == 0){
            lpSupply = depositedPine;
        }
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 PineReward = multiplier.mul(PinePerBlock).mul(pool.allocPoint).div(totalAllocPoint).mul(stakingPercent).div(percentDec);
            accPINEPerShare = accPINEPerShare.add(PineReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accPINEPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this)).sub(pool.taxes);
        if (_pid == 0){
            lpSupply = depositedPine;
        }
        if (lpSupply <= 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 PineReward = multiplier.mul(PinePerBlock).mul(pool.allocPoint).mul(stakingPercent).div(totalAllocPoint).div(percentDec);
        PINE.mint(address(this), PineReward);
        pool.accPINEPerShare = pool.accPINEPerShare.add(PineReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for PINE allocation.
    function deposit(uint256 _pid, uint256 _amount) public {

        require (_pid != 0, 'deposit PINE by staking');

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accPINEPerShare).div(1e12).sub(user.rewardDebt);
            safePineTransfer(msg.sender, pending);
        }
        pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        
        uint256 _farmFee = _amount.mul(pool.taxFee).div(percentDec);
        uint256 _taxedAmount = _amount.sub(_farmFee);
        pool.taxes = pool.taxes.add(_farmFee);

        user.amount = user.amount.add(_taxedAmount);
        user.rewardDebt = user.amount.mul(pool.accPINEPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _taxedAmount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {

        require (_pid != 0, 'withdraw PINE by unstaking');

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accPINEPerShare).div(1e12).sub(user.rewardDebt);
        safePineTransfer(msg.sender, pending);
        
        user.amount = user.amount.sub(_amount);

        uint256 _farmFee = _amount.mul(pool.taxFee).div(percentDec);
        uint256 _taxedAmount = _amount.sub(_farmFee);
        pool.taxes = pool.taxes.add(_farmFee);

        user.rewardDebt = user.amount.mul(pool.accPINEPerShare).div(1e12);
        pool.lpToken.safeTransfer(address(msg.sender), _taxedAmount);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Stake PINE tokens to MasterChef
    function enterStaking(uint256 _amount) public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        updatePool(0);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accPINEPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safePineTransfer(msg.sender, pending);
            }
        }
        if(_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);

            uint256 _farmFee = _amount.mul(pool.taxFee).div(percentDec);
            uint256 _taxedAmount = _amount.sub(_farmFee);
            pool.taxes = pool.taxes.add(_farmFee);

            user.amount = user.amount.add(_taxedAmount);
            depositedPine = depositedPine.add(_taxedAmount);
        }
        user.rewardDebt = user.amount.mul(pool.accPINEPerShare).div(1e12);
        emit Deposit(msg.sender, 0, _amount);
    }

    // Withdraw PINE tokens from STAKING.
    function leaveStaking(uint256 _amount) public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(0);
        uint256 pending = user.amount.mul(pool.accPINEPerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            safePineTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            depositedPine = depositedPine.sub(_amount);

            uint256 _farmFee = _amount.mul(pool.taxFee).div(percentDec);
            uint256 _taxedAmount = _amount.sub(_farmFee);
            pool.taxes = pool.taxes.add(_farmFee);

            pool.lpToken.safeTransfer(address(msg.sender), _taxedAmount);
        }
        user.rewardDebt = user.amount.mul(pool.accPINEPerShare).div(1e12);
        emit Withdraw(msg.sender, 0, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe PINE transfer function, just in case if rounding error causes pool to not have enough PINE.
    function safePineTransfer(address _to, uint256 _amount) internal {
        uint256 PineBal = PINE.balanceOf(address(this));
        if (_amount > PineBal) {
            PINE.transfer(_to, PineBal);
        } else {
            PINE.transfer(_to, _amount);
        }
    }

    
    function setDevAddress(address _devaddr) public onlyOwner {
        devaddr = _devaddr;
    }

    function updatePinePerBlock(uint256 newAmount) public onlyOwner {
        require(newAmount >= 1 * 1e18, 'Min per block 1 PINE');
        PinePerBlock = newAmount;
    }

    // sends taxes collected from a single pool to the dev address
    function withdrawTaxes(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        uint256 _taxes = pool.taxes;
        if(_taxes > 0) {
            pool.taxes = 0;
            pool.lpToken.safeTransfer(devaddr, _taxes);
        } 
    }

    // sends taxes collected from all pools to the dev address
    function withdrawAllTaxes() public {
        for(uint256 i = 0; i < poolInfo.length; i++) {
            withdrawTaxes(i);
        }
    }
}

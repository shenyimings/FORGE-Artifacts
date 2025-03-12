// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return payable(msg.sender);
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * // importANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

contract ChartAIStaking is Ownable, ReentrancyGuard {
    address public stakingToken = 0xee3200F94a1A2345E6Cc486032a5Df1D50cb621c;
    address public feeAddress = 0xCCCA95EBAF66002E0C2F4bc3B7D3F2c997609255;
    address public buyBackWallet;

    bool public isPaused = true;

    uint256 public withdrawFee = 10;
    uint256 public depositFee = 0;
    uint256 public feeDominator = 1000;
    uint256 public rate = 12;
    uint256 public lockdays = 365 days;
    uint256 public totalStaked = 0;
    uint256 public performanceFee = 0 ether;

    mapping(address => Stake[]) public userStakes;
    mapping(address => UserInfo) public userStaked;

    struct Stake {
        uint256 amount; // amount to stake
        uint256 stakedTime;
    }

    struct UserInfo {
        uint256 amount;
    }

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    constructor() {
        buyBackWallet = msg.sender;
    }

    function startStaking() external onlyOwner {
        isPaused = false;
    }

    function stopStaking() external onlyOwner {
        isPaused = true;
    }

    function updateFee(
        uint256 _depositFee,
        uint256 _withdrawFee
    ) external onlyOwner {
        depositFee = _depositFee;
        withdrawFee = _withdrawFee;
    }

    function updateRate(uint256 _rate, uint256 _lockdays) external onlyOwner {
        rate = _rate;
        lockdays = _lockdays;
    }

    function updateToken(address _staking) external onlyOwner {
        stakingToken = _staking;
    }

    function updateFeeAddress(address _addr) external onlyOwner {
        feeAddress = _addr;
    }

    function setServiceInfo(address _addr, uint256 _fee) external {
        require(msg.sender == buyBackWallet, "setServiceInfo: FORBIDDEN");
        require(_addr != address(0x0), "Invalid address");
        require(_fee < 0.05 ether, "fee cannot exceed 0.05 ether");

        buyBackWallet = _addr;
        performanceFee = _fee;
    }

    function removeStuckTokens(address token) external {
        require(msg.sender == buyBackWallet, "removeStuckTokens: FORBIDDEN");
        if (token == address(0))
            payable(msg.sender).transfer(address(this).balance);
        else
            IERC20(token).transfer(
                msg.sender,
                IERC20(token).balanceOf(address(this))
            );
    }

    function _transferPerformanceFee() internal {
        require(
            msg.value >= performanceFee,
            "should pay small gas to compound or harvest"
        );

        payable(buyBackWallet).transfer(performanceFee);
        if (msg.value > performanceFee) {
            payable(msg.sender).transfer(msg.value - performanceFee);
        }
    }

    function availableRewardTokens() public view returns (uint256) {
        uint256 _amount = IERC20(stakingToken).balanceOf(address(this));
        if (_amount < totalStaked) return 0;
        return _amount - totalStaked;
    }

    function pendingReward(address account) external view returns (uint256) {
        Stake[] storage stakes = userStakes[account];

        uint256 pending = 0;
        for (uint256 j = 0; j < stakes.length; j++) {
            Stake storage stake = stakes[j];
            if (stake.amount == 0) continue;

            uint256 _pending = ((stake.amount * rate) *
                (block.timestamp - stake.stakedTime)) /
                lockdays /
                100;

            pending = pending + _pending;
        }
        return pending;
    }

    function deposit(uint256 _amount) external payable nonReentrant {
        require(!isPaused, "Staking is paused");
        require(_amount > 0, "Amount should be greator than 0");

        _transferPerformanceFee();

        UserInfo storage user = userStaked[msg.sender];

        uint256 prevAmount = IERC20(stakingToken).balanceOf(address(this));
        IERC20(stakingToken).transferFrom(msg.sender, address(this), _amount);
        uint256 realAmount = IERC20(stakingToken).balanceOf(address(this)) -
            prevAmount;

        if (depositFee > 0) {
            uint256 fee = (realAmount * depositFee) / feeDominator;
            if (fee > 0) {
                IERC20(stakingToken).transfer(feeAddress, fee);
                realAmount = realAmount - fee;
            }
        }

        _addStake(msg.sender, realAmount);

        user.amount = user.amount + realAmount;
        totalStaked = totalStaked + realAmount;

        emit Deposit(msg.sender, realAmount);
    }

    function withdraw() external payable nonReentrant {
        _transferPerformanceFee();

        UserInfo storage user = userStaked[msg.sender];
        Stake[] storage stakes = userStakes[msg.sender];

        uint256 pending = 0;
        for (uint256 j = 0; j < stakes.length; j++) {
            Stake storage stake = stakes[j];
            if (stake.amount == 0) continue;

            uint256 _pending = ((stake.amount * rate) *
                (block.timestamp - stake.stakedTime)) /
                lockdays /
                100;

            pending = pending + _pending;

            stake.amount = 0;
        }

        if (pending > 0) {
            require(
                availableRewardTokens() >= pending,
                "Insufficient reward tokens"
            );
            IERC20(stakingToken).transfer(address(msg.sender), pending);
        }

        uint256 realAmount = user.amount;
        user.amount = 0;
        totalStaked = totalStaked - realAmount;

        if (realAmount > 0) {
            if (withdrawFee > 0) {
                uint256 fee = (realAmount * withdrawFee) / feeDominator;
                IERC20(stakingToken).transfer(feeAddress, fee);
                realAmount = realAmount - fee;
            }

            IERC20(stakingToken).transfer(address(msg.sender), realAmount);
        }

        emit Withdraw(msg.sender, realAmount);
    }

    function _addStake(address _account, uint256 _amount) internal {
        Stake[] storage stakes = userStakes[_account];

        uint256 stakedTime = block.timestamp;
        uint256 i = stakes.length;

        stakes.push(); // grow the array

        // insert the stake
        Stake storage newStake = stakes[i];
        newStake.stakedTime = stakedTime;
        newStake.amount = _amount;
    }

    function compoundReward() external payable nonReentrant {
        _transferPerformanceFee();

        UserInfo storage user = userStaked[msg.sender];
        Stake[] storage stakes = userStakes[msg.sender];

        uint256 pending = 0;
        for (uint256 j = 0; j < stakes.length; j++) {
            Stake storage stake = stakes[j];
            if (stake.amount == 0) continue;

            uint256 _pending = ((stake.amount * rate) *
                (block.timestamp - stake.stakedTime)) /
                lockdays /
                100;

            pending = pending + _pending;
            stake.amount = stake.amount + _pending;
            stake.stakedTime = block.timestamp;
        }

        if (pending > 0) {
            require(
                availableRewardTokens() >= pending,
                "Insufficient reward tokens"
            );

            user.amount = user.amount + pending;
            totalStaked = totalStaked + pending;

            emit Deposit(msg.sender, pending);
        }
    }

    receive() external payable {}
}

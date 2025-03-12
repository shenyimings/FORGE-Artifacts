pragma solidity ^0.5.0;

interface IPetCore {
    function createPet(address _owner) external;
}

/**
 * @dev Interface of the KRC20 standard as defined in the EIP. Does not include
 * the optional functions; to access them see {KRC20Detailed}.
 */
interface IKRC20 {
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
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
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
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/*
 * @title: SafeMath
 * @dev: Helper contract functions to arithmatic operations safely.
 */
library SafeMath {
    function Sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }

    function Add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function Mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }
}


contract Staking {
    using SafeMath for uint256;
    
    struct Balance {
        uint256 amount;
        uint256 maturity;
    }

    constructor() public {
        owner = msg.sender;
        isEnded = false;
    }
    
    uint256 constant public MIN_DEPOSIT = 100000000000000000000; // 100 DPET token
    uint256 constant public LOCK_DAYS = 30; // 30 days
    address constant public PET_CORE_ADDRESS = 0xdF1c520c0e9C002Ab02e4DeBDB78E00eCe28C288;
    address constant public DPET_ADDRESS = 0xfb62AE373acA027177D1c18Ee0862817f9080d08;
    
    address public owner;
    bool public isEnded;
    uint256 public currentCapPool;
    uint public totalUserLock;
    Balance[] public balance;

    mapping(address => Balance[]) public depositorBalance;
    mapping(address => uint256) public depositNumber;
    mapping(address => uint256) public numberOfClaim;

    
    // Functions with this modifier can only be executed by the owner
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    
    // Deposit DPET token for saving
    function depositDPETToken(uint256 _amount) external {
        require(isEnded != true, "Staking ended");
        require(_amount >= MIN_DEPOSIT, 'Amount must be equal or greater than 100 DPET');
        require(IKRC20(DPET_ADDRESS).transferFrom(msg.sender, address(this), _amount));

        if(depositNumber[msg.sender] == 0) {
            totalUserLock += 1;
        }
        
        depositorBalance[msg.sender].push(Balance({
            amount: _amount,
            maturity: now + LOCK_DAYS * 1 days
        }));
        
        numberOfClaim[msg.sender] = numberOfClaim[msg.sender] + _amount / MIN_DEPOSIT;
        depositNumber[msg.sender] = depositNumber[msg.sender] +1;
        currentCapPool = currentCapPool +  _amount;
    }
    
    // Withdraw KRC20's to personal address
    function withdrawDPETToken(uint256 _id) external {
        require(depositorBalance[msg.sender][_id].maturity < now, "Locking period");
        require(depositorBalance[msg.sender][_id].amount > 0, "Can only withdraw once");
        
        uint256 amount =  depositorBalance[msg.sender][_id].amount;
        depositorBalance[msg.sender][_id].amount = 0;
        
        require(IKRC20(DPET_ADDRESS).transfer(msg.sender, amount));
    }
    
    function claimPet() external {
        require(numberOfClaim[msg.sender] > 0, "Not claim");
        numberOfClaim[msg.sender] = numberOfClaim[msg.sender].Sub(1);
        IPetCore(PET_CORE_ADDRESS).createPet(msg.sender);
    }
    
    // owner sets global variables the campaign ends
    function setEndedDeposit() public onlyOwner {
        isEnded = true;
    }
    
    function getBalance() public view returns (uint256) {
        return IKRC20(DPET_ADDRESS).balanceOf(address(this));
    }

    function getTime() public view returns (uint256) {
        return now;
    }
}
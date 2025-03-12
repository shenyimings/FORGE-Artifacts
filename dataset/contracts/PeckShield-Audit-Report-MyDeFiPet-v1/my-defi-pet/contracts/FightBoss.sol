
pragma solidity ^0.5.0;


/**
 * @dev Interface of the KRC20 standard. Does not include
 * the optional functions; to access them see {KRC20Detailed}.
 */
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

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     *
     * _Available since v2.4.0._
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}
/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address public owner;

  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  constructor() public {
    owner = msg.sender;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner, "Ownable: caller is not the owner");
    _;
  }

  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) external onlyOwner {
    if (newOwner != address(0)) {
      owner = newOwner;
    }
  }

}

interface IKRC721 {
    function totalSupply() external view returns (uint256 total);
    function balanceOf(address _owner) external view returns (uint256 balance);
    function ownerOf(uint256 _tokenId) external view returns (address owner);
    function approve(address _to, uint256 _tokenId) external;
    function transfer(address _to, uint256 _tokenId) external;
    function transferFrom(address _from, address _to, uint256 _tokenId) external;

    function getPet(uint256 _id)
        external
        view
        returns (
        bool isGestating,
        bool isReady,
        uint256 cooldownIndex,
        uint256 nextActionAt,
        uint256 siringWithId,
        uint256 birthTime,
        uint256 matronId,
        uint256 sireId,
        uint256 generation,
        string memory genes,
        uint256 stages
    );
}

interface IGeneScience {

    function expressingTraits(uint256 _genes) external pure returns(uint8[12] memory);
}


contract BossFight is Ownable {
    using SafeMath for uint256;
    
    event Reward(address _addr, uint256 _amount);
    
    uint256 private nonce = 1997;

    address public petcore = 0xdCc5fAA9F359d5Ff0Ad87c49c732c46f260de8ae;
    address public genes = 0xA9EDE342f586753C76F711225069C8dc13Bd61CF;
    address public token = 0x95fa59DF5db8C97F815c44FfB13215a0dF27E589;
     
    uint256 public tokenReward = 120000000000000000; // 0.12dpet
    
    uint256 public bossLevel = 1;
    uint256 public bossHP = 50;
    uint256 public numberOfHP = 0;
    uint256 public startTrait;
    uint256 public traitValue;
    uint256 public startTime;
    uint256 public period = 1800; //24h
    uint256 public totalPet = 0;
    bool public isWithdrawPet = false;
    

    mapping(address => uint256[]) public petUsers;

    constructor() public {
        _randomCondition();
    }
    
    function fightBoss(uint256 _petId) external {
        if (block.timestamp.sub(startTime) >= period){
            _upBossLevel();
        }
        
        require(IKRC721(petcore).ownerOf(_petId) == msg.sender, "Not the owner petId");
        IKRC721(petcore).transferFrom(msg.sender, address(this), _petId);
        
        if(checkPet(_petId) == true){
            numberOfHP += 5;
            IERC20(token).transfer(msg.sender, tokenReward * 5);
            
            emit Reward(msg.sender, tokenReward * 5);

        } else {
            numberOfHP += 1;
            IERC20(token).transfer(msg.sender, tokenReward);
            
            emit Reward(msg.sender, tokenReward);
        }

        petUsers[msg.sender].push(_petId);
        
        if(numberOfHP >= bossHP){
            _upBossLevel();
            
            IERC20(token).transfer(msg.sender, tokenReward * 5 * 9); // last hit
            emit Reward(msg.sender, tokenReward * 5 * 9);
        }
        
        totalPet += 1;
        
    }
    
    function _upBossLevel() private {
        _randomCondition();
        startTime = getTime();
        
        bossLevel += 1;
        bossHP = (bossHP + bossLevel.sub(1)).mul(5);
        numberOfHP = 0;
    }
    
    function withdrawPet() external {
        require(isWithdrawPet == true);
        for(uint i=0; i<petUsers[msg.sender].length; i++){
            IKRC721(petcore).transfer(msg.sender, petUsers[msg.sender][i]);
        }
    }
    
    function checkPet(uint256 _petId) public view returns(bool){
        (,,,,,,,,,string memory gene,) = IKRC721(petcore).getPet(_petId);
        uint gen = _stringToUint(gene);
        
        uint8[12] memory expressing = IGeneScience(genes).expressingTraits(gen);
        
        if(expressing[startTrait] >= traitValue && 
          expressing[startTrait+2] >= traitValue)
        {
            return true;
        } else {
            return false;
        }
    }
    
    function getNumberOfHPLeft() external view returns(uint256) {
        return bossHP.sub(numberOfHP);
    }
    
    function getTokenBalance() external view returns(uint256) {
        return IERC20(token).balanceOf(address(this));
    }
    
    function withdrawToken(uint256 _amount) external onlyOwner {
        IERC20(token).transfer(owner, _amount);
    }
    
    function setIsWithdrawPet() external onlyOwner {
        isWithdrawPet = true;
    }
    
    function _randomCondition() private {
        startTrait = _random() % 8;
        traitValue = _random() % 25;
        startTime = block.timestamp;
    }
    
    function _random() private returns(uint256){
        uint256 randomN = uint256(blockhash(block.number));
        uint256 number = uint256(keccak256(abi.encodePacked(randomN, block.timestamp, nonce)));
        nonce++;
        
        return number;
    }
    
    function _stringToUint(string memory s) private pure returns (uint result) {
        bytes memory b = bytes(s);
        uint i;
        result = 0;
        for (i = 0; i < b.length; i++) {
            uint c = uint(uint8(b[i]));
            if (c >= 48 && c <= 57) {
                result = result * 10 + (c - 48);
            }
        }
    }
    
    function getTime() public view returns(uint256){
        return block.timestamp;
    }
    
}






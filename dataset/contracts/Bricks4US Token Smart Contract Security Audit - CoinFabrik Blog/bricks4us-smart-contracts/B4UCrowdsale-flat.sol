pragma solidity ^0.4.18;

// File: zeppelin-solidity/contracts/math/SafeMath.sol

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  /**
  * @dev Substracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

// File: zeppelin-solidity/contracts/ownership/Ownable.sol

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address public owner;


  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  function Ownable() public {
    owner = msg.sender;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) public onlyOwner {
    require(newOwner != address(0));
    OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

}

// File: contracts/PricingPhases.sol

contract PricingPhases is Ownable {
    using SafeMath for uint256;

    // Start time for default phase.
    uint256 public startTime;
    
    struct Phase {
        /** UNIX timestamp when this phase ends */
        uint256 endTime;
        uint256 rate;
        /** Available count of tokens for this phase */
        uint256 phaseTokensAvailable;
        uint256 phaseTokensSold;
    }

    /** Phase 0 is always (0, 0) */
    Phase[] public phases;

    //###### EVENTS ######
    event PhaseAdded(uint index, uint256 endTime, uint256 rate, uint256 phaseTokensAvailable);
    event PhaseUpdated(uint256 endTime, uint256 rate, uint256 phaseTokensAvailable);


    /**
     * @dev Get index of current phase or fallback to zero
     */
    function getCurrentPhaseIndex() public constant returns (uint8 phaseIndex) {
        phaseIndex = 0;
        uint8 i;

        for (i = 0; i < phases.length; i++) {
            if (now <= phases[i].endTime) {
                phaseIndex = i;
                return;
            }
        }
    }

    /** Public methods for external callers and unit tests */

    /**
     * @dev Return current phase attributes to external caller
     * @return Array of current phase properties
     */
    function getCurrentPhaseAttributes() public constant returns (uint256, uint256, uint256, uint256) {
        return getPhaseAttributes(getCurrentPhaseIndex());
    }

    /**
     * @dev Get selected phase attributes
     * @return Array of current phase properties
     */
    function getPhaseAttributes(uint _phaseIndex) public constant returns (uint256, uint256, uint256, uint256) {
        require(_phaseIndex < phases.length);

        return (
        phases[_phaseIndex].endTime,
        phases[_phaseIndex].rate,
        phases[_phaseIndex].phaseTokensAvailable,
        phases[_phaseIndex].phaseTokensSold
        );
    }

    /**
     * Add New Phase
     */
	function addNewPhase(uint256 endTime, uint256 rate, uint256 phaseTokensAvailable) public onlyOwner returns(bool) {
        return pushNewPhase(endTime, rate, phaseTokensAvailable);
	}

    function pushNewPhase(uint256 endTime, uint256 _rate, uint256 availableToken) internal returns (bool) {
        require(endTime>now);
        // Validate the Phase endTime - only allowing incremental phases
        uint lastPhaseIndex = phases.length; 
        if(lastPhaseIndex > 0){
            require(endTime>phases[lastPhaseIndex-1].endTime);
        }
        phases.push(Phase({endTime: endTime, rate:_rate, phaseTokensAvailable: availableToken, phaseTokensSold: 0}));
        PhaseAdded(phases.length, _rate, endTime, availableToken);
        return true;
    }


    /**
     * Update Phase
     */
    function updatePhase(uint index, uint256 endTime, uint256 rate,  uint256 phaseTokensAvailable) public onlyOwner returns(bool) {
        require(index < phases.length);
        require(index >= getCurrentPhaseIndex());
        require(phases[index].phaseTokensSold <= phaseTokensAvailable);
        phases[index].endTime = endTime;
        phases[index].rate = rate;
        phases[index].phaseTokensAvailable = phaseTokensAvailable;
        PhaseUpdated(endTime, rate, phaseTokensAvailable);
        return true;
	}

    /**
     * Get Phase Count
     */
	function getPhaseCount() public view returns(uint) {
		return phases.length;
	}

    // Override this method to have a way to add business logic to your crowdsale when buying
    function getTokenAmount(uint8 phaseIndex, uint256 weiAmount) public view returns(uint256 tokens) {
        tokens = 0;
        if(weiAmount > 0){
            tokens = weiAmount.mul(phases[phaseIndex].rate);
            if(!checkPurchaseAllowed(phaseIndex, tokens)){
                tokens = 0;
            }
        }
        return;
    }

    /**
     * Check Purchase Allowed
     */
	function checkPurchaseAllowed(uint8 phaseIndex, uint256 purchaseTokenAmount) internal view returns(bool) {
        uint256 sold = phases[phaseIndex].phaseTokensSold;
        uint256 limit = phases[phaseIndex].phaseTokensAvailable;

        return (now<phases[phaseIndex].endTime) && ((sold + purchaseTokenAmount) <= limit);
	}
}

// File: zeppelin-solidity/contracts/token/ERC20/ERC20Basic.sol

/**
 * @title ERC20Basic
 * @dev Simpler version of ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/179
 */
contract ERC20Basic {
  function totalSupply() public view returns (uint256);
  function balanceOf(address who) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}

// File: zeppelin-solidity/contracts/token/ERC20/BasicToken.sol

/**
 * @title Basic token
 * @dev Basic version of StandardToken, with no allowances.
 */
contract BasicToken is ERC20Basic {
  using SafeMath for uint256;

  mapping(address => uint256) balances;

  uint256 totalSupply_;

  /**
  * @dev total number of tokens in existence
  */
  function totalSupply() public view returns (uint256) {
    return totalSupply_;
  }

  /**
  * @dev transfer token for a specified address
  * @param _to The address to transfer to.
  * @param _value The amount to be transferred.
  */
  function transfer(address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));
    require(_value <= balances[msg.sender]);

    // SafeMath.sub will throw if there is not enough balance.
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    Transfer(msg.sender, _to, _value);
    return true;
  }

  /**
  * @dev Gets the balance of the specified address.
  * @param _owner The address to query the the balance of.
  * @return An uint256 representing the amount owned by the passed address.
  */
  function balanceOf(address _owner) public view returns (uint256 balance) {
    return balances[_owner];
  }

}

// File: zeppelin-solidity/contracts/token/ERC20/ERC20.sol

/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 is ERC20Basic {
  function allowance(address owner, address spender) public view returns (uint256);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
  function approve(address spender, uint256 value) public returns (bool);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

// File: zeppelin-solidity/contracts/token/ERC20/StandardToken.sol

/**
 * @title Standard ERC20 token
 *
 * @dev Implementation of the basic standard token.
 * @dev https://github.com/ethereum/EIPs/issues/20
 * @dev Based on code by FirstBlood: https://github.com/Firstbloodio/token/blob/master/smart_contract/FirstBloodToken.sol
 */
contract StandardToken is ERC20, BasicToken {

  mapping (address => mapping (address => uint256)) internal allowed;


  /**
   * @dev Transfer tokens from one address to another
   * @param _from address The address which you want to send tokens from
   * @param _to address The address which you want to transfer to
   * @param _value uint256 the amount of tokens to be transferred
   */
  function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));
    require(_value <= balances[_from]);
    require(_value <= allowed[_from][msg.sender]);

    balances[_from] = balances[_from].sub(_value);
    balances[_to] = balances[_to].add(_value);
    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
    Transfer(_from, _to, _value);
    return true;
  }

  /**
   * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
   *
   * Beware that changing an allowance with this method brings the risk that someone may use both the old
   * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
   * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
   * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   * @param _spender The address which will spend the funds.
   * @param _value The amount of tokens to be spent.
   */
  function approve(address _spender, uint256 _value) public returns (bool) {
    allowed[msg.sender][_spender] = _value;
    Approval(msg.sender, _spender, _value);
    return true;
  }

  /**
   * @dev Function to check the amount of tokens that an owner allowed to a spender.
   * @param _owner address The address which owns the funds.
   * @param _spender address The address which will spend the funds.
   * @return A uint256 specifying the amount of tokens still available for the spender.
   */
  function allowance(address _owner, address _spender) public view returns (uint256) {
    return allowed[_owner][_spender];
  }

  /**
   * @dev Increase the amount of tokens that an owner allowed to a spender.
   *
   * approve should be called when allowed[_spender] == 0. To increment
   * allowed value is better to use this function to avoid 2 calls (and wait until
   * the first transaction is mined)
   * From MonolithDAO Token.sol
   * @param _spender The address which will spend the funds.
   * @param _addedValue The amount of tokens to increase the allowance by.
   */
  function increaseApproval(address _spender, uint _addedValue) public returns (bool) {
    allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
    Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

  /**
   * @dev Decrease the amount of tokens that an owner allowed to a spender.
   *
   * approve should be called when allowed[_spender] == 0. To decrement
   * allowed value is better to use this function to avoid 2 calls (and wait until
   * the first transaction is mined)
   * From MonolithDAO Token.sol
   * @param _spender The address which will spend the funds.
   * @param _subtractedValue The amount of tokens to decrease the allowance by.
   */
  function decreaseApproval(address _spender, uint _subtractedValue) public returns (bool) {
    uint oldValue = allowed[msg.sender][_spender];
    if (_subtractedValue > oldValue) {
      allowed[msg.sender][_spender] = 0;
    } else {
      allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
    }
    Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

}

// File: contracts/B4UCrowdsale.sol

/**
 * @title B4UCrowdsale
 */
contract B4UCrowdsale is PricingPhases {
    using SafeMath for uint256;

    // The token being sold
    StandardToken public token;


    // address where funds are collected
    address public wallet;


    // amount of raised money in wei
    uint256 public weiRaised;

    address public tokenOwner;

    bool public checkKYC;
    mapping (address => bool) public KYCWhitelist;

    // Investor Address -> Investment 
    mapping (address => uint256) public investedAmountOf;
    mapping (address => uint256) public investedTokenOf;    

    address public APIAdminAddress;

    //######### Modifiers #########
    modifier onlyAPIAdmin() {
        require(msg.sender == APIAdminAddress);
        _;
    }

    //######### EVENTS #########

    /**
     * event for token purchase logging
     * @param purchaser who paid for the tokens
     * @param value weis paid for purchase
     * @param amount amount of tokens purchased
     */
    event TokenPurchase(address indexed purchaser, uint256 value, uint256 amount);

    event Whitelisted(address addr, bool status);

    function B4UCrowdsale(uint256 _startTime, uint256 _endTime, uint256 _rate, address _wallet, address _token, address _tokenOwner, uint256 _tokenAvailable) public {
        require(_startTime > 0);
        require(_endTime >= _startTime);
        // require(_rate > 0);
        require(_wallet != address(0));

        token = StandardToken(_token);
        
        wallet = _wallet;
        tokenOwner = _tokenOwner;
        APIAdminAddress = msg.sender;
        startTime = _startTime;
        super.pushNewPhase(_startTime,0,0);
        super.pushNewPhase(_endTime, _rate, _tokenAvailable);
    }

    // fallback function can be used to buy tokens
    function () external payable {
        buy();
    }

    // low level token purchase function
    function buy() public payable {
        require(msg.sender != address(0));
        if(checkKYC && !KYCWhitelist[msg.sender]) {
            throw;
        }
        uint256 weiAmount = msg.value;
        require(weiAmount > 0);
        uint8 currentPhaseIndex = getCurrentPhaseIndex();
        // calculate token amount to be created
        uint256 tokens = getTokenAmount(currentPhaseIndex, weiAmount);

        // To verify Phase sale limit
        require(tokens != 0);

        // update state
        weiRaised = weiRaised.add(weiAmount);
        investedAmountOf[msg.sender] = investedAmountOf[msg.sender].add(weiAmount);
        investedTokenOf[msg.sender] = investedTokenOf[msg.sender].add(tokens);
        
        // add tokens to phases token sold
        phases[currentPhaseIndex].phaseTokensSold = phases[currentPhaseIndex].phaseTokensSold.add(tokens);
        
        token.transferFrom(tokenOwner, msg.sender, tokens);
        
        TokenPurchase(msg.sender, weiAmount, tokens);

        forwardFunds();
    }

    // @return true if crowdsale event has ended
    function hasEnded() public view returns (bool) {
        return checkPurchaseAllowed(getCurrentPhaseIndex(), uint256(1));
    }


    
    // send ether to the fund collection wallet
    // override to create custom fund forwarding mechanisms
    function forwardFunds() internal {
        wallet.transfer(msg.value);
    }

    function setKYCCheck(bool _bSet) public onlyOwner{
        checkKYC = _bSet;
    }

    function setAPIAdmin(address _newAPIAdmin) public onlyOwner {
        require(_newAPIAdmin != address(0));
        APIAdminAddress = _newAPIAdmin;
    }

    function setInvestorKYCWhitelist(address addr, bool status) public onlyAPIAdmin {
        KYCWhitelist[addr] = status;
        Whitelisted(addr, status);
    }
}

pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/token/ERC20/StandardToken.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./PoaCommon.sol";


/**
  @title This acts as a master copy for use with PoaProxy in conjunction
  with PoaCrowdsale. Storage is assumed to be set on PoaProxy through
  delegatecall in fallback function. This contract handles the
  token/dividends functionality of PoaProxy. Inherited PoaCommon dictates
  common storage slots as well as common functions used by both PoaToken
  and PoaCrowdsale.
*/
contract PoaToken is PoaCommon {
  uint256 public constant tokenVersion = 1;

  /**********************************
  * start poaToken specific storage *
  **********************************/

  // ERC20 name of the token
  bytes32 private name32;
  // ERC20 symbol
  bytes32 private symbol32;
  // ERC0 decimals
  uint8 public constant decimals = 18;
  // the total per token payout rate: accumulates as payouts are received
  uint256 public totalPerTokenPayout;
  // the onwer of the contract
  address public owner;
  // used for deducting already claimed payouts on a per token basis
  mapping(address => uint256) public claimedPerTokenPayouts;
  // used for calculating balanceOf by deducting spent balances
  mapping(address => uint256) public spentBalances;
  // used for calculating balanceOf by adding received balances
  mapping(address => uint256) public receivedBalances;
  // allowance of spender to spend owners tokens
  mapping(address => mapping (address => uint256)) internal allowed;

  /********************************
  * end poaToken specific storage *
  ********************************/

  /************************************
  * start non-centrally logged events *
  ************************************/

  event Pause();
  event Unpause();
  event OwnershipTransferred(
    address indexed previousOwner,
    address indexed newOwner
  );
  event Approval(
    address indexed owner,
    address indexed spender,
    uint256 value
  );
  event Transfer(
    address indexed from,
    address indexed to,
    uint256 value
  );

  /**********************************
  * end non-centrally logged events *
  **********************************/

  /******************
  * start modifiers *
  ******************/

  modifier onlyOwner() {
    owner = getContractAddress("PoaManager");
    require(msg.sender == owner);
    _;
  }

  modifier whenNotPaused() {
    require(!paused);
    _;
  }

  modifier whenPaused() {
    require(paused);
    _;
  }

  modifier eitherCustodianOrOwner() {
    owner = getContractAddress("PoaManager");
    require(
      msg.sender == custodian ||
      msg.sender == owner
    );
    _;
  }

  modifier eitherIssuerOrCustodian() {
    require(
      msg.sender == issuer ||
      msg.sender == custodian
    );
    _;
  }

  modifier isTransferWhitelisted(
    address _address
  )
  {
    require(isWhitelisted(_address));
    _;
  }

  /****************
  * end modifiers *
  ****************/

  /**
    @notice Proxied contracts cannot have constructors. This works in place
    of the constructor in order to initialize the contract storage.
  */
  function initializeToken(
    bytes32 _name32, // bytes32 of name string
    bytes32 _symbol32, // bytes32 of symbol string
    address _issuer,
    address _custodian,
    address _registry,
    uint256 _totalSupply // token total supply
  )
    external
    returns (bool)
  {
    // ensure initialize has not been called already
    require(!tokenInitialized);

    // validate and initialize parameters in sequential storage
    setName(_name32);
    setSymbol(_symbol32);
    setIssuerAddress(_issuer);
    setCustodianAddress(_custodian);
    setTotalSupply(_totalSupply);

    owner = getContractAddress("PoaManager");
    registry = _registry;

    paused = true;
    tokenInitialized = true;

    return true;
  }

  /****************************************
  * external setters for `Stages.Preview` *
  *****************************************/

  /**
   * @notice Update name for POA Token
   * @dev Only allowed in `Stages.Preview` by Issuer
   * @param _newName32 The new name
   */
  function updateName(bytes32 _newName32)
    external
    onlyIssuer
    atStage(Stages.Preview)
  {
    setName(_newName32);
  }

  /**
   * @notice Update symbol for POA Token
   * @dev Only allowed in `Stages.Preview` by Issuer
   * @param _newSymbol32 The new symbol
   */
  function updateSymbol(bytes32 _newSymbol32)
    external
    onlyIssuer
    atStage(Stages.Preview)
  {
    setSymbol(_newSymbol32);
  }

  /**
   * @notice Update Issuer address for POA Token
   * @dev Only allowed in `Stages.Preview` by Issuer
   * @param _newIssuer The new Issuer address
   */
  function updateIssuerAddress(address _newIssuer)
    external
    onlyIssuer
    atStage(Stages.Preview)
  {
    setIssuerAddress(_newIssuer);
  }

  /**
   * @notice Update total supply for POA Token
   * @dev Only allowed in `Stages.Preview` by Issuer
   * @param _newTotalSupply The new total supply
   */
  function updateTotalSupply(uint256 _newTotalSupply)
    external
    onlyIssuer
    atStage(Stages.Preview)
  {
    setTotalSupply(_newTotalSupply);
  }

  /********************************************
  * end external setters for `Stages.Preview` *
  *********************************************/

  /*******************************
   * internal validating setters *
   *******************************/

  /**
   * @notice Set name for POA Token
   * @param _newName32 The new name
   */
  function setName(bytes32 _newName32)
    internal
  {
    require(_newName32 != bytes32(0));
    require(_newName32 != name32);

    name32 = _newName32;
  }

  /**
   * @notice Set symbol for POA Token
   * @param _newSymbol32 The new symbol
   */
  function setSymbol(bytes32 _newSymbol32)
    internal
  {
    require(_newSymbol32 != bytes32(0));
    require(_newSymbol32 != symbol32);

    symbol32 = _newSymbol32;
  }

  /**
   * @notice Set Issuer address for POA Token
   * @param _newIssuer The new Issuer address
   */
  function setIssuerAddress(address _newIssuer)
    internal
  {
    require(_newIssuer != address(0));
    require(_newIssuer != issuer);

    issuer = _newIssuer;
  }

  /**
   * @notice Set Custodian address for POA Token
   * @param _newCustodian The new Custodian address
   */
  function setCustodianAddress(address _newCustodian)
    internal
  {
    require(_newCustodian != address(0));
    require(_newCustodian != custodian);

    custodian = _newCustodian;
  }

  /**
   * @notice Set total supply for POA token
   * @dev Assuming 18 decimals, the total supply must
   *      be greather than 1e18
   * @param _newTotalSupply The new total supply
   */
  function setTotalSupply(uint256 _newTotalSupply)
    internal
  {
    require(_newTotalSupply >= 1e18);
    require(fundingGoalInCents < _newTotalSupply);
    require(_newTotalSupply != totalSupply_);

    totalSupply_ = _newTotalSupply;
  }

  /***********************************
   * end internal validating setters *
   ***********************************/

  /****************************
  * start lifecycle functions *
  ****************************/

  /**
   * @notice Change Custodian address for POA Token
   * @dev Only old Custodian is able to change his own
   *      address (`onlyCustodian` modifier)
   * @dev This change is allowed at any stage and is
   *      logged via PoaManager
   * @param _newCustodian The new Custodian address
   * @return true when successful
   */
  function changeCustodianAddress(address _newCustodian)
    external
    onlyCustodian
    returns (bool)
  {
    getContractAddress("PoaLogger").call(
      abi.encodeWithSignature(
        "logCustodianChanged(address,address)",
        custodian,
        _newCustodian
      )
    );

    setCustodianAddress(_newCustodian);

    return true;
  }

  /**
   * @notice Move from `Stages.Preview` to `Stages.PreFunding`
   * @dev After calling this function, the token parameters
   *      become immutable
   * @dev Only allowed in `Stages.Preview` by Issuer
   * @dev We need to revalidate the time-related token parameters here
  */
  function startPreFunding()
    external
    onlyIssuer
    atStage(Stages.Preview)
    returns (bool)
  {
    // check that `startTimeForFundingPeriod` lies in the future
    // solium-disable-next-line security/no-block-members
    require(startTimeForFundingPeriod > block.timestamp);

    // set Stage to PreFunding
    enterStage(Stages.PreFunding);

    return true;
  }

  /**
    @notice Used when asset should no longer be tokenized.
    Allows for winding down via payouts, and freeze trading
  */
  function terminate()
    external
    eitherCustodianOrOwner
    atStage(Stages.Active)
    returns (bool)
  {
    // set Stage to terminated
    enterStage(Stages.Terminated);
    // pause. Cannot be unpaused now that in Stages.Terminated
    paused = true;
    getContractAddress("PoaLogger").call(
      abi.encodeWithSignature("logTerminated()")
    );

    return true;
  }

  /**************************
  * end lifecycle functions *
  **************************/

  /************************
  * start owner functions *
  ************************/

  function pause()
    public
    onlyOwner
    whenNotPaused
  {
    paused = true;
    emit Pause();
  }

  function unpause()
    public
    onlyOwner
    whenPaused
    atStage(Stages.Active)
  {
    paused = false;
    emit Unpause();
  }

  /**********************
  * end owner functions *
  **********************/

  /*************************
  * start getter functions *
  *************************/

  /// @notice returns string coverted from bytes32 representation of name
  function name()
    external
    view
    returns (string)
  {
    return to32LengthString(name32);
  }

  /// @notice returns strig converted from bytes32 representation of symbol
  function symbol()
    external
    view
    returns (string)
  {
    return to32LengthString(symbol32);
  }

  function totalSupply()
    public
    view
    returns (uint256)
  {
    return totalSupply_;
  }

  /***********************
  * end getter functions *
  ***********************/

  /*********************************
  * start payout related functions *
  *********************************/

  /// @notice get current payout for perTokenPayout and unclaimed
  function currentPayout(
    address _address,
    bool _includeUnclaimed
  )
    public
    view
    returns (uint256)
  {
    /**
      @dev Need to check if there have been no payouts, otherwise safe math
      will throw due to dividing by 0.
      The below variable represents the total payout from the per token rate pattern.
      It uses this funky naming pattern in order to differentiate from the unclaimedPayoutTotals
      which means something very different.
    */
    uint256 _totalPerTokenUnclaimedConverted = totalPerTokenPayout == 0
      ? 0
      : balanceOf(_address)
      .mul(totalPerTokenPayout.sub(claimedPerTokenPayouts[_address]))
      .div(1e18);

    /**
      @dev Balances may be bumped into unclaimedPayoutTotals in order to
      maintain balance tracking accross token transfers.
      Per token payout rates are stored * 1e18 in order to be kept accurate
      per token payout is / 1e18 at time of usage for actual Ξ balances
      `unclaimedPayoutTotals` are stored as actual Ξ value no need for rate * balance
    */
    return _includeUnclaimed
      ? _totalPerTokenUnclaimedConverted.add(unclaimedPayoutTotals[_address])
      : _totalPerTokenUnclaimedConverted;
  }

  /// @notice settle up perToken balances and move into unclaimedPayoutTotals in order
  /// to ensure that token transfers will not result in inaccurate balances
  function settleUnclaimedPerTokenPayouts(
    address _from,
    address _to
  )
    internal
    returns (bool)
  {
    // add perToken balance to unclaimedPayoutTotals which will not be affected by transfers
    unclaimedPayoutTotals[_from] = unclaimedPayoutTotals[_from]
      .add(currentPayout(_from, false));
    // max out claimedPerTokenPayouts in order to effectively make perToken balance 0
    claimedPerTokenPayouts[_from] = totalPerTokenPayout;
    // same as above for to
    unclaimedPayoutTotals[_to] = unclaimedPayoutTotals[_to]
      .add(currentPayout(_to, false));
    // same as above for to
    claimedPerTokenPayouts[_to] = totalPerTokenPayout;

    return true;
  }

  /// @notice send Ξ to contract to be claimed by token holders
  function payout()
    external
    payable
    eitherIssuerOrCustodian
    atEitherStage(Stages.Active, Stages.Terminated)
    returns (bool)
  {
    // calculate fee based on feeRateInPermille
    uint256 _fee = calculateFee(msg.value);
    // ensure the value is high enough for a fee to be claimed
    require(_fee > 0);
    // deduct fee from payout
    uint256 _payoutAmount = msg.value.sub(_fee);
    /*
      totalPerTokenPayout is a rate at which to payout based on token balance.
      It is stored as * 1e18 in order to keep accuracy
      It is / 1e18 when used relating to actual Ξ values
    */
    totalPerTokenPayout = totalPerTokenPayout
      .add(_payoutAmount
        .mul(1e18)
        .div(totalSupply_)
      );

    // take remaining dust and send to feeManager rather than leave stuck in
    // contract. should not be more than a few wei
    uint256 _delta = (_payoutAmount.mul(1e18) % totalSupply_).div(1e18);
    // pay fee along with any dust to FeeManager
    payFee(_fee.add(_delta));
    getContractAddress("PoaLogger").call(
      abi.encodeWithSignature(
        "logPayout(uint256)",
        _payoutAmount.sub(_delta)
      )
    );

    return true;
  }

  /// @notice claim total eth claimable for sender based on token holdings at time of each payout
  function claim()
    external
    atEitherStage(Stages.Active, Stages.Terminated)
    returns (uint256)
  {
    /*
      pass true to currentPayout in order to get both:
      - perToken payouts
      - unclaimedPayoutTotals
    */
    uint256 _payoutAmount = currentPayout(msg.sender, true);
    // check that there indeed is a pending payout for sender
    require(_payoutAmount > 0);
    // max out per token payout for sender in order to make payouts effectively
    // 0 for sender
    claimedPerTokenPayouts[msg.sender] = totalPerTokenPayout;
    // 0 out unclaimedPayoutTotals for user
    unclaimedPayoutTotals[msg.sender] = 0;
    // transfer Ξ payable amount to sender
    msg.sender.transfer(_payoutAmount);
    getContractAddress("PoaLogger").call(
      abi.encodeWithSignature(
        "logClaim(address,uint256)",
        msg.sender,
        _payoutAmount
      )
    );

    return _payoutAmount;
  }

  /**
   @notice Allow proof-of-custody IPFS hash to be updated.
     This is used for both initial upload as well as changing
     or adding more documents later. The first proof-of-custody
     will be a legal document in which the custodian certifies
     that have received the actual securities that this contract
     tokenizes.
   */
  function updateProofOfCustody(bytes32[2] _ipfsHash)
    external
    onlyCustodian
    validIpfsHash(_ipfsHash)
    returns (bool)
  {
    require(
      stage == Stages.Active || stage == Stages.FundingSuccessful || stage == Stages.Terminated
    );
    proofOfCustody32_ = _ipfsHash;
    getContractAddress("PoaLogger").call(
      abi.encodeWithSignature(
        "logProofOfCustodyUpdated()",
        _ipfsHash
      )
    );

    return true;
  }

  /*******************************
  * end payout related functions *
  *******************************/

  /************************
  * start ERC20 overrides *
  ************************/

  /// @notice used for calculating starting balance once activated
  function startingBalance(address _address)
    public
    view
    returns (uint256)
  {
    if (stage < Stages.Active) {
      return 0;
    }

    if (isFiatInvestor(_address)) { 
      return fundedFiatAmountPerUserInTokens[_address];
    }

    if (isEthInvestor(_address)) {
      return fundedEthAmountPerUserInWei[_address]
        .mul(totalSupply_.sub(fundedFiatAmountInTokens))
        .div(fundedEthAmountInWei);
    }

    return 0;
  }

  /// @notice ERC20 compliant balanceOf: uses NoobCoin pattern: https://github.com/TovarishFin/NoobCoin
  function balanceOf(address _address)
    public
    view
    returns (uint256)
  {
    return startingBalance(_address)
      .add(receivedBalances[_address])
      .sub(spentBalances[_address]);
  }

  /**
    @notice ERC20 compliant transfer:
    - uses NoobCoin pattern combined with settling payout balances: https://github.com/TovarishFin/NoobCoin
  */
  function transfer(
    address _to,
    uint256 _value
  )
    public
    whenNotPaused
    isTransferWhitelisted(_to)
    isTransferWhitelisted(msg.sender)
    returns (bool)
  {
    // move perToken payout balance to unclaimedPayoutTotals
    settleUnclaimedPerTokenPayouts(msg.sender, _to);

    require(_to != address(0));
    require(_value <= balanceOf(msg.sender));
    spentBalances[msg.sender] = spentBalances[msg.sender].add(_value);
    receivedBalances[_to] = receivedBalances[_to].add(_value);
    emit Transfer(msg.sender, _to, _value);

    return true;
  }

  /**
    @notice ERC20 compliant transferFrom:
    - uses NoobCoin pattern combined with settling payout balances: https://github.com/TovarishFin/NoobCoin
  */
  function transferFrom(
    address _from,
    address _to,
    uint256 _value
  )
    public
    whenNotPaused
    isTransferWhitelisted(_to)
    isTransferWhitelisted(_from)
    returns (bool)
  {
    // move perToken payout balance to unclaimedPayoutTotals
    settleUnclaimedPerTokenPayouts(_from, _to);

    require(_to != address(0));
    require(_value <= balanceOf(_from));
    require(_value <= allowed[_from][msg.sender]);
    spentBalances[_from] = spentBalances[_from].add(_value);
    receivedBalances[_to] = receivedBalances[_to].add(_value);
    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
    emit Transfer(_from, _to, _value);

    return true;
  }

  /**
    @notice ERCO compliant approve
  */
  function approve(
    address _spender,
    uint256 _value
  )
    public
    whenNotPaused
    returns (bool)
  {
    allowed[msg.sender][_spender] = _value;
    emit Approval(msg.sender, _spender, _value);

    return true;
  }

  /**
    @notice openZeppelin implementation of increaseApproval
  */
  function increaseApproval(
    address _spender,
    uint _addedValue
  )
    public
    whenNotPaused
    returns (bool success)
  {
    allowed[msg.sender][_spender] = (
      allowed[msg.sender][_spender].add(_addedValue));
    emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);

    return true;
  }

  /**
    @notice openZeppelin implementation of decreaseApproval
  */
  function decreaseApproval(
    address _spender,
    uint _subtractedValue
  )
    public
    whenNotPaused
    returns (bool success)
  {
    uint256 oldValue = allowed[msg.sender][_spender];
    if (_subtractedValue > oldValue) {
      allowed[msg.sender][_spender] = 0;
    } else {
      allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
    }
    emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);

    return true;
  }

  /**
  @notice ERC20 compliant allowance
  */
  function allowance(
    address _owner,
    address _spender
  )
    public
    view
    returns (uint256)
  {
    return allowed[_owner][_spender];
  }

  /************************
  * start ERC20 overrides *
  ************************/

  /// @notice forward any non-matching function calls to poaCrowdsaleMaster
  function()
    external
    payable
  {
    assembly {
      // load value using *_slot suffix
      let _poaCrowdsaleMaster := sload(poaCrowdsaleMaster_slot)
      // calldatacopy(t, f, s)
      calldatacopy(
        0x0, // t = mem position to
        0x0, // f = mem position from
        calldatasize // s = size bytes
      )

      // delegatecall(g, a, in, insize, out, outsize) => 0 on error 1 on success
      let result := delegatecall(
        gas, // g = gas
        _poaCrowdsaleMaster, // a = address
        0x0, // in = mem in  mem[in..(in+insize)
        calldatasize, // insize = mem insize  mem[in..(in+insize)
        0x0, // out = mem out  mem[out..(out+outsize)
        0 // outsize = mem outsize  mem[out..(out+outsize)
      )

      // check if call was a success and return if no errors & revert if errors
      if iszero(result) {
        revert(0, 0)
      }

      // returndatacopy(t, f, s)
      returndatacopy(
        0x0, // t = mem position to
        0x0,  // f = mem position from
        returndatasize // s = size bytes
      )

      return(
        0x0,
        returndatasize
      )
    }
  }
}

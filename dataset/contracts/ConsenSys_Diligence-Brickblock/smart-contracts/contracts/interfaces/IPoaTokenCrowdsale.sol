pragma solidity 0.4.24;

// this is meant to be a combined interface of PoaToken and PoaCrowdsale
// the resulting ABI can be used for calling both PoaToken and PoaCrowdsale functions
interface IPoaTokenCrowdsale {

  //
  // start token functionality
  //

  function owner()
    external
    view
    returns (address);

  function decimals()
    external
    view
    returns (uint256);

  function totalPerTokenPayout()
    external
    view
    returns (uint256);

  function claimedPerTokenPayouts(address _address)
    external
    view
    returns (uint256);

  function startingBalance(address _address)
    external
    view
    returns (uint256);

  function spentBalances(address _address)
    external
    view
    returns (uint256);

  function receivedBalances(address _address)
    external
    view
    returns (uint256);

  function initializeToken(
    bytes32 _name32, // bytes32 of name string
    bytes32 _symbol32, // bytes32 of symbol string
    address _issuer,
    address _custodian,
    address _registry,
    uint256 _totalSupply // token total supply
  )
    external
    returns (bool);

  // setters in `Preview` stage
  function updateName(
    bytes32 _newName
  )
    external;

  function updateSymbol(
    bytes32 _newSymbol
  )
    external;

  function updateIssuerAddress(
    address _newIssuer
  )
    external;

  function updateTotalSupply(
    uint256 _newTotalSupply
  )
    external;

  function updateFiatCurrency(
    bytes32 _newFiatCurrency
  )
    external;

  function updateFundingGoalInCents(
    uint256 _newFundingGoalInCents
  )
    external;

  function updateStartTimeForFundingPeriod(
    uint256 _newStartTimeForFundingPeriod
  )
    external;

  function updateDurationForEthFundingPeriod(
    uint256 _newDurationForEthFundingPeriod
  )
    external;

  function updateDurationForActivationPeriod(
    uint256 _newDurationForActivationPeriod
  )
    external;

  function changeCustodianAddress(
    address _newCustodian
  )
    external
    returns (bool);

  function terminate()
    external
    returns (bool);

  function pause()
    external;

  function unpause()
    external;

  function name()
    external
    view
    returns (string);

  function symbol()
    external
    view
    returns (string);

  function isActivationFeePaid()
    external
    view
    returns (bool);

  function currentPayout(
    address _address,
    bool _includeUnclaimed
  )
    external
    view
    returns (uint256);

  function payout()
    external
    payable
    returns (bool);

  function claim()
    external
    returns (uint256);

  function updateProofOfCustody(
    bytes32[2] _ipfsHash
  )
    external
    returns (bool);

  function balanceOf(
    address _address
  )
    external
    view
    returns (uint256);

  function transfer(
    address _to,
    uint256 _value
  )
    external
    returns (bool);

  function transferFrom(
    address _from,
    address _to,
    uint256 _value
  )
    external
    returns (bool);

  function paused()
    external
    view
    returns (bool _paused);

  function allowance(
    address _owner,
    address _spender
  )
    external
    view
    returns (uint256);

  function approve(
    address _spender,
    uint256 _value
  )
    external
    returns (bool);


  //
  // end token functionality
  //

  //
  // start crowdsale functionality
  //

  function precisionOfPercentCalc()
    external
    returns (uint256);

  function initializeCrowdsale(
    bytes32 _fiatCurrency32,                // fiat currency string, e.g. 'EUR'
    uint256 _startTimeForFundingPeriod,     // future UNIX timestamp
    uint256 _durationForFiatFundingPeriod,  // duration of fiat funding period in seconds
    uint256 _durationForEthFundingPeriod,   // duration of ETH funding period in seconds
    uint256 _durationForActivationPeriod,   // duration of activation period in seconds
    uint256 _fundingGoalInCents             // funding goal in fiat cents
  )
    external
    returns (bool);

  function startPreFunding()
    external
    returns (bool);

  function startFiatSale()
    external
    returns (bool);

  function startEthSale()
    external
    returns (bool);

  function calculateTokenAmountForAmountInCents(
    uint256 _amountInCents
  )
    external
    returns (uint256);

  function buyWithFiat(
    address _fiatInvestor,
    uint256 _amountInCents
  )
    external
    returns (bool);

  function removeFiat(
    address _fiatInvestor,
    uint256 _amountInCents
  )
    external
    returns (bool);

  function buyWithEth()
    external
    payable
    returns (bool);

  function calculateTotalFee()
    external
    view
    returns (uint256);

  function payActivationFee()
    external
    payable
    returns (bool);

  function activate()
    external
    returns (bool);

  function manualCheckForTimeout()
    external
    returns (bool);

  function reclaim()
    external
    returns (bool);

  function cancelFunding()
    external
    returns (bool);

  function getFiatRate()
    external
    view
    returns (uint256 _fiatRate);

  function percent(
    uint256 numerator,
    uint256 denominator,
    uint256 precision
  )
    external
    returns (uint256 quotient);

  function weiToFiatCents(uint256 _wei)
    external
    view
    returns (uint256);

  function fiatCentsToWei(uint256 _cents)
    external
    view
    returns (uint256);

  function fundedEthAmountInCents()
    external
    view
    returns (uint256);

  function fundingGoalInWei()
    external
    view
    returns (uint256);

  function fiatCurrency()
    external
    view
    returns (string);

  function crowdsaleInitialized()
    external
    view
    returns (bool _crowdsaleInitialized);

  function startTimeForFundingPeriod()
    external
    view
    returns (uint256 _startTimeForFundingPeriod);

  function durationForFiatFundingPeriod()
    external
    view
    returns (uint256 _durationForFiatFundingPeriod);

  function durationForEthFundingPeriod()
    external
    view
    returns (uint256 _durationForEthFundingPeriod);

  function durationForActivationPeriod()
    external
    view
    returns (uint256 _durationForActivationPeriod);

  function fundingGoalInCents()
    external
    view
    returns (uint256 _fundingGoalInCents);

  function fundedFiatAmountInCents()
    external
    view
    returns (uint256 _fundedFiatAmountInCents);

  function issuer()
    external
    view
    returns (address _issuer);

  function manualCheckForFundingSuccessful()
    external
    returns (bool);

  function isFundingGoalReached(uint256 _withWeiAmount)
    external
    view
    returns (bool);

  //
  // end crowdsale functionality
  //

  //
  // start common functionality
  //

  function feeRateInPermille()
    external
    view
    returns (uint256);

  function calculateFee(
    uint256 _value
  )
    external
    pure
    returns (uint256);

  function getContractAddress(
    string _name
  )
    external
    view
    returns (address _contractAddress);

  function isWhitelisted(
    address _address
  )
    external
    view
    returns (bool _isWhitelisted);

  function proofOfCustody()
    external
    view
    returns (string);

  function stage()
    external
    view
    returns (uint256 _stage);

  function totalSupply()
    external
    view
    returns (uint256 _totalSupply);

  function fundedFiatAmountInTokens()
    external
    view
    returns (uint256 _fundedFiatAmountInTokens);

  function fundedFiatAmountPerUserInTokens(
    address _address
  )
    external
    view
    returns (uint256 _fiatInvested);

  function fundedEthAmountInWei()
    external
    view
    returns (uint256 _fundedEthAmountInWei);

  function fundedEthAmountPerUserInWei(
    address _address
  )
    external
    view
    returns (uint256 _fundedEthAmountPerUserInWei);

  function registry()
    external
    view
    returns (address _registry);

  function unclaimedPayoutTotals(
    address _address
  )
    external
    view
    returns (uint256 _unclaimedPayoutTotals);

  function tokenInitialized()
    external
    view
    returns (bool _tokenInitialized);

  function poaCrowdsaleMaster()
    external
    view
    returns (address _poaCrowdsaleMaster);

  function custodian()
    external
    view
    returns (address _custodian);

  function crowdsaleVersion()
    external
    view
    returns (uint256);

  function tokenVersion()
    external
    view
    returns (uint256);

  function poaTokenMaster()
    external
    view
    returns (address);

  //
  // end common functionality
  //
}

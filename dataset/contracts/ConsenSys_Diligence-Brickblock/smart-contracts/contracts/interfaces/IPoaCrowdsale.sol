pragma solidity 0.4.24;

interface IPoaCrowdsale {
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
}

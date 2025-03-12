pragma solidity ^0.4.19;

import "../token/ERC20/ERC20Interface.sol";
import "../math/SafeMath.sol";
import "./TokenSaleManager.sol";
import "../crowdsale/distribution/FinalizableCrowdsale.sol";
import "../crowdsale/validation/WhitelistedCrowdsale.sol";

contract TokenSale is FinalizableCrowdsale,
                      WhitelistedCrowdsale {
    using SafeMath for uint256;

    address public managerAddr; 
    address public poolAddr;
    bool public isInitialized = false;
    uint256 public timeLockRate;
    uint256 public timeLockEnd;
    uint256 public tokensMinted = 0;
    uint256 public tokensCap;
    uint256 public minAcceptableWei;
    bool public carryover;

    modifier onlyManager{
        require(msg.sender == managerAddr);
        _;
    }

    function TokenSale (
        uint256 _rate, /* The unit of rate is [nano tokens / ETH] in this contract */
        ERC20Interface _token,
        address _poolAddr,
        uint256 _openingTime,
        uint256 _closingTime,
        uint256 _tokensCap,
        uint256 _timeLockRate,
        uint256 _timeLockEnd,
        bool _carryover,
        uint256 _minAcceptableWei
    ) public Crowdsale(_rate, _poolAddr, _token) TimedCrowdsale(_openingTime, _closingTime) {
        managerAddr = msg.sender;
        poolAddr = _poolAddr;
        timeLockRate = _timeLockRate;
        timeLockEnd = _timeLockEnd;
        tokensCap = _tokensCap;
        carryover = _carryover;
        minAcceptableWei = _minAcceptableWei;
    }

    function initialize(uint256 carryoverAmount) external onlyManager {
        require(!isInitialized);
        isInitialized = true;
        tokensCap = tokensCap.add(carryoverAmount);
    }

    function finalize() onlyOwner public {
        //require(!isFinalized);
        require(isInitialized);
        require(canFinalize());

        finalization();
        Finalized();

        isFinalized = true;
    }

    function canFinalize() public constant returns(bool) {
        return (hasClosed() || (isInitialized && tokensCap <= tokensMinted));
    }


    function finalization() internal {
        if(address(this).balance > 0){
            poolAddr.transfer(address(this).balance);
        }
    }

    /**
     * @dev Overrides delivery by minting tokens upon purchase.
     * @param _beneficiary Token purchaser
     * @param _tokenAmount Number of tokens to be minted
     */
    function _deliverTokens(address _beneficiary, uint256 _tokenAmount) internal {
        //require(tokensMinted.add(_tokenAmount) <= tokensCap);
        require(tokensMinted < tokensCap);

        uint256 time_locked = _tokenAmount.mul(timeLockRate).div(100); 
        uint256 instant = _tokenAmount.sub(time_locked);

        if (instant > 0) {
            require(TokenSaleManager(managerAddr).mint(_beneficiary, instant));
        }
        if (time_locked > 0) {
            require(TokenSaleManager(managerAddr).mintTimeLocked(
                _beneficiary,
                time_locked,
                timeLockEnd
            ));
        }
  
        tokensMinted = tokensMinted.add(_tokenAmount);
    }

    function _forwardFunds() internal {}

    function _preValidatePurchase(address _beneficiary, uint256 _weiAmount) internal {
        super._preValidatePurchase(_beneficiary, _weiAmount);
        require(isInitialized);
        require(_weiAmount >= minAcceptableWei);
    }

    /**
     * @dev Overridden in order to change the unit of rate with [nano toekns / ETH]
     * instead of original [minimal unit of the token / wei].
     * @param _weiAmount Value in wei to be converted into tokens
     * @return Number of tokens that can be purchased with the specified _weiAmount
     */
    function _getTokenAmount(uint256 _weiAmount) internal view returns (uint256) {
      return _weiAmount.mul(rate).div(10**18); //The unit of rate is [nano tokens / ETH].
    }

}

pragma solidity ^0.4.21;

import "./zeppelin-solidity/contracts/math/SafeMath.sol";
import "./zeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "./zeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract ICOStartSale is Pausable {
  using SafeMath for uint256;

  struct Period {
    uint256 startTimestamp;
    uint256 endTimestamp;
    uint256 rate;
  }

  Period[] private periods;
  mapping(address => bool) public whitelistedAddresses;
  mapping(address => uint256) public whitelistedRates;
  using SafeMath for uint256;

  ERC20 public token;
  address public wallet;
  address public tokenWallet;
  uint256 public weiRaised;

  /**
   * @dev A purchase was made.
   * @param _purchaser Who paid for the tokens.
   * @param _value Total purchase price in weis.
   * @param _amount Amount of tokens purchased.
   */
  event TokensPurchased(address indexed _purchaser, uint256 _value, uint256 _amount);

  uint256 constant public MINIMUM_AMOUNT = 0.05 ether;
  uint256 constant public MAXIMUM_NON_WHITELIST_AMOUNT = 5 ether;

  /**
   * @dev Constructor, takes initial parameters.
   * @param _wallet Address where collected funds will be forwarded to.
   * @param _token Address of the token being sold.
   * @param _tokenWallet Address holding the tokens, which has approved allowance to this contract.
   */
  function ICOStartSale(address _wallet, ERC20 _token, address _tokenWallet) public {
    require(_wallet != address(0));
    require(_token != address(0));
    require(_tokenWallet != address(0));

    wallet = _wallet;
    token = _token;
    tokenWallet = _tokenWallet;
  }

  /**
   * @dev Send weis, get tokens.
   */
  function () external payable {
    // Preconditions.
    require(msg.sender != address(0));
    require(msg.value >= MINIMUM_AMOUNT);
    require(isOpen());
    if (msg.value > MAXIMUM_NON_WHITELIST_AMOUNT) {
      if (!isAddressInWhitelist(msg.sender)) {
        revert();
      }
    }

    uint256 tokenAmount = getTokenAmount(msg.sender, msg.value);
    weiRaised = weiRaised.add(msg.value);

    token.transferFrom(tokenWallet, msg.sender, tokenAmount);
    emit TokensPurchased(msg.sender, msg.value, tokenAmount);

    wallet.transfer(msg.value);
  }

  /**
   * @dev Add a sale period with its default rate.
   * @param _startTimestamp Beginning of this sale period.
   * @param _endTimestamp End of this sale period.
   * @param _rate Rate at which tokens are sold during this sale period.
   */
  function addPeriod(uint256 _startTimestamp, uint256 _endTimestamp, uint256 _rate) onlyOwner public {
    require(_startTimestamp != 0);
    require(_endTimestamp > _startTimestamp);
    require(_rate != 0);
    Period memory period = Period(_startTimestamp, _endTimestamp, _rate);
    periods.push(period);
  }

  /**
   * @dev Emergency function to clear all sale periods (for example in case the sale is delayed).
   */
  function clearPeriods() onlyOwner public {
    delete periods;
  }

  /**
   * @dev Add an address to the whitelist or update the rate of an already added address.
   * This function cannot be used to reset a previously set custom rate. Remove the address and add it
   * again if you need to do that.
   * @param _address Address to whitelist
   * @param _rate Optional custom rate reserved for that address (0 = use default rate)
   * @return true if the address was added to the whitelist, false if the address was already in the whitelist
   */
  function addAddressToWhitelist(address _address, uint256 _rate) onlyOwner public returns (bool success) {
    require(_address != address(0));
    success = false;
    if (!whitelistedAddresses[_address]) {
      whitelistedAddresses[_address] = true;
      success = true;
    }
    if (_rate != 0) {
      whitelistedRates[_address] = _rate;
    }
  }

  /**
   * @dev Adds an array of addresses to the whitelist, all with the same optional custom rate.
   * @param _addresses Addresses to add.
   * @param _rate Optional custom rate reserved for all added addresses (0 = use default rate).
   * @return true if at least one address was added to the whitelist,
   * false if all addresses were already in the whitelist  
   */
  function addAddressesToWhitelist(address[] _addresses, uint256 _rate) onlyOwner public returns (bool success) {
    success = false;
    for (uint256 i = 0; i <_addresses.length; i++) {
      if (addAddressToWhitelist(_addresses[i], _rate)) {
        success = true;
      }
    }
  }

  /**
   * @dev Remove an address from the whitelist.
   * @param _address Address to remove.
   * @return true if the address was removed from the whitelist, 
   * false if the address wasn't in the whitelist in the first place.
   */
  function removeAddressFromWhitelist(address _address) onlyOwner public returns (bool success) {
    require(_address != address(0));
    success = false;
    if (whitelistedAddresses[_address]) {
      whitelistedAddresses[_address] = false;
      success = true;
    }
    if (whitelistedRates[_address] != 0) {
      whitelistedRates[_address] = 0;
    }
  }

  /**
   * @dev Remove addresses from the whitelist.
   * @param _addresses addresses
   * @return true if at least one address was removed from the whitelist, 
   * false if all addresses weren't in the whitelist in the first place
   */
  function removeAddressesFromWhitelist(address[] _addresses) onlyOwner public returns (bool success) {
    success = false;
    for (uint256 i = 0; i < _addresses.length; i++) {
      if (removeAddressFromWhitelist(_addresses[i])) {
        success = true;
      }
    }
  }

  /**
   * @dev True if the specified address is whitelisted.
   */
  function isAddressInWhitelist(address _address) view public returns (bool) {
    return whitelistedAddresses[_address];
  }

  /**
   * @dev True while the sale is open (i.e. accepting contributions). False otherwise.
   */
  function isOpen() view public returns (bool) {
    return ((!paused) && (_getCurrentPeriod().rate != 0));
  }

  /**
   * @dev Current rate for the specified purchaser.
   * @param _purchaser Purchaser address (may or may not be whitelisted).
   * @return Custom rate for the purchaser, or current standard rate if no custom rate was whitelisted.
   */
  function getCurrentRate(address _purchaser) public view returns (uint256 rate) {
    Period memory currentPeriod = _getCurrentPeriod();
    require(currentPeriod.rate != 0);
    rate = whitelistedRates[_purchaser];
    if (rate == 0) {
      rate = currentPeriod.rate;
    }
  }

  /**
   * @dev Number of tokens that a specified address would get by sending right now
   * the specified amount.
   * @param _purchaser Purchaser address (may or may not be whitelisted).
   * @param _weiAmount Value in wei to be converted into tokens.
   * @return Number of tokens that can be purchased with the specified _weiAmount.
   */
  function getTokenAmount(address _purchaser, uint256 _weiAmount) public view returns (uint256) {
    return _weiAmount.mul(getCurrentRate(_purchaser));
  }

  /**
   * @dev Checks the amount of tokens left in the allowance.
   * @return Amount of tokens remaining for sale.
   */
  function remainingTokens() public view returns (uint256) {
    return token.allowance(tokenWallet, this);
  }

  /*
   * Internal functions
   */

  /**
   * @dev Returns the current period, or null.
   */
  function _getCurrentPeriod() view internal returns (Period memory _period) {
    _period = Period(0, 0, 0);
    for (uint256 i = 0; i < periods.length; i++) {
      if ((periods[i].startTimestamp <= block.timestamp) && (periods[i].endTimestamp >= block.timestamp)) {
        _period = periods[i];
        break;
      }
    }
  }

}

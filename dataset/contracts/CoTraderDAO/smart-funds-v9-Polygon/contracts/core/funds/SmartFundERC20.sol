pragma solidity ^0.6.12;

import "./SmartFundCore.sol";
import "../interfaces/PermittedAddressesInterface.sol";


/*
  Note: this smart fund smart fund inherits SmartFundCore and make core operations like deposit,
  calculate fund value etc in ERC20
*/
contract SmartFundERC20 is SmartFundCore {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  // State for recognize if this fund stable asset based
  bool public isStableCoinBasedFund;

  /**
  * @dev constructor
  *
  * @param _owner                        Address of the fund manager
  * @param _name                         Name of the fund, required for DetailedERC20 compliance
  * @param _successFee                   Percentage of profit that the fund manager receives
  * @param _platformAddress              Address of platform to send fees to
  * @param _exchangePortalAddress        Address of initial exchange portal
  * @param _permittedAddresses           Address of permittedAddresses contract
  * @param _isRequireTradeVerification   If true fund will require verification from Merkle White list for each new asset
  */
  constructor(
    address _owner,
    string memory _name,
    uint256 _successFee,
    address _platformAddress,
    address _exchangePortalAddress,
    address _permittedAddresses,
    address _coinAddress,
    bool    _isRequireTradeVerification
  )
  SmartFundCore(
    _owner,
    _name,
    _successFee,
    _platformAddress,
    _exchangePortalAddress,
    _permittedAddresses,
    _coinAddress,
    _isRequireTradeVerification
  )
  public {
    // Initial stable coint permitted interface
    permittedAddresses = PermittedAddressesInterface(_permittedAddresses);
    // Push coin in tokens list
    _addToken(_coinAddress);
    // Define is stable based fund
    isStableCoinBasedFund = permittedAddresses.isMatchTypes(_coinAddress, 4);
  }

  /**
  * @dev Deposits core coin into the fund and allocates a number of shares to the sender
  * depending on the current number of shares, the funds value, and amount deposited
  *
  * @return The amount of shares allocated to the depositor
  */
  function deposit(uint256 depositAmount) external returns (uint256) {
    // Check if the sender is allowed to deposit into the fund
    if (onlyWhitelist)
      require(whitelist[msg.sender]);

    // Require that the amount sent is not 0
    require(depositAmount > 0, "ZERO_DEPOSIT");

    // Transfer core ERC20 coin from sender
    require(IERC20(coreFundAsset).transferFrom(msg.sender, address(this), depositAmount),
    "TRANSFER_FROM_ISSUE");

    totalWeiDeposited += depositAmount;

    // Calculate number of shares
    uint256 shares = calculateDepositToShares(depositAmount);

    // If user would receive 0 shares, don't continue with deposit
    require(shares != 0, "ZERO_SHARES");

    // Add shares to total
    totalShares = totalShares.add(shares);

    // Add shares to address
    addressToShares[msg.sender] = addressToShares[msg.sender].add(shares);

    addressesNetDeposit[msg.sender] += int256(depositAmount);

    emit Deposit(msg.sender, depositAmount, shares, totalShares);

    return shares;
  }


  /**
  * @dev Calculates the funds value in deposited token
  *
  * @return The current total fund value
  */
  function calculateFundValue() public override view returns (uint256) {
    // Convert ETH balance to core ERC20
    uint256 ethBalance = exchangePortal.getValue(
      address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
      coreFundAsset,
      address(this).balance
    );

    // cache global var for save gas
    uint256 tokenAddressesLength = tokenAddresses.length;

    // If the fund only contains ether, return the funds ether balance converted in core ERC20
    if (tokenAddressesLength == 1)
      return ethBalance;

    // Otherwise, we get the value of all the other tokens in ether via exchangePortal

    // Calculate value for ERC20
    address[] memory fromAddresses = new address[](tokenAddressesLength - 2); // sub ETH + curernt core ERC20
    uint256[] memory amounts = new uint256[](tokenAddressesLength - 2);
    uint8 index = 0;

    // get all ERC20 addresses and balance
    for (uint8 i = 2; i < tokenAddressesLength; i++) {
      fromAddresses[index] = tokenAddresses[i];
      amounts[index] = IERC20(tokenAddresses[i]).balanceOf(address(this));
      index++;
    }
    // Ask the Exchange Portal for the value of all the funds tokens in core coin
    uint256 tokensValue = exchangePortal.getTotalValue(fromAddresses, amounts, coreFundAsset);

    // Get curernt core ERC20 token balance
    uint256 currentERC20 = IERC20(coreFundAsset).balanceOf(address(this));

    // Sum ETH in ERC20 + Current ERC20 Token + ERC20 in ERC20
    return ethBalance + currentERC20 + tokensValue;
  }


  /**
  * @dev get balance of input asset address in current core ERC20 ratio
  *
  * @param _token     token address
  *
  * @return balance in core ERC20
  */
  function getTokenValue(IERC20 _token) public override view returns (uint256) {
    // get ETH in core ERC20
    if (_token == IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)){
      return exchangePortal.getValue(
        address(_token),
        coreFundAsset,
        address(this).balance);
    }
    // get current core ERC20
    else if(_token == IERC20(coreFundAsset)){
      return _token.balanceOf(address(this));
    }
    // get ERC20 in core ERC20
    else{
      uint256 tokenBalance = _token.balanceOf(address(this));
      return exchangePortal.getValue(
        address(_token),
        coreFundAsset,
        tokenBalance
      );
    }
  }

  /**
  * @dev sets new coreFundAsset NOTE: this works only for stable coins
  *
  * @param _coinAddress    New stable address
  */
  function changeStableCoinAddress(address _coinAddress) external onlyOwner {
    require(isStableCoinBasedFund, "NOT_USD_FUND");
    require(totalWeiDeposited == 0, "NOT_EMPTY_DEPOSIT");
    require(permittedAddresses.isMatchTypes(_coinAddress, 4), "WRONG_ADDRESS");

    coreFundAsset = _coinAddress;
  }
}

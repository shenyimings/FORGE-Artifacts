pragma solidity ^0.6.12;

import "./SmartFundETH.sol";

contract SmartFundETHFactory {

  function createSmartFund(
    address _owner,
    string  memory _name,
    uint256 _successFee,
    address _platfromAddress,
    address _exchangePortalAddress,
    address _permittedAddresses,
    bool    _isRequireTradeVerification
  )
  public
  returns(address)
  {
    SmartFundETH smartFundETH = new SmartFundETH(
      _owner,
      _name,
      _successFee,
      _platfromAddress,
      _exchangePortalAddress,
      _permittedAddresses,
      _isRequireTradeVerification
    );

    return address(smartFundETH);
  }
}

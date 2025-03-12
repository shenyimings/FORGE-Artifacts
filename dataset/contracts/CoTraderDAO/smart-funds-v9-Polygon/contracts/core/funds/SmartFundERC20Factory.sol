pragma solidity ^0.6.12;

import "./SmartFundERC20.sol";

contract SmartFundERC20Factory {
  function createSmartFund(
    address _owner,
    string memory _name,
    uint256 _successFee,
    address _platfromAddress,
    address _exchangePortalAddress,
    address _permittedAddresses,
    address _coinAddress,
    bool    _isRequireTradeVerification
  )
  public
  returns(address)
  {
    SmartFundERC20 smartFundERC20 = new SmartFundERC20(
      _owner,
      _name,
      _successFee,
      _platfromAddress,
      _exchangePortalAddress,
      _permittedAddresses,
      _coinAddress,
      _isRequireTradeVerification
    );

    return address(smartFundERC20);
  }
}

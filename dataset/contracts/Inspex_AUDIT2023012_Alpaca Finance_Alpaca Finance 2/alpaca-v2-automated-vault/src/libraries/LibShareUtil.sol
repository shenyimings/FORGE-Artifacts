// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

import { LibFullMath } from "./LibFullMath.sol";

library LibShareUtil {
  function shareToValue(uint256 _shareAmount, uint256 _totalValue, uint256 _totalShare) internal pure returns (uint256) {
    if (_totalShare == 0) return _shareAmount;
    return LibFullMath.mulDiv(_shareAmount, _totalValue, _totalShare);
  }

  function valueToShare(uint256 _tokenAmount, uint256 _totalShare, uint256 _totalValue) internal pure returns (uint256) {
    if (_totalShare == 0) return _tokenAmount;
    return LibFullMath.mulDiv(_tokenAmount, _totalShare, _totalValue);
  }

  function valueToShareRoundingUp(uint256 _tokenAmount, uint256 _totalShare, uint256 _totalValue)
    internal
    pure
    returns (uint256)
  {
    uint256 _shares = valueToShare(_tokenAmount, _totalShare, _totalValue);
    uint256 _shareValues = shareToValue(_shares, _totalValue, _totalShare);
    if (_shareValues + 1 == _tokenAmount) {
      _shares += 1;
    }
    return _shares;
  }

  function shareToValueRoundingUp(uint256 _shareAmount, uint256 _totalValue, uint256 _totalShare)
    internal
    pure
    returns (uint256)
  {
    uint256 _values = shareToValue(_shareAmount, _totalValue, _totalShare);
    uint256 _valueShares = valueToShare(_values, _totalShare, _totalValue);
    if (_valueShares + 1 == _shareAmount) {
      _values += 1;
    }
    return _values;
  }
}

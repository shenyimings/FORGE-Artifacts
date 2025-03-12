pragma solidity 0.4.23;

import "zeppelin-solidity/contracts/crowdsale/validation/CappedCrowdsale.sol";
import "zeppelin-solidity/contracts/ownership/Ownable.sol";

contract UserMinMaxCrowdsale is Crowdsale, Ownable {
  using SafeMath for uint256;

	uint256 public min;
  uint256 public max;

	mapping(address => uint256) public contributions;

	function UserMinMaxCrowdsale(uint256 _min, uint256 _max) public {
		require(_min > 0);
		require(_max > _min);
		// each person should contribute between min-max amount of wei
		min = _min;
		max = _max;
	}

	function getUserContribution(address _beneficiary) public view returns (uint256) {
    return contributions[_beneficiary];
  }

  function _preValidatePurchase(address _beneficiary, uint256 _weiAmount) internal {
    super._preValidatePurchase(_beneficiary, _weiAmount);
    require(contributions[_beneficiary].add(_weiAmount) <= max);
		require(contributions[_beneficiary].add(_weiAmount) >= min);
  }

	function _updatePurchasingState(address _beneficiary, uint256 _weiAmount) internal {
		super._updatePurchasingState(_beneficiary, _weiAmount);
		// update total contribution
		contributions[_beneficiary] = contributions[_beneficiary].add(_weiAmount);
	}
}

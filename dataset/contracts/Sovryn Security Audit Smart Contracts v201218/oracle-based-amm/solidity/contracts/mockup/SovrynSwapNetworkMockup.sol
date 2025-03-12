pragma solidity 0.4.26;

import "../SovrynSwapNetwork.sol";

contract SovrynSwapNetworkMockup is SovrynSwapNetwork {
  uint256 public mockConversionValue;
  IERC20Token wrbtcToken;

  constructor(IContractRegistry _registry, uint256 _mockConversionValue, IERC20Token _wrbtcToken) public SovrynSwapNetwork(_registry) {
    mockConversionValue = _mockConversionValue;
    wrbtcToken = _wrbtcToken;
  }

  function conversionPath(IERC20Token _sourceToken, IERC20Token _targetToken) public view returns (address[]) {
    address[] memory _address;
    return _address;
  }

  function rateByPath(IERC20Token[] _path, uint256 _amount) public view returns (uint256) {
    return mockConversionValue;
  }

  /**
   * @dev used by converter withdraw fee function.
   * This function will act as token/WRBTC converter, and then directly send WRBTC (with total of mockConversionValue) into the caller.
   */
  function convert(
		IERC20Token[] _path,
		uint256 _amount,
		uint256 _minReturn
	) public payable returns (uint256) {
    wrbtcToken.transfer(msg.sender, mockConversionValue);
		return mockConversionValue;
	}

  function setMockConversionValue(uint256 _conversionValue) {
    mockConversionValue = _conversionValue;
  }
}
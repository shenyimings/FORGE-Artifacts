pragma solidity >=0.5.0 <0.6.0;

import "./IERC20Token.sol";
import "./IEtherToken.sol";
import "./ISovrynSwapX.sol";

interface ISovrynSwapNetwork {
	event Conversion(
		address indexed _smartToken,
		address indexed _fromToken,
		address indexed _toToken,
		uint256 _fromAmount,
		uint256 _toAmount,
		address _trader
	);

	function setMaxAffiliateFee(uint256 _maxAffiliateFee) external;

	function registerEtherToken(IEtherToken _token, bool _register) external;

	function conversionPath(IERC20Token _sourceToken, IERC20Token _targetToken) external view returns (address[] memory);

	function rateByPath(IERC20Token[] calldata _path, uint256 _amount) external view returns (uint256);

	function convertByPath(
		IERC20Token[] calldata _path,
		uint256 _amount,
		uint256 _minReturn,
		address _beneficiary,
		address _affiliateAccount,
		uint256 _affiliateFee
	) external payable returns (uint256);

	function xConvert(
		IERC20Token[] calldata _path,
		uint256 _amount,
		uint256 _minReturn,
		bytes32 _targetBlockchain,
		bytes32 _targetAccount,
		uint256 _conversionId
	) external payable returns (uint256);

	function xConvert2(
		IERC20Token[] calldata _path,
		uint256 _amount,
		uint256 _minReturn,
		bytes32 _targetBlockchain,
		bytes32 _targetAccount,
		uint256 _conversionId,
		address _affiliateAccount,
		uint256 _affiliateFee
	) external payable returns (uint256);

	function completeXConversion(
		IERC20Token[] calldata _path,
		ISovrynSwapX _sovrynSwapX,
		uint256 _conversionId,
		uint256 _minReturn,
		address _beneficiary
	) external returns (uint256);

	function getReturnByPath(IERC20Token[] calldata _path, uint256 _amount) external view returns (uint256, uint256);

	function convert(
		IERC20Token[] calldata _path,
		uint256 _amount,
		uint256 _minReturn
	) external payable returns (uint256);

	function convert2(
		IERC20Token[] calldata _path,
		uint256 _amount,
		uint256 _minReturn,
		address _affiliateAccount,
		uint256 _affiliateFee
	) external payable returns (uint256);

	function convertFor(
		IERC20Token[] calldata _path,
		uint256 _amount,
		uint256 _minReturn,
		address _beneficiary
	) external payable returns (uint256);

	function convertFor2(
		IERC20Token[] calldata _path,
		uint256 _amount,
		uint256 _minReturn,
		address _beneficiary,
		address _affiliateAccount,
		uint256 _affiliateFee
	) external payable returns (uint256);

	function claimAndConvert(
		IERC20Token[] calldata _path,
		uint256 _amount,
		uint256 _minReturn
	) external returns (uint256);

	function claimAndConvert2(
		IERC20Token[] calldata _path,
		uint256 _amount,
		uint256 _minReturn,
		address _affiliateAccount,
		uint256 _affiliateFee
	) external returns (uint256);

	function claimAndConvertFor(
		IERC20Token[] calldata _path,
		uint256 _amount,
		uint256 _minReturn,
		address _beneficiary
	) external returns (uint256);

	function claimAndConvertFor2(
		IERC20Token[] calldata _path,
		uint256 _amount,
		uint256 _minReturn,
		address _beneficiary,
		address _affiliateAccount,
		uint256 _affiliateFee
	) external returns (uint256);
}

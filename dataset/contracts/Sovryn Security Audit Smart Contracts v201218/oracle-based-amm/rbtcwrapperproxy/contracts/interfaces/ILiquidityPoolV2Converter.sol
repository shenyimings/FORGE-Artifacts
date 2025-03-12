pragma solidity >=0.5.0 <0.6.0;

import "./IERC20Token.sol";
import "./ISmartToken.sol";
import "./IConsumerPriceOracle.sol";

interface ILiquidityPoolV2Converter {
	event DynamicFeeFactorUpdate(uint256 _prevFactor, uint256 _newFactor);

	function converterType() external pure returns (uint16);

	function isActive() external view returns (bool);

	function amplificationFactor() external pure returns (uint8);

	function activate(
		IERC20Token _primaryReserveToken,
		IConsumerPriceOracle _primaryReserveOracle,
		IConsumerPriceOracle _secondaryReserveOracle
	) external;

	function setDynamicFeeFactor(uint256) external;

	function reserveStakedBalance(IERC20Token _reserveToken) external view returns (uint256);

	function reserveAmplifiedBalance(IERC20Token _reserveToken) external view returns (uint256);

	function setReserveStakedBalance(IERC20Token _reserveToken, uint256 _balance) external;

	function setMaxStakedBalances(uint256 _reserve1MaxStakedBalance, uint256 _reserve2MaxStakedBalance) external;

	function disableMaxStakedBalances() external;

	function poolToken(IERC20Token _reserveToken) external view returns (ISmartToken);

	function liquidationLimit(ISmartToken _poolToken) external view returns (uint256);

	function addReserve(IERC20Token _token, uint32 _weight) external;

	function effectiveTokensRate() external view returns (uint256, uint256);

	function effectiveReserveWeights() external view returns (uint256, uint256);

	function targetAmountAndFee(
		IERC20Token _sourceToken,
		IERC20Token _targetToken,
		uint256 _amount
	) external view returns (uint256, uint256);

	function addLiquidity(
		IERC20Token _reserveToken,
		uint256 _amount,
		uint256 _minReturn
	) external payable returns (uint256);

	function removeLiquidity(
		ISmartToken _poolToken,
		uint256 _amount,
		uint256 _minReturn
	) external returns (uint256);

	function removeLiquidityReturnAndFee(ISmartToken _poolToken, uint256 _amount) external view returns (uint256, uint256);
}

pragma solidity 0.5.16;

import "./IERC20Token.sol";
import "./IConverterAnchor.sol";

/**
  * @dev Liquidity Pool v1 Converter
  *
  * The liquidity pool v1 converter is a specialized version of a converter that manages
  * a classic SovrynSwap liquidity pool.
  *
  * Even though classic pools can have many reserves, the most common configuration of
  * the pool has 2 reserves with 50%/50% weights.
*/
interface ILiquidityPoolV1Converter {
    /**
      * @dev triggered after a conversion with new price data
      * deprecated, use `TokenRateUpdate` from version 28 and up
      *
      * @param  _connectorToken     reserve token
      * @param  _tokenSupply        smart token supply
      * @param  _connectorBalance   reserve balance
      * @param  _connectorWeight    reserve weight
    */
    event PriceDataUpdate(
        address indexed _connectorToken,
        uint256 _tokenSupply,
        uint256 _connectorBalance,
        uint32 _connectorWeight
    );

    /**
      * @dev returns the converter type
      *
      * @return see the converter types in the the main contract doc
    */
    function converterType() external pure returns (uint16);

    /**
      * @dev accepts ownership of the anchor after an ownership transfer
      * also activates the converter
      * can only be called by the contract owner
      * note that prior to version 28, you should use 'acceptTokenOwnership' instead
    */
    function acceptAnchorOwnership() external;

    /**
      * @dev returns the expected target amount of converting one reserve to another along with the fee
      *
      * @param _sourceToken contract address of the source reserve token
      * @param _targetToken contract address of the target reserve token
      * @param _amount      amount of tokens received from the user
      *
      * @return expected target amount
      * @return expected fee
    */
    function targetAmountAndFee(IERC20Token _sourceToken, IERC20Token _targetToken, uint256 _amount) external view returns (uint256, uint256);


    /**
      * @dev increases the pool's liquidity and mints new shares in the pool to the caller
      * note that prior to version 28, you should use 'fund' instead
      *
      * @param _reserveTokens   address of each reserve token
      * @param _reserveAmounts  amount of each reserve token
      * @param _minReturn       token minimum return-amount
    */
    function addLiquidity(IERC20Token[] calldata _reserveTokens, uint256[] calldata _reserveAmounts, uint256 _minReturn) external payable;

    /**
      * @dev decreases the pool's liquidity and burns the caller's shares in the pool
      * note that prior to version 28, you should use 'liquidate' instead
      *
      * @param _amount                  token amount
      * @param _reserveTokens           address of each reserve token
      * @param _reserveMinReturnAmounts minimum return-amount of each reserve token
    */
    function removeLiquidity(uint256 _amount, IERC20Token[] calldata _reserveTokens, uint256[] calldata _reserveMinReturnAmounts) external;

    /**
      * @dev increases the pool's liquidity and mints new shares in the pool to the caller
      * for example, if the caller increases the supply by 10%,
      * then it will cost an amount equal to 10% of each reserve token balance
      * note that starting from version 28, you should use 'addLiquidity' instead
      *
      * @param _amount  amount to increase the supply by (in the pool token)
    */
    function fund(uint256 _amount) external payable;

    /**
      * @dev decreases the pool's liquidity and burns the caller's shares in the pool
      * for example, if the holder sells 10% of the supply,
      * then they will receive 10% of each reserve token balance in return
      * note that starting from version 28, you should use 'removeLiquidity' instead
      *
      * @param _amount  amount to liquidate (in the pool token)
    */
    function liquidate(uint256 _amount) external;

    /**
      * @dev calculates the number of decimal digits in a given value
      *
      * @param _x   value (assumed positive)
      * @return the number of decimal digits in the given value
    */
    function decimalLength(uint256 _x) external pure returns (uint256);

    /**
      * @dev calculates the nearest integer to a given quotient
      *
      * @param _n   quotient numerator
      * @param _d   quotient denominator
      * @return the nearest integer to the given quotient
    */
    function roundDiv(uint256 _n, uint256 _d) external pure returns (uint256);

    /**
      * @dev calculates the average number of decimal digits in a given list of values
      *
      * @param _values  list of values (each of which assumed positive)
      * @return the average number of decimal digits in the given list of values
    */
    function geometricMean(uint256[] calldata _values) external pure returns (uint256);

    /**
      * @dev deprecated since version 28, backward compatibility - use only for earlier versions
    */
    function token() external view returns (IConverterAnchor);

    function reserveRatio() external view returns (uint32);

    struct Reserve {
      uint256 balance;    // reserve balance
      uint32 weight;      // reserve weight, represented in ppm, 1-1000000
      bool deprecated1;   // deprecated
      bool deprecated2;   // deprecated
      bool isSet;         // true if the reserve is valid, false otherwise
    }
    function reserves(address) external view returns (uint256, uint32, bool, bool, bool);  
}

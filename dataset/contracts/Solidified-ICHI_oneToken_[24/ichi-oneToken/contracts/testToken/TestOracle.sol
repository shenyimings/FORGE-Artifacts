// SPDX-License-Identifier: Unlicensed

pragma solidity 0.7.6;

import "../oracle/OracleCommon.sol";
import "../interface/IERC20Extended.sol";

/**
 * @notice Separate ownable instances can be managed by separate governing authorities.
 * Immutable windowSize and granularity changes require a new oracle contract. 
 */

contract TestOracle is OracleCommon {

    event Deployed(address sender);
    event Initialized(address sender, address baseToken, address indexToken);
    event Updated(address sender);
    
    /**
    @dev should the oracle get off center up or down
     */
    bool private adjustUp;

    constructor(address oneTokenFactory_, string memory description_, address indexToken_) 
        OracleCommon(oneTokenFactory_, description_, indexToken_) 
    {
        adjustUp = false;
        emit Deployed(msg.sender);
    }

    /**
     @notice update is adjust up/down flag
     */
    function setAdjustUp(bool _adjustUp) external {
        adjustUp = _adjustUp;
    }

    /**
     @notice intialization is called when a oneToken appoints an Oracle
     @dev there is nothing to do in this case
     */
    function init(address /* baseToken */) external override {}

    /**
     @notice update is called when a oneToken wants to persist observations
     @dev there is nothing to do in this case
     */
    function update(address /* token */) external override {
        emit Updated(msg.sender);
    }

    /**
     @notice returns equivalent amount of index tokens for an amount of baseTokens and volatility metric
     @dev token:usdToken is always 1:1 and valatility is always 0
     */
    function read(address /* token */, uint256 amount) public view override returns(uint256 amountOut, uint256 volatility) {
        /// @notice it is always 1:1 with no volatility
        this; // silence mutability warning
        if (adjustUp) {
            amountOut = amount + 2 * 10 ** 16;
        } else {
            amountOut = amount - 2 * 10 ** 16;
        }
        volatility = 1;
    }

    /**
     @notice returns the tokens needed to reach a target usd value
     @dev token:usdToken is always 1:1 and valatility is always 0
     */
    function amountRequired(address /* token */, uint256 amountUsd) external view override returns(uint256 tokens, uint256 volatility) {
        /// @notice it is always 1:1 with no volatility
        this; // silence visbility warning
        tokens = amountUsd;
        volatility = 1;      
    }
}

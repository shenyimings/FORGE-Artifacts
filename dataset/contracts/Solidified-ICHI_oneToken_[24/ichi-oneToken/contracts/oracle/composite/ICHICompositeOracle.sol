// SPDX-License-Identifier: Unlicensed

pragma solidity 0.7.6;

import "../OracleCommon.sol";
import "../../interface/IERC20Extended.sol";
import "../../_openzeppelin/math/SafeMath.sol";

/**
 @notice Relies on external Oracles using any price quote methodology.
 */

contract ICHICompositeOracle is OracleCommon {

    using SafeMath for uint256;
    
    address[] public oracleContracts;
    address[] public interimTokens;

    /**
     @notice addresses and oracles define a chain of currency conversions (e.g. X:ETH, ETH:BTC: BTC:USDC => X:USDC) that will be executed in order of declaration
     @dev output of oracles is used as input for the next oracle. 
     @param description_ human-readable name has no bearing on internal logic
     @param indexToken_ a registered usdToken to use for quote indexed
     @param interimTokens_ a sequential list of base tokens to query the oracles, starting with the base token for the composite oracle, e.g. X
     @param oracles_ a sequential list of unregisted contracts that support the IOracle interface, ending with a collateral token, e.g. USDC
     */
    constructor(address oneTokenFactory_, string memory description_, address indexToken_, address[] memory interimTokens_, address[] memory oracles_)
        OracleCommon(oneTokenFactory_, description_, indexToken_)
    {
        require(interimTokens_.length == oracles_.length, 'ICHICompositeOracle: unequal interimTokens and Oracles list lengths');
        oracleContracts = oracles_;
        interimTokens = interimTokens_;
        indexToken = indexToken_;
    }

    /**
     @notice intialization is called when the factory assigns an oracle to an asset
     @dev there is nothing to do. Deploy separate instances configured for distinct baseTokens
     */
    function init(address baseToken) external onlyModuleOrFactory override {
        for(uint256 i=0; i<oracleContracts.length; i++) {
            IOracle(oracleContracts[i]).init(interimTokens[i]);
        }
        emit OracleInitialized(msg.sender, baseToken, indexToken);
    }

    /**
     @notice update is called when a oneToken wants to persist observations
     @dev chain length is constrained by gas
     //param token composite oracles are always single-tenant, The token context is ignored.
     */
    function update(address /* token */) external override {
        for(uint256 i=0; i<oracleContracts.length; i++) {
            IOracle(oracleContracts[i]).update(interimTokens[i]);
        }
    }

    /**
     @notice returns equivalent amount of index tokens for an amount of baseTokens and volatility metric
     @dev volatility is the product of interim volatility measurements
     //param token composite oracles are always single-tenant, The token context is ignored.
     @param amountTokens quantity of tokens, token precision
     @param amountUsd index tokens required, precision 18
     @param volatility overall volatility metric - for future use-caeses
     */
    function read(address /* token */ , uint256 amountTokens) public view override returns(uint256 amountUsd, uint256 volatility) {
        uint256 compoundedVolatility;
        uint256 amount = tokensToNormalized(interimTokens[0], amountTokens);
        volatility = 1;
        for(uint256 i=0; i<oracleContracts.length; i++) {
            ( amount, compoundedVolatility ) = IOracle(oracleContracts[i]).read(interimTokens[i], normalizedToTokens(interimTokens[i], amount));
            volatility = volatility.mul(compoundedVolatility);
        }
        amountUsd = amount;
    }

    /**
     @notice returns the tokens needed to reach a target usd value
     //param token composite oracles are always single-tenant, The token context is ignored.     
     @param amountUsd Usd required in 10**18 precision
     @param amountTokens tokens required in tokens native precision
     @param volatility metric for future use-cases
     */
    function amountRequired(address /* token */, uint256 amountUsd) external view override returns(uint256 amountTokens, uint256 volatility) {
        uint256 tokenToUsd;
        (tokenToUsd, volatility) = read(NULL_ADDRESS, normalizedToTokens(indexToken, PRECISION)); 
        amountTokens = PRECISION.mul(amountUsd).div(tokenToUsd);
        amountTokens = normalizedToTokens(indexToken, amountTokens);
        volatility = 1;
    }

    /**
     * extended functionality 
     */

    /**
     @param count number of interim oracles
     */
    function oracleCount() external view returns(uint256 count) {
        return oracleContracts.length;
    }

    /**
     @param index oracle contract to retrieve
     @param oracle interim token oracle address
     @param token interim token address     
     */

    function oracleAtIndex(uint256 index) external view returns(address oracle, address token) {
        return(oracleContracts[index], interimTokens[index]);
    }

}

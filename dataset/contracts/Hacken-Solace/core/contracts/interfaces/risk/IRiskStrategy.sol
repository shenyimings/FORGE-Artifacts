// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

/**
 * @title IRiskStrategy
 * @author solace.fi
 * @notice The interface of `RiskStragety` smart contract that is created by [`RiskStrategyFactor`](./RiskStrategyFactory).
 * The `RiskStrategy` defines the product risk params for coverage products.
 *
*/
interface IRiskStrategy {

    /***************************************
      TYPE DEFINITIONS
    ***************************************/
   
    /// @notice Struct for a product's risk parameters.
    struct ProductRiskParams {
      uint32 weight;  // The weighted allocation of this product vs other products.
      uint24 price;   // The price in wei per 1e12 wei of coverage per block.
      uint16 divisor; // The max cover per policy divisor. (maxCoverPerProduct / divisor = maxCoverPerPolicy)
    }
    
    /***************************************
      EVENTS
    ***************************************/
    
    /// @notice Emitted when a product's risk parameters are set at initialization.
    event ProductRiskParamsSet(address product, uint32 weight, uint24 price, uint16 divisor);

    /// @notice Emitted when governance adds a product.
    event ProductAddedByGovernance(address product, uint32 weight, uint24 price, uint16 divisor);
    
    /// @notice Emitted when governance updates a product.
    event ProductUpdatedByGovernance(address product, uint32 weight, uint24 price, uint16 divisor);

    /// @notice Emitted when governance removes a product.
    event ProductRemovedByGovernance(address product);

    /// @notice Emitted when governance sets product risk params.
    event ProductRiskParamsSetByGovernance(address product, uint32 weight, uint24 price, uint16 divisor);

    /// @notice Emitted when RiskManager is set.
    event RiskManagerSet(address riskManager);


    /***************************************
      RISK STRATEGY VIEW FUNCTIONS
    ***************************************/

    /**
     * @notice Given a request for coverage, determines if that risk is acceptable and if so at what price.
     * @param product_ The product that wants to sell coverage.
     * @param currentCover_ If updating an existing policy's cover amount, the current cover amount, otherwise 0.
     * @param newCover_ The cover amount requested.
     * @return acceptable True if risk of the new cover is acceptable, false otherwise.
     * @return price The price in wei per 1e12 wei of coverage per block.
    */
    function assessRisk(address product_, uint256 currentCover_, uint256 newCover_) external view returns (bool acceptable, uint24 price);

    /**
     * @notice The maximum amount of cover that `Risk Strategy` as a whole can sell.
     * @return cover The max amount of cover in `wei`
    */
    function maxCover() external view returns (uint256 cover);
    
    /**
     * @notice The maximum amount of cover in `Risk Strategy` that a product can sell in total.
     * @param product_ The product that wants to sell cover.
     * @return cover The max amount of cover in `wei`
    */
    function  maxCoverPerProduct(address product_) external view returns (uint256 cover);
    
    /**
     * @notice The amount of cover in `Risk Strategy` that a product can still sell.
     * @param product_ The product that wants to sell cover.
     * @return cover The max amount of cover in `wei`.  
    */
    function sellableCoverPerProduct(address product_) external view returns (uint256 cover);
    
    /**
     * @notice The maximum amount of cover in `Risk Strategy` that a product can sell in a single policy.
     * @param product_ The product that wants to sell cover.
     * @return cover The max amount of cover in `wei`.
    */
    function maxCoverPerPolicy(address product_) external view returns (uint256 cover);
    
    /**
     * @notice Checks if product is an active product in `Risk Strategy`.
     * @param product_ The product to check.
     * @return status True if the product is active.
    */
    function productIsActive(address product_) external view returns (bool status);
    
    /**
     * @notice Returns the number of registered products in `Risk Strategy`.
     * @return count The number of products.
    */
    function numProducts() external view returns (uint256 count);
    
    /**
     * @notice Returns the product at an index in `Risk Strategy`.
     * @dev Enumerable `[1, numProducts]`.
     * @param index_ The index to query.
     * @return prod The product address.
    */
    function product(uint256 index_) external view returns (address prod);
    
    /**
     * @notice Returns given product's risk paramaters. The product must be active.
     * @param product_ The product to get parameters for.
     * @return weight The weighted allocation of this product.
     * @return price The price in `wei` per `1e12 wei` of coverage per block.
     * @return divisor The max cover per policy divisor.
    */
    function productRiskParams(address product_) external view returns (uint32 weight, uint24 price, uint16 divisor);
    
    /**
     * @notice Returns the sum of weights in `Risk Strategy`.
     * @return sum The weight sum.
    */
    function weightSum() external view returns (uint32 sum);

   /**
     * @notice Returns risk allocation weight in `Risk Strategy`.
     * @return weightAllocation_ The weight allocation.
    */
    function weightAllocation() external view returns (uint32 weightAllocation_);
      
    /**
     * @notice Returns the strategist address.
     * @return strategist_ The address of the risk strategy owner.
    */
    function strategist() external view returns (address strategist_);

    /**
     * @notice Returns the risk manager address.
     * @return riskManager_ The address of the risk strategy owner.
    */
    function riskManager() external view returns (address riskManager_);

    /**
     * @notice Returns the status of the risk strategy.
     * @return status True if strategy is active.
    */
    function status() external view returns (bool status);

    /***************************************
    RISK STRATEGY GOVERNANCE FUNCTIONS
    ***************************************/

    /**
     * @notice Adds a product.
     * If the product is already added, sets its parameters.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param product_ Address of the product.
     * @param weight_ The products weight.
     * @param price_ The products price in wei per 1e12 wei of coverage per block.
     * @param divisor_ The max cover per policy divisor.
    */
    function addProduct(address product_, uint32 weight_, uint24 price_, uint16 divisor_) external;

    /**
     * @notice Removes a product.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param product_ Address of the product to remove.
    */
    function removeProduct(address product_) external;
 
    /**
     * @notice Sets the products and their parameters.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param products_ The products.
     * @param weights_ The product weights.
     * @param prices_ The product prices.
     * @param divisors_ The max cover per policy divisors.
    */
    function setProductParams(address[] calldata products_, uint32[] calldata weights_, uint24[] calldata prices_, uint16[] calldata divisors_) external;

    /**
     * @notice Changes the risk manager.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param riskManager_ The new risk manager.
    */
    function setRiskManager(address riskManager_) external;
}
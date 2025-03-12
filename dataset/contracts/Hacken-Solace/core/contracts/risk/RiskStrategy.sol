// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

import "../utils//GovernableInitializable.sol";
import "../interfaces/products/IProduct.sol";
import "../interfaces/risk/IRiskManager.sol";
import "../interfaces/risk/IRiskStrategy.sol";

/**
 * @title RiskStrategy
 * @author solace.fi
 * @notice The `RiskStragety` smart contract that is created by [`RiskStrategyFactor`](./RiskStrategyFactory).
 * The `RiskStrategy` defines the product risk params for coverage products.
 *
*/
contract RiskStrategy is IRiskStrategy, GovernableInitializable {

    /// @notice mapping product => index
    mapping(address => uint256) internal _productToIndex;
   
    /// @notice mapping index => product
    mapping(uint256 => address) internal _indexToProduct;

    /// @notice mapping for the product risk params per product
    mapping(address => ProductRiskParams) internal _productRiskParams;

    /// @notice the number of products in strategy
    uint256 internal _productCount = 0;

    /// @notice Solace `Risk Manager`
    IRiskManager internal _riskManager;

    /// @notice the address of the strategist.(a.k.a strategy owner)
    address internal _strategist = address(0);

    /// @notice sum of the product weights in strategy
    uint32 internal _weightSum = 0;

    /// @notice controls the access that for only risk manager can access.
    modifier onlyRiskManager() {
      require(msg.sender == address(_riskManager), "not risk manager");
      _;
    }
    
    /**
     * @notice Constructs the `RiskStrategy` contract.
     * @param governance_ The address of the [governor](/docs/protocol/governance).
     * @param riskManager_ The address of the Solace `RiskManager` contract.
     * @param products_ The strategy products.
     * @param weights_  The weights of the strategy products.
     * @param prices_   The prices of the strategy products.
     * @param divisors_ The divisors(max cover per policy divisor) of the strategy products. 
    */
    function initialize(
        address governance_,
        address riskManager_,
        address strategist_,
        address[] memory products_,
        uint32[] memory weights_,
        uint24[] memory prices_,
        uint16[] memory divisors_
    ) public initializer {
        __Governable_init(governance_);
        require(riskManager_ != address(0x0), "zero address risk manager");
        require(strategist_  != address(0x0), "zero address strategist");
        _riskManager = IRiskManager(riskManager_);
        _strategist = strategist_;
        _weightSum = type(uint32).max;

        // set strategy product risk params
        _initializeStrategyRiskParams(products_, weights_, prices_, divisors_); 
    }

    /***************************************
      RISK STRATEGY VIEW FUNCTIONS
    ***************************************/

    /**
    * @notice Given a request for coverage, determines if that risk is acceptable and if so at what price.
    * @dev The strategy should be active. The status check is important because, we don't force any status check
    * in the products. So, we don't allow any product to call assessRisk function if the strategy is not active
    * and also product is not in the strategy.  
    * @param prod_ The product that wants to sell coverage.
    * @param currentCover_ If updating an existing policy's cover amount, the current cover amount, otherwise 0.
    * @param newCover_ The cover amount requested.
    * @return acceptable True if risk of the new cover is acceptable, false otherwise.
    * @return price The price in wei per 1e12 wei of coverage per block.
    */
    function assessRisk(address prod_, uint256 currentCover_, uint256 newCover_) external view override returns (bool acceptable, uint24 price) {
        require(status(), "strategy inactive");
        require(_productToIndex[prod_] > 0, "invalid product");

        // max cover checks
        uint256 mc = maxCover();
        ProductRiskParams storage params = _productRiskParams[prod_];

        // must be less than maxCoverPerProduct
        mc = mc * params.weight / _weightSum;
        uint256 productActiveCoverLimit = IProduct(payable(prod_)).activeCoverLimitPerStrategy(address(this));
        productActiveCoverLimit = productActiveCoverLimit + newCover_ - currentCover_;
    
        if (productActiveCoverLimit > mc) return (false, params.price);
        // must be less than maxCoverPerPolicy
        mc = mc / params.divisor;

        if(newCover_ > mc) return (false, params.price);
        // risk is acceptable
        return (true, params.price);
    }
    
    /**
     * @notice The maximum amount of cover that `Risk Strategy` as a whole can sell.
     * @return cover The max amount of cover in `wei`
    */
    function maxCover() public view override returns (uint256 cover) {
        return _riskManager.maxCoverPerStrategy(address(this));
    }

    /**
     * @notice The maximum amount of cover in `Risk Strategy` that a product can sell in total.
     * @param prod_ The product that wants to sell cover.
     * @return cover The max amount of cover in `wei`
    */
    function  maxCoverPerProduct(address prod_) public view override returns (uint256 cover) {
        return maxCover() * _productRiskParams[prod_].weight / _weightSum;
    }

    /**
     * @notice The amount of cover in `Risk Strategy` that a product can still sell.
     * @param prod_ The product that wants to sell cover.
     * @return cover The max amount of cover in `wei`.  
    */
    function sellableCoverPerProduct(address prod_) public view override returns (uint256 cover) {
        // max cover per product
        uint256 mc = maxCoverPerProduct(prod_);
        // active cover for product
        uint256 ac = IProduct(payable(prod_)).activeCoverLimitPerStrategy(address(this));
        return (mc < ac) ? 0 : (mc - ac);
    }

    /**
     * @notice The maximum amount of cover in `Risk Strategy` that a product can sell in a single policy.
     * @param prod_ The product that wants to sell cover.
     * @return cover The max amount of cover in `wei`.
    */
    function maxCoverPerPolicy(address prod_) external view override returns (uint256 cover) {
        ProductRiskParams storage params = _productRiskParams[prod_];
        require(params.weight > 0, "product inactive");
        return maxCover() * params.weight / (_weightSum * params.divisor);
    }

    /**
     * @notice Checks if product is an active product in `Risk Strategy`.
     * @param prod_ The product to check.
     * @return status_ True if the product is active.
    */
    function productIsActive(address prod_) public view override returns (bool status_) {
        return _productToIndex[prod_] != 0;
    }

    /**
     * @notice Returns the number of registered products in `Risk Strategy`.
     * @return count The number of products.
    */
    function numProducts() external view override returns (uint256 count) {
        return _productCount;
    }

    /**
     * @notice Returns the product at an index in `Risk Strategy`.
     * @dev Enumerable `[1, numProducts]`.
     * @param index_ The index to query.
     * @return prod The product address.
    */
    function product(uint256 index_) external view override returns (address prod) {
      return _indexToProduct[index_];
    }

    /**
     * @notice Returns given product's risk paramaters. The product must be active.
     * @param prod_ The product to get parameters for.
     * @return weight The weighted allocation of this product.
     * @return price The price in `wei` per `1e12 wei` of coverage per block.
     * @return divisor The max cover per policy divisor.
    */
    function productRiskParams(address prod_) external view override returns (uint32 weight, uint24 price, uint16 divisor) {
        ProductRiskParams storage params = _productRiskParams[prod_];
        require(params.weight > 0,  "product inactive");
        return (params.weight, params.price, params.divisor);
    }

    /**
     * @notice Returns the sum of weights in `Risk Strategy`.
     * @return sum The weight sum.
    */
    function weightSum() external view override returns (uint32 sum) {
        return _weightSum;
    }

    /**
     * @notice Returns risk allocation weight in `Risk Strategy`.
     * @return weightAllocation_ The weight allocation.
    */
    function weightAllocation() external view override returns (uint32 weightAllocation_) {
        return _riskManager.weightPerStrategy(address(this));
    }

    /**
     * @notice Returns the strategist address.
     * @return strategist_ The address of the risk strategy owner.
    */
    function strategist() external view override returns (address strategist_) {
        return _strategist;
    }

    /**
     * @notice Returns the status of the risk strategy.
     * @return status_ True if strategy is active.
    */
    function status() public view override returns (bool status_) {
        return _riskManager.strategyIsActive(address(this));
    }

    /**
     * @notice Returns the risk manager address.
     * @return riskManager_ The address of the risk strategy owner.
    */
    function riskManager() external view override returns (address riskManager_) {
        return address(_riskManager);
    }

    /***************************************
    GOVERNANCE FUNCTIONS
    ***************************************/

    /**
     * @notice Adds a product.
     * If the product is already added, sets its parameters.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @dev Governance can add or update product in the strategy in case of any necessary situations.
     * @param prod_ Address of the product.
     * @param weight_ The product weight.
     * @param price_ The product price in wei per 1e12 wei of coverage per block.
     * @param divisor_ The max cover amount divisor for per policy. (maxCover / divisor = maxCoverPerPolicy).
     */
    function addProduct(address prod_, uint32 weight_, uint24 price_, uint16 divisor_) external override onlyGovernance {
        require(prod_ != address(0x0), "invalid product risk param");
        require(weight_ > 0, "invalid weight risk param");
        require(price_ > 0, "invalid price risk param");
        require(divisor_ > 0, "invalid divisor risk param");

        uint256 index = _productToIndex[prod_];
        uint32 weightSum_ = _weightSum;
        if (index == 0) {
            // add new product
            weightSum_ = (_productCount == 0) ? weight_ : (weightSum_ + weight_);
            _productRiskParams[prod_] = ProductRiskParams({
                weight: weight_,
                price: price_,
                divisor: divisor_
            });
            index = _productCount;
            _productToIndex[prod_] = index + 1;
            _indexToProduct[index + 1] = prod_;
            _productCount++;
            emit ProductAddedByGovernance(prod_, weight_, price_, divisor_);
        } else {
            // change params of existing product
            uint32 prevWeight = _productRiskParams[prod_].weight;
            weightSum_ = weightSum_ - prevWeight + weight_;
            _productRiskParams[prod_] = ProductRiskParams({
                weight: weight_,
                price: price_,
                divisor: divisor_
            });
            emit ProductUpdatedByGovernance(prod_, weight_, price_, divisor_);
        }
        _weightSum = weightSum_;
    }

    /**
     * @notice Removes a product.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @dev Governance can remove a product in the strategy in case of any necessary situations.
     * @param prod_ Address of the product to remove.
     */
    function removeProduct(address prod_) external override onlyGovernance {
        uint256 index = _productToIndex[prod_];
        uint256 productCount = _productCount;

        if (productCount == 0) return;
        // product wasn't added to begin with
        if (index == 0) return;
        // if not at the end copy down
        uint256 lastIndex = productCount;
        if (index != lastIndex) {
            address lastProduct = _indexToProduct[lastIndex];
            _productToIndex[lastProduct] = index;
            _indexToProduct[index] = lastProduct;
        }
        // pop end of array
        delete _productToIndex[prod_];
        delete _indexToProduct[lastIndex];
        uint256 newProductCount = productCount - 1;
        _weightSum = (newProductCount == 0) ? type(uint32).max : (_weightSum - _productRiskParams[prod_].weight);
        _productCount = newProductCount;
        delete _productRiskParams[prod_];
        emit ProductRemovedByGovernance(prod_);
    }

    /**
     * @notice Sets the products and their parameters. The existing products will be removed first. 
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @dev Governance can set a product(s) for the strategy in case of any necessary situations.
     * @param products_ The products.
     * @param weights_ The product weights.
     * @param prices_ The product prices.
     * @param divisors_ The max cover per policy divisors.
     */
    function setProductParams(address[] calldata products_, uint32[] calldata weights_, uint24[] calldata prices_, uint16[] calldata divisors_) external override onlyGovernance {
        // check array lengths
        uint256 length = products_.length;
        require(length == weights_.length && length == prices_.length && length == divisors_.length, "length mismatch");
        // delete old products
        for (uint256 index = _productCount; index > 0; index--) {
            address prod_ = _indexToProduct[index];
            delete _productToIndex[prod_];
            delete _indexToProduct[index];
            delete _productRiskParams[prod_];
            emit ProductRiskParamsSetByGovernance(prod_, 0, 0, 0);
        }
        // add new products
        uint32 weightSum_ = 0;
        for (uint256 i = 0; i < length; i++) {
            address prod_ = products_[i];
            uint32 weight_ = weights_[i];
            uint24 price_ = prices_[i];
            uint16 divisor_ = divisors_[i];

            require(prod_ != address(0x0), "invalid product risk param");
            require(weight_ > 0, "invalid weight risk param");
            require(price_ > 0, "invalid price risk param");
            require(divisor_ > 0, "invalid divisor risk param");
            require(_productToIndex[prod_] == 0, "duplicate product");

            _productRiskParams[prod_] = ProductRiskParams({
                weight: weight_,
                price: price_,
                divisor: divisor_
            });
            weightSum_ += weight_;
            _productToIndex[prod_] = i + 1;
            _indexToProduct[i + 1] = prod_;
            emit ProductRiskParamsSetByGovernance(prod_, weight_, price_, divisor_);
        }
        _weightSum = (length == 0) ? type(uint32).max : weightSum_;
        _productCount = length;
    }

    /**
     * @notice Changes the risk manager.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param riskManager_ The new risk manager.
    */
    function setRiskManager(address riskManager_) external override onlyGovernance {
        require(riskManager_ != address(0x0), "zero address risk manager");
        _riskManager = IRiskManager(riskManager_);
        emit RiskManagerSet(riskManager_);
    }

    /***************************************
      RISK STRATEGY PRIVATE FUNCTIONS
    ***************************************/

    function _initializeStrategyRiskParams(address[] memory products_, uint32[] memory weights_, uint24[] memory prices_, uint16[] memory divisors_ ) private {
        uint256 length = products_.length;
        require(length > 0 && (length == weights_.length && length == prices_.length && length == divisors_.length), "risk param length mismatch");
        uint32 weightsum = 0;
        for (uint256 i = 0; i < length; i++) {
            require(products_[i] != address(0x0), "invalid product risk param");
            require(weights_[i]  > 0, "invalid weight risk param");
            require(prices_[i]   > 0, "invalid price risk param");
            require(divisors_[i] > 0, "invalid divisor risk param");

            _productRiskParams[products_[i]] = ProductRiskParams({
              weight: weights_[i],
              price: prices_[i],
              divisor: divisors_[i]
            });

            _productToIndex[products_[i]] = i + 1;
            _indexToProduct[i + 1] = products_[i];
            weightsum += weights_[i];

            emit ProductRiskParamsSet(products_[i], weights_[i], prices_[i], divisors_[i]);            
        }
        _weightSum = weightsum;
        _productCount = length;
    }
}
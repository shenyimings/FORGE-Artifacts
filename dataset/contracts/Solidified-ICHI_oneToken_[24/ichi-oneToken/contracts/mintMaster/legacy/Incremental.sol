// SPDX-License-Identifier: Unlicensed

pragma solidity 0.7.6;

import "../MintMasterCommon.sol";
import "../../interface/IOneTokenV1.sol";
import "../../interface/IOracle.sol";

/**
 * @notice Multi-tenant implementation with parameters managed by separate governing authorities.
 */

contract Incremental is MintMasterCommon {
    
    uint256 constant DEFAULT_RATIO = 10 ** 18; // 100%
    uint256 constant DEFAULT_STEP_SIZE = 0;
    uint256 constant DEFAULT_MAX_ORDER_VOLUME = INFINITE;

    struct Parameters {
        bool set;
        uint256 minRatio;
        uint256 maxRatio;
        uint256 stepSize;
        uint256 lastRatio;  
        uint256 maxOrderVolume;    
    }

    uint256 lastUpdatedBlock;

    mapping(address => Parameters) public parameters;

    event OneTokenOracleChanged(address sender, address oneToken, address oracle);
    event SetParams(address sender, address oneToken, uint256 minRatio, uint256 maxRatio, uint256 stepSize, uint256 initialRatio, uint256 maxOrderVolume);
    event UpdateMintingRatio(address sender, address oneToken, uint256 newRatio, uint256 maxOrderVolume);
    event StepSizeSet(address sender, address oneToken, uint256 stepSize);
    event MinRatioSet(address sender, address oneToken, uint256 minRatio);
    event MaxRatioSet(address sender, address oneToken, uint256 maxRatio);
    event RatioSet(address sender, address oneToken, uint256 ratio);
   
    constructor(address oneTokenFactory_, string memory description_) 
        MintMasterCommon(oneTokenFactory_, description_) {}

    /**
     @notice initializes the common interface with parameters managed by msg.sender, usually a oneToken.
     @dev A single instance can be shared by n oneToken implementations. Initialize from each instance. Re-initialization is acceptabe.
     @param oneTokenOracle gets the exchange rate of the oneToken
     */
    function init(address oneTokenOracle) external onlyKnownToken override {
        _setParams(msg.sender, DEFAULT_RATIO, DEFAULT_RATIO, DEFAULT_STEP_SIZE, DEFAULT_RATIO, DEFAULT_MAX_ORDER_VOLUME);
        _initMintMaster(msg.sender, oneTokenOracle);
        lastUpdatedBlock = block.number;
        emit MintMasterInitialized(msg.sender, msg.sender, oneTokenOracle);
    }

    /**
     @notice changes the oracle used to assess the oneTokens' value in relation to the peg
     @dev may use the peggedOracle (efficient but not informative) or an active oracle 
     @param oneToken oneToken vault (also ERC20 token)
     @param oracle oracle contract must be registered in the factory
     */
    function changeOracle(address oneToken, address oracle) external onlyTokenOwner(oneToken) {
        require(IOneTokenFactory(oneTokenFactory).isOracle(oneToken, oracle), "Incremental: oracle is not approved for oneToken");
        _initMintMaster(oneToken, oracle);      
        emit OneTokenOracleChanged(msg.sender, oneToken, oracle);
    }

    /**
     @notice updates parameters for a given oneToken that uses this module
     @dev inspects the oneToken implementation to establish authority
     @param oneToken token context for parameters
     @param minRatio minimum minting ratio that will be set
     @param maxRatio maximum minting ratio that will be set
     @param stepSize adjustment size iteration
     @param initialRatio unadjusted starting minting ratio
     */
    function setParams(
        address oneToken, 
        uint256 minRatio, 
        uint256 maxRatio, 
        uint256 stepSize, 
        uint256 initialRatio,
        uint256 maxOrderVolume
    ) 
        external
        onlyTokenOwner(oneToken)
    {
        _setParams(oneToken, minRatio, maxRatio, stepSize, initialRatio, maxOrderVolume);
    }

    function _setParams(
        address oneToken, 
        uint256 minRatio, 
        uint256 maxRatio, 
        uint256 stepSize, 
        uint256 initialRatio,
        uint256 maxOrderVolume
    ) 
        private
    {
        Parameters storage p = parameters[oneToken];
        require(minRatio <= maxRatio, "Incremental: minRatio must be <= maxRatio");
        require(maxRatio <= PRECISION, "Incremental: maxRatio must be <= 10 ** 18");
        // Can be zero to prevent movement
        // require(stepSize > 0, "Incremental: stepSize must be > 0");
        require(stepSize < maxRatio - minRatio || stepSize == 0, "Incremental: stepSize must be < (max - min) or zero.");
        require(initialRatio >= minRatio, "Incremental: initial ratio must be >= min ratio.");
        require(initialRatio <= maxRatio, "Incremental: initial ratio must be <= max ratio.");
        p.minRatio = minRatio;
        p.maxRatio = maxRatio;
        p.stepSize = stepSize;
        p.lastRatio = initialRatio;
        p.maxOrderVolume = maxOrderVolume;
        p.set = true;
        emit SetParams(msg.sender, oneToken, minRatio, maxRatio, stepSize, initialRatio, maxOrderVolume);
    }
 
    /**
     @notice returns an adjusted minting ratio
     @dev oneToken contracts call this to get their own minting ratio
     // collateralToken argument in the interface supports future-use cases
     @param ratio the minting ratio
     @param maxOrderVolume recommended maximum order size, specified by governance. Defaults to unlimited
     */
    function getMintingRatio(address /* collateralToken */) external view override returns(uint256 ratio, uint256 maxOrderVolume) {
        return getMintingRatio2(msg.sender, NULL_ADDRESS);
    }

    /**
     @notice returns an adjusted minting ratio. OneTokens use this function and it relies on initialization to select the oracle
     @dev anyone calls this to inspect any oneToken minting ratio based on the oracle chosen at initialization
     @param oneToken oneToken implementation to inspect
     // collateralToken argument in the interface supports future-use cases
     @param ratio the minting ratio
     @param maxOrderVolume recommended maximum order size, specified by governance. Defaults to unlimited     
     */    

    function getMintingRatio2(address oneToken, address /* collateralToken */) public view override returns(uint256 ratio, uint256 maxOrderVolume) {
        address oracle = oneTokenOracles[oneToken];
        return getMintingRatio4(oneToken, oracle, NULL_ADDRESS, NULL_ADDRESS);
    }

    /**
     @notice returns an adjusted minting ratio
     @dev anyone calls this to inspect any oneToken minting ratio based on arbitry oracles
     @param oneToken oneToken implementation to inspect
     @param oneTokenOracle explicit oracle selection
     // collateralToken argument in the interface supports future-use cases
     @param ratio the minting ratio
     @param maxOrderVolume recommended maximum order size, specified by governance. Defaults to unlimited     
     */   
    function getMintingRatio4(address oneToken, address oneTokenOracle, address /* collateralToken */, address /* collateralOracle */) public override view returns(uint256 ratio, uint256 maxOrderVolume) {
        Parameters storage p = parameters[oneToken];
        require(p.set, "Incremental: mintmaster is not initialized");
        
        // Both OneToken and oracle response are in precision 18. No conversion is necessary.
        (uint256 quote, /* uint256 volatility */ ) = IOracle(oneTokenOracle).read(oneToken, PRECISION);
        ratio = p.lastRatio;        
        if(quote == PRECISION) return(ratio, p.maxOrderVolume);
        uint256 stepSize = p.stepSize;
        maxOrderVolume = p.maxOrderVolume;
        if(quote < PRECISION && ratio < p.maxRatio) {
            ratio += stepSize;
            if (ratio > p.maxRatio) {
                ratio = p.maxRatio;
            }
        }
        if(quote > PRECISION && ratio > p.minRatio) {
            ratio -= stepSize;
            if (ratio < p.minRatio) {
                ratio = p.minRatio;
            }
        }
    }

    /**
     @notice records and returns an adjusted minting ratio for a oneToken implemtation
     @dev oneToken implementations calls this periodically, e.g. in the minting process
     // collateralToken argument in the interface supports future-use cases
     @param ratio the minting ratio
     @param maxOrderVolume recommended maximum order size, specified by governance. Defaults to unlimited
     */
    function updateMintingRatio(address /* collateralToken */) external override returns(uint256 ratio, uint256 maxOrderVolume) {
        if (lastUpdatedBlock >= block.number) {
            (ratio, maxOrderVolume) = getMintingRatio2(msg.sender, NULL_ADDRESS);
        } else {
            lastUpdatedBlock = block.number;
            return _updateMintingRatio(msg.sender, NULL_ADDRESS);
        }
    }

    /**
     @notice records and returns an adjusted minting ratio for a oneToken implemtation
     @dev internal use only
     @param oneToken the oneToken implementation to evaluate
     // collateralToken argument in the interface supports future-use cases
     @param ratio the minting ratio
     @param maxOrderVolume recommended maximum order size, specified by governance. Defaults to unlimited
     */    
    function _updateMintingRatio(address oneToken, address /* collateralToken */) private returns(uint256 ratio, uint256 maxOrderVolume) {
        Parameters storage p = parameters[oneToken];
        require(p.set, "Incremental: mintmaster is not initialized");
        address o = oneTokenOracles[oneToken];
        IOracle(o).update(oneToken);
        (ratio, maxOrderVolume) = getMintingRatio2(oneToken, NULL_ADDRESS);
        p.lastRatio = ratio;
        emit UpdateMintingRatio(msg.sender, oneToken, ratio, maxOrderVolume);
    }

    /**
     * Governance functions
     */

    /**
     @notice adjusts the rate of minting ratio change
     @dev only the governance that owns the token implentation can adjust the mintMaster's parameters
     @param oneToken the implementation to work with
     @param stepSize the step size must be smaller than the difference of min and max
     */
    function setStepSize(address oneToken, uint256 stepSize) external onlyTokenOwner(oneToken) {
        Parameters storage p = parameters[oneToken];
        require(stepSize < p.maxRatio - p.minRatio || stepSize == 0, "Incremental: stepSize must be < (max - min) or zero.");
        p.stepSize = stepSize;
        emit StepSizeSet(msg.sender, oneToken, stepSize);
    }

    /**
     @notice sets the minimum minting ratio
     @dev only the governance that owns the token implentation can adjust the mintMaster's parameters
     if the new minimum is higher than current minting ratio, the current ratio will be adjusted to minRatio
     @param oneToken the implementation to work with
     @param minRatio the new lower bound for the minting ratio
     */    
    function setMinRatio(address oneToken, uint256 minRatio) external onlyTokenOwner(oneToken) {
        Parameters storage p = parameters[oneToken];
        require(minRatio <= p.maxRatio, "Incremental: minRatio must be <= maxRatio");
        require(p.stepSize < p.maxRatio - minRatio || p.stepSize == 0, "Incremental: stepSize must be < (max - min) or zero.");
        p.minRatio = minRatio;
        if(minRatio > p.lastRatio) setRatio(oneToken, minRatio);
        emit MinRatioSet(msg.sender, oneToken, minRatio);
    }

    /**
     @notice sets the maximum minting ratio
     @dev only the governance that owns the token implentation can adjust the mintMaster's parameters
     if the new maximum is lower is than current minting ratio, the current ratio will be set to maxRatio
     @param oneToken the implementation to work with
     @param maxRatio the new upper bound for the minting ratio
     */ 
    function setMaxRatio(address oneToken, uint256 maxRatio) external onlyTokenOwner(oneToken) {
        Parameters storage p = parameters[oneToken];
        require(maxRatio >= p.minRatio, "Incremental: maxRatio must be >= minRatio");
        require(maxRatio <= PRECISION, "Incremental: maxRatio must <= 100%");
        require(p.stepSize < maxRatio - p.minRatio || p.stepSize == 0, "Incremental: stepSize must be < (max - min) or zero.");
        p.maxRatio = maxRatio;
        if(maxRatio < p.lastRatio) setRatio(oneToken, maxRatio);
        emit MaxRatioSet(msg.sender, oneToken, maxRatio);
    }

    /**
     @notice sets the current minting ratio
     @dev only the governance that owns the token implentation can adjust the mintMaster's parameters
     @param oneToken the implementation to work with
     @param ratio must be in the min-max range
     */
    function setRatio(address oneToken, uint256 ratio) public onlyTokenOwner(oneToken) {
        Parameters storage p = parameters[oneToken];
        require(ratio > 0, "Incremental: ratio must be > 0");
        require(ratio <= PRECISION, "Incremental: ratio must be <= 100%");
        require(ratio >= p.minRatio, "Incremental: ratio must be >= minRatio");
        require(ratio <= p.maxRatio, "Incremental: ratio must be <= maxRatio");
        p.lastRatio = ratio;
        emit RatioSet(msg.sender, oneToken, ratio);
    }

}

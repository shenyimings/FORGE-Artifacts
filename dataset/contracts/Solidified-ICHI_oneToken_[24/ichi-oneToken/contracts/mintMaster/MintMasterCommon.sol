// SPDX-License-Identifier: Unlicensed

pragma solidity 0.7.6;

import "../common/ICHIModuleCommon.sol";
import "../interface/IMintMaster.sol";
import "../interface/IOneTokenV1Base.sol";
import "../interface/IOneTokenFactory.sol";

abstract contract MintMasterCommon is IMintMaster, ICHIModuleCommon{

    bytes32 constant public override MODULE_TYPE = keccak256(abi.encodePacked("ICHI V1 MintMaster Implementation"));
    mapping(address => address) public override oneTokenOracles;

    event MintMasterDeployed(address sender, address oneTokenFactory, string description);
    event MintMasterInitialized(address sender, address oneToken, address oneTokenOracle);

    /**
     @notice controllers are bound to factories at deployment time
     @param oneTokenFactory_ factory to bind to
     @param description_ human-readable, descriptive only
     */ 
    constructor(address oneTokenFactory_, string memory description_) 
        ICHIModuleCommon(oneTokenFactory_, ModuleType.MintMaster, description_) 
    { 
        emit MintMasterDeployed(msg.sender, oneTokenFactory_, description_);
    }

    /**
     @notice initializes the common interface with parameters managed by msg.sender, usually a oneToken.
     @dev Initialize from each instance. Re-initialization is acceptabe.
     @param oneTokenOracle gets the exchange rate of the oneToken
     */
    function init(address oneTokenOracle) external onlyKnownToken virtual override {
        emit MintMasterInitialized(msg.sender, msg.sender, oneTokenOracle);
    }

    /**
     @notice sets up the common interface
     @dev only called when msg.sender is the oneToken or the oneToken governance
     @param oneToken the oneToken context for the multi-tenant MintMaster implementation
     @param oneTokenOracle proposed oracle for the oneToken that intializes the mintMaster
     */
    function _initMintMaster(address oneToken, address oneTokenOracle) internal {
        require(IOneTokenFactory(IOneTokenV1Base(oneToken).oneTokenFactory()).isModule(oneTokenOracle), "MintMasterCommon: unknown oracle");
        require(IOneTokenFactory(IOneTokenV1Base(oneToken).oneTokenFactory()).isValidModuleType(oneTokenOracle, ModuleType.Oracle), "MintMasterCommon: given oracle is not valid for oneToken (msg.sender)");
        oneTokenOracles[oneToken] = oneTokenOracle;
        emit MintMasterInitialized(msg.sender, oneToken, oneTokenOracle);
    }
}

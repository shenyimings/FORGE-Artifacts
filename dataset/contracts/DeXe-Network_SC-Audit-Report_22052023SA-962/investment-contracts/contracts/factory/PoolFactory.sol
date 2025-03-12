// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

import "@solarity/solidity-lib/contracts-registry/pools/pool-factory/AbstractPoolFactory.sol";
import "@solarity/solidity-lib/libs/data-structures/memory/Vector.sol";

import "@spherex-xyz/engine-contracts/src/SphereXEngine.sol";

import "../interfaces/factory/IPoolFactory.sol";
import "../interfaces/core/IContractsRegistry.sol";
import "../interfaces/core/ISBT721.sol";

import {DistributionProposal} from "../gov/proposals/DistributionProposal.sol";
import {TokenSaleProposal} from "../gov/proposals/TokenSaleProposal.sol";
import {ERC721Expert} from "../gov/ERC721/experts/ERC721Expert.sol";
import {ERC721Multiplier} from "../gov/ERC721/multipliers/ERC721Multiplier.sol";
import "../gov/GovPool.sol";
import "../gov/user-keeper/GovUserKeeper.sol";
import "../gov/settings/GovSettings.sol";
import "../gov/validators/GovValidators.sol";

import "../core/CoreProperties.sol";
import {PoolRegistry} from "./PoolRegistry.sol";

import "../proxy/ProtectedPublicBeaconProxy.sol";

import "../libs/factory/GovTokenDeployer.sol";

import "../core/Globals.sol";

contract PoolFactory is IPoolFactory, AbstractPoolFactory {
    using GovTokenDeployer for *;
    using Vector for Vector.AddressVector;

    string internal constant EXPERT_NAME_POSTFIX = (" Expert NFT");
    string internal constant EXPERT_SYMBOL_POSTFIX = (" EXPNFT");

    string internal constant NFT_MULTIPLIER_NAME_POSTFIX = (" Multiplier NFT");
    string internal constant NFT_MULTIPLIER_SYMBOL_POSTFIX = (" MULTNFT");

    PoolRegistry internal _poolRegistry;
    CoreProperties internal _coreProperties;
    ISBT721 internal _babt;
    ISphereXEngine internal _poolSphereXEngine;

    mapping(bytes32 => bool) private _usedSalts;

    event DaoPoolDeployed(
        string name,
        address govPool,
        GovPool.Dependencies govPoolDeps,
        address distributionProposal,
        address tokenSale,
        address token,
        address sender
    );

    function setDependencies(address contractsRegistry, bytes memory data) public override {
        super.setDependencies(contractsRegistry, data);

        IContractsRegistry registry = IContractsRegistry(contractsRegistry);

        _poolRegistry = PoolRegistry(registry.getPoolRegistryContract());
        _coreProperties = CoreProperties(registry.getCorePropertiesContract());
        _babt = ISBT721(registry.getBABTContract());
        _poolSphereXEngine = ISphereXEngine(registry.getPoolSphereXEngineContract());
    }

    function deployGovPool(GovPoolDeployParams calldata parameters) external override {
        string memory poolType = _poolRegistry.GOV_POOL_NAME();

        Vector.AddressVector memory vector = Vector.newAddress();
        GovPool.Dependencies memory govPoolDeps;

        govPoolDeps.validatorsAddress = payable(_deploy(_poolRegistry.VALIDATORS_NAME()));
        govPoolDeps.userKeeperAddress = _deploy(_poolRegistry.USER_KEEPER_NAME());
        address distributionAddress = _deploy2(
            _poolRegistry.DISTRIBUTION_PROPOSAL_NAME(),
            parameters.name
        );
        govPoolDeps.settingsAddress = _deploy(_poolRegistry.SETTINGS_NAME());
        address poolProxy = _deploy2(poolType, parameters.name);

        govPoolDeps.expertNftAddress = _deploy2(_poolRegistry.EXPERT_NFT_NAME(), parameters.name);
        govPoolDeps.nftMultiplierAddress = _deploy2(
            _poolRegistry.NFT_MULTIPLIER_NAME(),
            parameters.name
        );

        vector.push(poolProxy);
        vector.push(govPoolDeps.validatorsAddress);
        vector.push(govPoolDeps.userKeeperAddress);
        vector.push(govPoolDeps.settingsAddress);
        vector.push(govPoolDeps.expertNftAddress);
        vector.push(govPoolDeps.nftMultiplierAddress);

        if (parameters.votePowerParams.voteType == VotePowerType.LINEAR_VOTES) {
            govPoolDeps.votePowerAddress = _deploy2(
                _poolRegistry.LINEAR_POWER_NAME(),
                parameters.name
            );

            vector.push(govPoolDeps.votePowerAddress);
        } else if (parameters.votePowerParams.voteType == VotePowerType.POLYNOMIAL_VOTES) {
            govPoolDeps.votePowerAddress = _deploy2(
                _poolRegistry.POLYNOMIAL_POWER_NAME(),
                parameters.name
            );

            vector.push(govPoolDeps.votePowerAddress);
        } else {
            govPoolDeps.votePowerAddress = parameters.votePowerParams.presetAddress;
        }

        address tokenSaleProxy = _deployTokenSale(parameters, poolProxy);

        vector.push(distributionAddress);
        vector.push(tokenSaleProxy);

        emit DaoPoolDeployed(
            parameters.name,
            poolProxy,
            govPoolDeps,
            distributionAddress,
            tokenSaleProxy,
            parameters.userKeeperParams.tokenAddress,
            msg.sender
        );

        _addToEngine(vector);

        _updateSalt(parameters.name);

        _initGovPool(poolProxy, govPoolDeps, parameters);

        DistributionProposal(payable(distributionAddress)).__DistributionProposal_init(poolProxy);
        TokenSaleProposal(tokenSaleProxy).__TokenSaleProposal_init(poolProxy);

        GovSettings(govPoolDeps.settingsAddress).transferOwnership(poolProxy);
        GovUserKeeper(payable(govPoolDeps.userKeeperAddress)).transferOwnership(poolProxy);
        GovValidators(govPoolDeps.validatorsAddress).transferOwnership(poolProxy);
        ERC721Expert(govPoolDeps.expertNftAddress).transferOwnership(poolProxy);
        ERC721Multiplier(govPoolDeps.nftMultiplierAddress).transferOwnership(poolProxy);

        if (parameters.votePowerParams.voteType != VotePowerType.CUSTOM_VOTES) {
            Ownable(govPoolDeps.votePowerAddress).transferOwnership(poolProxy);
        }

        _register(poolType, poolProxy);
        _injectDependencies(poolProxy);
        _injectDependencies(tokenSaleProxy);
    }

    function predictGovAddresses(
        address deployer,
        string calldata poolName
    ) external view override returns (GovPoolPredictedAddresses memory predictedAddresses) {
        if (bytes(poolName).length == 0) {
            return predictedAddresses;
        }

        PoolRegistry poolRegistry = _poolRegistry;
        bytes32 govSalt = _calculateGovSalt(deployer, poolName);

        return
            GovPoolPredictedAddresses(
                _predictPoolAddress(poolRegistry.GOV_POOL_NAME(), govSalt),
                _predictPoolAddress(poolRegistry.TOKEN_SALE_PROPOSAL_NAME(), govSalt),
                govSalt.predictTokenAddress(),
                _predictPoolAddress(poolRegistry.DISTRIBUTION_PROPOSAL_NAME(), govSalt),
                _predictPoolAddress(poolRegistry.EXPERT_NFT_NAME(), govSalt),
                _predictPoolAddress(poolRegistry.NFT_MULTIPLIER_NAME(), govSalt)
            );
    }

    function _deployTokenSale(
        GovPoolDeployParams calldata parameters,
        address poolProxy
    ) internal returns (address tokenSaleProxy) {
        tokenSaleProxy = _deploy2(_poolRegistry.TOKEN_SALE_PROPOSAL_NAME(), parameters.name);

        bytes32 govSalt = _calculateGovSalt(tx.origin, parameters.name);

        if (parameters.userKeeperParams.tokenAddress == govSalt.predictTokenAddress()) {
            poolProxy.deployToken(govSalt, parameters.tokenParams);
        }
    }

    function _addToEngine(Vector.AddressVector memory vector) internal {
        ISphereXEngine engine = _poolSphereXEngine;

        for (uint256 i = 0; i < vector.length(); i++) {
            engine.addAllowedSenderOnChain(vector.at(i));
        }
    }

    function _initGovPool(
        address poolProxy,
        GovPool.Dependencies memory govPoolDeps,
        GovPoolDeployParams calldata parameters
    ) internal {
        uint256 babtId;

        if (_babt.balanceOf(msg.sender) > 0) {
            babtId = _babt.tokenIdOf(msg.sender);
        }

        GovValidators(govPoolDeps.validatorsAddress).__GovValidators_init(
            parameters.validatorsParams.name,
            parameters.validatorsParams.symbol,
            parameters.validatorsParams.proposalSettings,
            parameters.validatorsParams.validators,
            parameters.validatorsParams.balances
        );
        GovUserKeeper(payable(govPoolDeps.userKeeperAddress)).__GovUserKeeper_init(
            parameters.userKeeperParams.tokenAddress,
            parameters.userKeeperParams.nftAddress,
            parameters.userKeeperParams.individualPower,
            parameters.userKeeperParams.nftsTotalSupply
        );
        GovSettings(govPoolDeps.settingsAddress).__GovSettings_init(
            address(poolProxy),
            address(govPoolDeps.validatorsAddress),
            address(govPoolDeps.userKeeperAddress),
            parameters.settingsParams.proposalSettings,
            parameters.settingsParams.additionalProposalExecutors
        );
        GovPool(payable(poolProxy)).__GovPool_init(
            govPoolDeps,
            parameters.verifier,
            parameters.onlyBABTHolders,
            babtId,
            parameters.descriptionURL,
            parameters.name
        );
        ERC721Expert(govPoolDeps.expertNftAddress).__ERC721Expert_init(
            string.concat(parameters.name, EXPERT_NAME_POSTFIX),
            string.concat(parameters.name, EXPERT_SYMBOL_POSTFIX)
        );
        ERC721Multiplier(govPoolDeps.nftMultiplierAddress).__ERC721Multiplier_init(
            string.concat(parameters.name, NFT_MULTIPLIER_NAME_POSTFIX),
            string.concat(parameters.name, NFT_MULTIPLIER_SYMBOL_POSTFIX)
        );

        if (parameters.votePowerParams.voteType != VotePowerType.CUSTOM_VOTES) {
            (bool success, ) = (govPoolDeps.votePowerAddress).call(
                parameters.votePowerParams.initData
            );
            require(success, "PoolFactory: power init failed");
        }
    }

    function _deploy(string memory poolType) internal returns (address) {
        return _deploy(address(_poolRegistry), poolType);
    }

    function _deploy2(string memory poolType, string memory poolName) internal returns (address) {
        bytes32 salt = _calculateGovSalt(tx.origin, poolName);

        require(bytes(poolName).length != 0, "PoolFactory: pool name cannot be empty");
        require(!_usedSalts[salt], "PoolFactory: pool name is already taken");

        return _deploy2(address(_poolRegistry), poolType, salt);
    }

    function _updateSalt(string memory poolName) internal {
        _usedSalts[_calculateGovSalt(tx.origin, poolName)] = true;
    }

    function _register(string memory poolType, address poolProxy) internal {
        _register(address(_poolRegistry), poolType, poolProxy);
    }

    function _injectDependencies(address proxy) internal {
        _injectDependencies(address(_poolRegistry), proxy);
    }

    function _deploy(
        address poolRegistry,
        string memory poolType
    ) internal override returns (address) {
        return
            address(
                new ProtectedPublicBeaconProxy(
                    AbstractPoolContractsRegistry(poolRegistry).getProxyBeacon(poolType),
                    bytes("")
                )
            );
    }

    function _deploy2(
        address poolRegistry,
        string memory poolType,
        bytes32 salt
    ) internal override returns (address) {
        return
            address(
                new ProtectedPublicBeaconProxy{salt: salt}(
                    AbstractPoolContractsRegistry(poolRegistry).getProxyBeacon(poolType),
                    bytes("")
                )
            );
    }

    function _predictPoolAddress(
        address poolRegistry,
        string memory poolType,
        bytes32 salt
    ) internal view override returns (address) {
        bytes32 bytecodeHash = keccak256(
            abi.encodePacked(
                type(ProtectedPublicBeaconProxy).creationCode,
                abi.encode(
                    AbstractPoolContractsRegistry(poolRegistry).getProxyBeacon(poolType),
                    bytes("")
                )
            )
        );

        return Create2.computeAddress(salt, bytecodeHash);
    }

    function _predictPoolAddress(
        string memory poolType,
        bytes32 salt
    ) internal view returns (address) {
        return _predictPoolAddress(address(_poolRegistry), poolType, salt);
    }

    function _calculateGovSalt(
        address deployer,
        string memory poolName
    ) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(deployer, poolName));
    }
}

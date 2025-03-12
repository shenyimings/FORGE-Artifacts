// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "@solarity/solidity-lib/contracts-registry/pools/presets/MultiOwnablePoolContractsRegistry.sol";
import "@solarity/solidity-lib/libs/arrays/Paginator.sol";

import "../interfaces/factory/IPoolRegistry.sol";
import "../interfaces/core/IContractsRegistry.sol";

import "../proxy/PoolBeacon.sol";

contract PoolRegistry is IPoolRegistry, MultiOwnablePoolContractsRegistry {
    using EnumerableSet for EnumerableSet.AddressSet;
    using Paginator for EnumerableSet.AddressSet;
    using Math for uint256;

    string public constant GOV_POOL_NAME = "GOV_POOL";
    string public constant SETTINGS_NAME = "SETTINGS";
    string public constant VALIDATORS_NAME = "VALIDATORS";
    string public constant USER_KEEPER_NAME = "USER_KEEPER";
    string public constant DISTRIBUTION_PROPOSAL_NAME = "DISTRIBUTION_PROPOSAL";
    string public constant TOKEN_SALE_PROPOSAL_NAME = "TOKEN_SALE_PROPOSAL";

    string public constant EXPERT_NFT_NAME = "EXPERT_NFT";
    string public constant NFT_MULTIPLIER_NAME = "NFT_MULTIPLIER";

    string public constant LINEAR_POWER_NAME = "LINEAR_POWER";
    string public constant POLYNOMIAL_POWER_NAME = "POLYNOMIAL_POWER";

    address internal _poolFactory;
    address internal _poolSphereXEngine;

    modifier onlyPoolFactory() {
        _onlyPoolFactory();
        _;
    }

    function setDependencies(address contractsRegistry, bytes memory data) public override {
        super.setDependencies(contractsRegistry, data);

        _poolFactory = IContractsRegistry(contractsRegistry).getPoolFactoryContract();
        _poolSphereXEngine = IContractsRegistry(contractsRegistry).getPoolSphereXEngineContract();
    }

    function addProxyPool(
        string memory name,
        address poolAddress
    ) public override(IPoolRegistry, MultiOwnablePoolContractsRegistry) onlyPoolFactory {
        _addProxyPool(name, poolAddress);
    }

    function toggleSphereXEngine(bool on) external onlyOwner {
        address sphereXEngine = on ? _poolSphereXEngine : address(0);

        _setSphereXEngine(GOV_POOL_NAME, sphereXEngine);
        _setSphereXEngine(SETTINGS_NAME, sphereXEngine);
        _setSphereXEngine(VALIDATORS_NAME, sphereXEngine);
        _setSphereXEngine(USER_KEEPER_NAME, sphereXEngine);
        _setSphereXEngine(DISTRIBUTION_PROPOSAL_NAME, sphereXEngine);
        _setSphereXEngine(TOKEN_SALE_PROPOSAL_NAME, sphereXEngine);
        _setSphereXEngine(EXPERT_NFT_NAME, sphereXEngine);
        _setSphereXEngine(NFT_MULTIPLIER_NAME, sphereXEngine);
        _setSphereXEngine(LINEAR_POWER_NAME, sphereXEngine);
        _setSphereXEngine(POLYNOMIAL_POWER_NAME, sphereXEngine);
    }

    function protectPoolFunctions(
        string calldata poolName,
        bytes4[] calldata selectors
    ) external onlyOwner {
        SphereXProxyBase(getProxyBeacon(poolName)).addProtectedFuncSigs(selectors);
    }

    function unprotectPoolFunctions(
        string calldata poolName,
        bytes4[] calldata selectors
    ) external onlyOwner {
        SphereXProxyBase(getProxyBeacon(poolName)).removeProtectedFuncSigs(selectors);
    }

    function isGovPool(address potentialPool) external view override returns (bool) {
        return isPool(GOV_POOL_NAME, potentialPool);
    }

    function _setSphereXEngine(string memory poolName, address sphereXEngine) internal {
        PoolBeacon(getProxyBeacon(poolName)).changeSphereXEngine(sphereXEngine);
    }

    function _onlyPoolFactory() internal view {
        require(_poolFactory == msg.sender, "PoolRegistry: Caller is not a factory");
    }

    function _deployProxyBeacon() internal override returns (address) {
        return address(new PoolBeacon(msg.sender, address(this), address(0)));
    }
}

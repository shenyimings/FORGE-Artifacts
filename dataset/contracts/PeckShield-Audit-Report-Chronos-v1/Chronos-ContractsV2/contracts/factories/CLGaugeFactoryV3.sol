// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;


import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/StorageSlot.sol";


interface IGauge{
    function setDistribution(address _distro) external;
    function initialize(
        address _rewardToken,
        address _ve,
        address _token,
        address _distribution,
        address _internal_bribe,
        address _external_bribe,
        bool _isForPair
    ) external;
}

interface IGaugeFactoryImpl {
    function gaugeImplementation () external view returns (address impl);
}

contract GaugeProxy {
    address immutable private gaugeFactory;
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    constructor () {
        gaugeFactory = msg.sender;
    }

    function _getImplementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    function _setImplementation(address newImplementation) private {
        StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }

    fallback () payable external {
        address impl = IGaugeFactoryImpl(gaugeFactory).gaugeImplementation();
        require(impl != address(0));

        //Just for etherscan compatibility
        if (impl != _getImplementation() && msg.sender != (address(0))) {
            _setImplementation(impl);
        }

        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())
            let result := delegatecall(gas(), impl, ptr, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(ptr, 0, size)

            switch result
            case 0 { revert(ptr, size) }
            default { return(ptr, size) }
        }
    }
}

contract CLGaugeFactoryV3 is OwnableUpgradeable {
    
    uint256[50] __gap;
    
    address public last_gauge;
    address public gaugeImplementation;
    
    event GaugeImplementationChanged( address _oldGaugeImplementation, address _newGaugeImplementation);

    function initialize(address _gaugeImplementation) initializer  public {
        __Ownable_init();
        gaugeImplementation = _gaugeImplementation;
    }

    function createGaugeV2(address _rewardToken,address _ve,address _token,address _distribution, address _internal_bribe, address _external_bribe, bool _isPair) external returns (address) {
        last_gauge = address(new GaugeProxy());
        IGauge(last_gauge).initialize(_rewardToken,_ve,_token,_distribution,_internal_bribe,_external_bribe,_isPair);
        return last_gauge;
    }

    function gaugeOwner() external view returns (address) {
        return owner();
    }

    function changeImplementation(address _implementation) external onlyOwner {
        require(_implementation != address(0));
        emit GaugeImplementationChanged(gaugeImplementation, _implementation);
        gaugeImplementation = _implementation;
    }

    function setDistribution(address _gauge, address _newDistribution) external onlyOwner {
        IGauge(_gauge).setDistribution(_newDistribution);
    }

}

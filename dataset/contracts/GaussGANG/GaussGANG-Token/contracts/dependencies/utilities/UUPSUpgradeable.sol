// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;
import "./Initializable.sol";
import "./BEP20Upgrade.sol";



/*  An upgradeability mechanism designed for UUPS proxies. The functions included here can perform an upgrade of an
    {ERC1967Proxy}, when this contract is set as the implementation behind such a proxy.
 
    A security mechanism ensures that an upgrade does not turn off upgradeability accidentally, although this risk is
    reinstated if the upgrade retains upgradeability but removes the security mechanism, e.g. by replacing
    `UUPSUpgradeable` with a custom implementation of upgrades.
 
    NOTE:   The {_authorizeUpgrade} function must be overridden to include access restriction to the upgrade mechanism.
*/
abstract contract UUPSUpgradeable is Initializable, BEP20Upgrade {

    function __UUPSUpgradeable_init() internal initializer {
        __BEP20Upgrade_init_unchained();
        __UUPSUpgradeable_init_unchained();
    }
    

    function __UUPSUpgradeable_init_unchained() internal initializer {}


    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable state-variable-assignment
    address private immutable __self = address(this);    

    /*  Check that the execution is being performed through a delegatecall call and that the execution context is
        a proxy contract with an implementation (as defined in ERC1967) pointing to self. This should only be the case
        for UUPS and transparent proxies that are using the current contract as their implementation. Execution of a
        function through ERC1167 minimal proxies (clones) would not normally pass this test, but is not guaranteed to fail.
    */
    modifier onlyProxy() {
        require(address(this) != __self, "Function must be called through delegatecall");
        require(_getImplementation() == __self, "Function must be called through active proxy");
        _;
    }

    
    /* Upgrade the implementation of the proxy to `newImplementation`.
            - Calls {_authorizeUpgrade}; Emits an {Upgraded} event. */
    function upgradeTo(address newImplementation) external virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallSecure(newImplementation, new bytes(0), false);
    }


    /*  Upgrade the implementation of the proxy to `newImplementation`, and subsequently execute the function call encoded in `data`.
            - Calls {_authorizeUpgrade}; Emits an {Upgraded} event.                                                                 */
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallSecure(newImplementation, data, true);
    }
    

    // Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by {upgradeTo} and {upgradeToAndCall}.
    function _authorizeUpgrade(address newImplementation) internal virtual;
}
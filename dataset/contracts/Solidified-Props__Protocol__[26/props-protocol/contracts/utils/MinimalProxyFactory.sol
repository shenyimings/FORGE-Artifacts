// SPDX-License-Identifier: MIT

pragma solidity 0.7.3;

/**
 * @title  MinimalProxyFactory
 * @author Forked from: OpenZeppelin
 * @dev    Factory contract for deploying minimal proxies.
 */
abstract contract MinimalProxyFactory {
    event ProxyCreated(address proxy);

    /**
     * @dev Deploy a minimal proxy contract.
     * @param _logic The address of the implementation contract
     * @param _data The initial message to send to the newly deployed proxy contract
     * @return proxy The address of the newly deployed proxy contract
     */
    function deployMinimal(address _logic, bytes memory _data) public returns (address proxy) {
        // Adapted from https://github.com/optionality/clone-factory/blob/32782f82dfc5a00d103a7e61a17a5dedbd1e8e9d/contracts/CloneFactory.sol

        // Deploy the proxy, pointing to the implementation contract
        bytes20 targetBytes = bytes20(_logic);
        assembly {
            let clone := mload(0x40)
            mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone, 0x14), targetBytes)
            mstore(
                add(clone, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            proxy := create(0, clone, 0x37)
        }

        emit ProxyCreated(address(proxy));

        // Initialize the proxy
        if (_data.length > 0) {
            // solhint-disable-next-line avoid-low-level-calls
            (bool success, ) = proxy.call(_data);
            require(success);
        }
    }
}

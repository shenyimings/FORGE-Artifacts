// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import "./BaseImmutableAdminUpgradeabilityProxy.sol";
import "./InitializableUpgradeabilityProxy.sol";

/**
 * @title InitializableAdminUpgradeabilityProxy
 * @dev Extends BaseAdminUpgradeabilityProxy with an initializer function
 */
contract InitializableImmutableAdminUpgradeabilityProxy is
	BaseImmutableAdminUpgradeabilityProxy,
	InitializableUpgradeabilityProxy
{
	constructor(address admin) BaseImmutableAdminUpgradeabilityProxy(admin) {}

	/**
	 * @dev Only fall back when the sender is not the admin.
	 */
	function _willFallback() internal override(BaseImmutableAdminUpgradeabilityProxy, Proxy) {
		BaseImmutableAdminUpgradeabilityProxy._willFallback();
	}
}

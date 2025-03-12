// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenAccessControl is Ownable {
	mapping(address => bool) public minters;
	mapping(address => bool) public allowlistedAddresses;

	bool public paused;
	bool public foreverUnpaused;
	bool public mintingDisabled;
	bool public allowlistDisabled;

	event MintersAdded(address[] minters);
	event MintersRemoved(address[] minters);
	event AllowlistedAddressesAdded(address[] minters);
	event AllowlistedAddressesRemoved(address[] minters);

	event AllowlistDisabled();
	event PauseStatusChanged(bool status);
	event PausingDisabledForever();
	event MintingDisabledForever();


	modifier notPaused() {
		require(!paused || (!allowlistDisabled && allowlistedAddresses[msg.sender]), "AccessControl: User cannot transfer");
		_;
	}

	modifier isMinter(address _caller) {
		require(!mintingDisabled, "AccessControl: Contract cannot mint tokens anymore");
		require(minters[_caller], "AccessControl: Cannot mint");
		_;
	}

	function disableAllowlist() external onlyOwner {
		require(!allowlistDisabled, "AccessControl: Allowlist already disabled");
		allowlistDisabled = true;
		emit AllowlistDisabled();
	}

	function changePauseStatus(bool _status) external onlyOwner {
		require(!foreverUnpaused, "AccessControl: Contract is unpaused forever");
		paused = _status;
		emit PauseStatusChanged(_status);
	}


	function disablePausingForever() external onlyOwner {
		require(!foreverUnpaused, "AccessControl: Contract is unpaused forever");
		foreverUnpaused = true;
		paused = false;
		emit PausingDisabledForever();
	}

	function addMinters(address[] calldata _minters) external onlyOwner {
		require(!mintingDisabled, "AccessControl: Contract cannot mint tokens anymore");

		for(uint256 i = 0; i < _minters.length; i++)
			minters[_minters[i]] = true;
		emit MintersAdded(_minters);
	}

	function removeMinters(address[] calldata _minters) external onlyOwner {
		require(!mintingDisabled, "AccessControl: Contract cannot mint tokens anymore");

		for(uint256 i = 0; i < _minters.length; i++)
			minters[_minters[i]] = false;
		emit MintersRemoved(_minters);
	}

	function addAllowlistedAddresses(address[] calldata _addresses) external onlyOwner {
		require(!allowlistDisabled, "AccessControl: Allowlist already disabled");

		for(uint256 i = 0; i < _addresses.length; i++)
			allowlistedAddresses[_addresses[i]] = true;
		emit AllowlistedAddressesAdded(_addresses);
	}

	function removeAllowlistedAddresses(address[] calldata _addresses) external onlyOwner {
		require(!allowlistDisabled, "AccessControl: Allowlist already disabled");

		for(uint256 i = 0; i < _addresses.length; i++)
			allowlistedAddresses[_addresses[i]] = false;
		emit AllowlistedAddressesRemoved(_addresses);
	}

	function disableMintingForever() external onlyOwner {
		require(!mintingDisabled, "AccessControl: Contract cannot mint anymore");
		mintingDisabled = true;
		emit MintingDisabledForever();
	}
}
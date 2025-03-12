// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.7;

import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/**
 * @title ConsensusVault responsible for managing initial capital and reward
 */
contract ConsensusVault is UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    address private _liquidStakingProxyAddress;

    event LiquidStakingChanged(address _from, address _to);
    event Transferred(address _to, uint256 _amount);

    modifier onlyLiquidStaking() {
        require(_liquidStakingProxyAddress == msg.sender, "Not allowed to touch funds");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {}

    /**
     * @notice Initializes the NodeCapitalVault contract by setting the required external contracts ,
     *         ReentrancyGuardUpgradeable, OwnableUpgradeable, UUPSUpgradeable and `_aggregatorProxyAddress`
     * @dev initializer - A modifier that defines a protected initializer function that can be invoked at most once
     */
    function initialize() external initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        _liquidStakingProxyAddress = address(0x1);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function liquidStaking() external view returns (address) {
        return _liquidStakingProxyAddress;
    }

    function transfer(uint256 amount, address to) external nonReentrant onlyLiquidStaking {
        require(to != address(0), "Recipient address provided invalid");
        payable(to).transfer(amount);
        emit Transferred(to, amount);
    }

    /**
     * @notice Set proxy address of LiquidStaking
     * @param liquidStakingProxyAddress_ proxy address of LiquidStaking
     * @dev will only allow call of function by the address registered as the owner
     */
    function setLiquidStaking(address liquidStakingProxyAddress_) external onlyOwner {
        require(liquidStakingProxyAddress_ != address(0), "Aggregator address provided invalid");
        emit LiquidStakingChanged(_liquidStakingProxyAddress, liquidStakingProxyAddress_);
        _liquidStakingProxyAddress = liquidStakingProxyAddress_;
    }

    receive() external payable {}
}

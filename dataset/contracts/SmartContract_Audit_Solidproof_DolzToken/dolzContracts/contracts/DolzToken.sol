// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "./IDolzToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

struct BridgeUpdate {
    address newBridge;
    uint256 endGracePeriod;
}

/**
 * @notice ERC20 token smart contract with a mechanism for authorizing a bridge to mint and burn.
 */
contract DolzToken is IDolzToken, ERC20, Ownable {
    address private bridge;
    // Latest update launched, executed or not
    BridgeUpdate private bridgeUpdate;

    modifier onlyBridge() {
        require(msg.sender == bridge, "DolzToken: access denied");
        _;
    }

    /**
     * @param name Name of the token.
     * @param symbol Symbol of the token.
     * @param initialSupply Initial supply minted during deployment for the deployer.
     * No more minting afterward.
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }

    /**
     * @return Bridge address. Zero address if no bridge set.
     */
    function getBridge() external view returns (address) {
        return bridge;
    }

    /**
     * @return Bridge update proposal informations.
     * 1) The address of the bridge proposed.
     * 2) The timestamp in second from when the proposal can be executed.
     */
    function getBridgeUpdate() external view returns (BridgeUpdate memory) {
        return bridgeUpdate;
    }

    /**
     * @notice Create a bridge update that can be executed after 7 days.
     * The 7 days period is there to enable holders to check the new bridge contract
     * before it starts to be used.
     * @dev Only executable by the owner of the contract.
     * @param newBridge Address of the new bridge.
     */
    function launchBridgeUpdate(address newBridge) external onlyOwner {
        // Check if there already is an update waiting to be executed
        require(
            bridgeUpdate.newBridge == address(0),
            "DolzToken: current update has to be executed"
        );
        // Make sure the new address is a contract and not an EOA
        require(isContract(newBridge), "DolzToken: address provided is not a contract");

        uint256 endGracePeriod = block.timestamp + 604800; // 604800 = 7 days

        bridgeUpdate = BridgeUpdate(newBridge, endGracePeriod);

        emit BridgeUpdateLaunched(newBridge, endGracePeriod);
    }

    /**
     * @notice Execute the update once the grace period has passed, and change the bridge address.
     * @dev Only executable by the owner of the contract.
     */
    function executeBridgeUpdate() external onlyOwner {
        // Check that grace period has passed
        require(
            bridgeUpdate.endGracePeriod <= block.timestamp,
            "DolzToken: grace period has not finished"
        );
        // Check that update have not already been executed
        require(bridgeUpdate.newBridge != address(0), "DolzToken: update already executed");

        bridge = bridgeUpdate.newBridge;
        emit BridgeUpdateExecuted(bridgeUpdate.newBridge);

        delete bridgeUpdate;
    }

    /**
     * @dev Enable the bridge to mint tokens in case they are received from Ethereum mainnet.
     * Only executable by the bridge contract.
     * @param account Address of the user who should receive the tokens.
     * @param amount Amount of token that the user should receive.
     */
    function mintFromBridge(address account, uint256 amount) external override onlyBridge {
        // Internal _mint function of the inherited ERC20 contract
        _mint(account, amount);
    }

    /**
     * @dev Enable the bridge to burn tokens in case they are sent to Ethereum mainnet.
     * Only executable by the bridge contract.
     * @param account Address of the user who is bridging the tokens.
     * @param amount Amount of token that the user is bridging.
     */
    function burnFromBridge(address account, uint256 amount) external override onlyBridge {
        // Internal _burn function of the inherited ERC20 contract
        _burn(account, amount);
    }

    /**
     * @dev Publicly available burn function to destroy tokens.
     * Mainly used for the unsold tokens during the ICO.
     * @param amount Amount of tokens to burn.
     */
    function burn(uint256 amount) external override {
        // Internal _burn function of the inherited ERC20 contract
        _burn(msg.sender, amount);
    }

    /**
     * @dev Helper function that enables to check if an address is a contract.
     * @param target Address to check.
     */
    function isContract(address target) private view returns (bool) {
        uint256 size;
        assembly {
            // Retrieve the size of the code at the address
            size := extcodesize(target)
        }
        // Returns true if there is code
        return size > 0;
    }
}

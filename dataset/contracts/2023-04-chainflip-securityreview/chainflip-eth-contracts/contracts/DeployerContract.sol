pragma solidity ^0.8.0;

import "./Vault.sol";
import "./KeyManager.sol";
import "./StakeManager.sol";
import "./FLIP.sol";
import "./interfaces/IShared.sol";

/**
 * @title    Deployer contract
 * @notice   Upon deployment of this contract, all the necessary contracts will be
 *           deployed in a single transaction. This give atomocity to the deployment
 *           flow by deploying all the contracts and setting them up appropriately.
 */
contract DeployerContract is IShared {
    address[] internal whitelist;

    Vault public immutable vault;
    KeyManager public immutable keyManager;
    StakeManager public immutable stakeManager;
    FLIP public immutable flip;

    constructor(
        Key memory aggKey,
        address govKey,
        address commKey,
        uint256 minStake,
        uint256 initSupply,
        uint256 numGenesisValidators,
        uint256 genesisStake
    ) {
        KeyManager _keyManager = new KeyManager(aggKey, govKey, commKey);
        Vault _vault = new Vault(_keyManager);
        StakeManager _stakeManager = new StakeManager(_keyManager, minStake);
        FLIP _flip = new FLIP(
            initSupply,
            numGenesisValidators,
            genesisStake,
            address(_stakeManager),
            govKey,
            _keyManager
        );
        // Set the FLIP address to the StakeManager contract
        _stakeManager.setFlip(FLIP(address(_flip)));

        // Set the whitelist to the KeyManager contract
        whitelist = [address(_vault), address(_stakeManager), address(_flip)];
        _keyManager.setCanConsumeKeyNonce(whitelist);

        // Set values to storage
        vault = _vault;
        keyManager = _keyManager;
        stakeManager = _stakeManager;
        flip = _flip;
    }
}

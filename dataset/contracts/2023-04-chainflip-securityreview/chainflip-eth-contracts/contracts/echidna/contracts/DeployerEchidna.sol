pragma solidity ^0.8.0;

import "../../Vault.sol";
import "../../FLIP.sol";
import "../../KeyManager.sol";
import "../../StakeManager.sol";
import "../../DeployerContract.sol";

import "./KeyManagerEchidna.sol";
import "./StakeManagerEchidna.sol";
import "./VaultEchidna.sol";
import "./FLIPEchidna.sol";

contract DeployerEchidna is DeployerContract, KeyManagerEchidna, StakeManagerEchidna, FLIPEchidna, VaultEchidna {
    // Common constants across tests
    uint256 internal constant E_18 = 10 ** 18;
    uint256 internal constant PUBKEYX = 22479114112312168431982914496826057754130808976066989807481484372215659188398;
    uint8 internal constant PUBKEYYPARITY = 1;
    uint256 internal constant INIT_SUPPLY = 9 * 10 ** 7 * E_18;
    uint256 internal constant NUM_GENESIS_VALIDATORS = 5;
    uint256 internal constant GENESIS_STAKE = 5000 * E_18;

    uint256 internal _lastValidateTime;

    // Tests will pass the deploying values - deploying contracts mimicking deploy.py
    constructor(
        Key memory aggKey,
        address govKey,
        address commKey,
        uint256 minStake,
        uint256 initSupply,
        uint256 numGenesisValidators,
        uint256 genesisStake
    ) DeployerContract(aggKey, govKey, commKey, minStake, initSupply, numGenesisValidators, genesisStake) {
        _lastValidateTime = block.timestamp;
    }
}

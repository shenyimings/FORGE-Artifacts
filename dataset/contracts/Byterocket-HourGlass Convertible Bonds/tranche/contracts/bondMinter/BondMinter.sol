pragma solidity 0.8.3;

import "../interfaces/IBondFactory.sol";
import "../interfaces/IBondMinter.sol";
import "./BondConfigVault.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Canonical Bond Minter
 * @notice Implementation of IBondMinter
 */
contract BondMinter is IBondMinter, Ownable, BondConfigVault {
    /// @notice BondFactory that will be used to mint bonds
    IBondFactory public bondFactory;
    /// @notice Block timestamp (in seconds) of the last mint
    uint256 public lastMintTimestamp;
    /// @notice Minimum waiting period (in second) between mints allowed
    uint256 public waitingPeriod;

    /// @dev The bonds created by this minter
    mapping(address => bool) private _mintedBonds;

    /**
     * @notice Constructor for IBondMinter
     * @param _bondFactory bondFactory that will be used for minting bonds
     * @param _waitingPeriod minimum waiting period between mints
     */
    constructor(IBondFactory _bondFactory, uint256 _waitingPeriod) {
        bondFactory = _bondFactory;
        lastMintTimestamp = 0;
        waitingPeriod = _waitingPeriod;
    }

    /**
     * @inheritdoc IBondMinter
     * @dev Only the contract owner can call this method
     */
    function setBondFactory(IBondFactory _bondFactory) external override onlyOwner {
        bondFactory = _bondFactory;
    }

    /**
     * @inheritdoc IBondMinter
     * @dev Only the contract owner can call this
     */
    function setWaitingPeriod(uint256 _waitingPeriod) external override onlyOwner {
        waitingPeriod = _waitingPeriod;
    }

    /**
     * @inheritdoc IBondMinter
     * @dev Requires that enough time has passed since last minting. Uses block timestamp to calculate this.
     */
    function mintBonds() external override {
        require(
            block.timestamp - lastMintTimestamp >= waitingPeriod,
            "BondMinter: Not enough time has passed since last mint timestamp"
        );
        lastMintTimestamp = block.timestamp;

        for (uint256 i = 0; i < numConfigs(); i++) {
            BondConfig memory bondConfig = bondConfigAt(i);
            address bond = bondFactory.createBond(
                bondConfig.collateralToken,
                bondConfig.trancheRatios,
                block.timestamp + bondConfig.duration
            );

            _mintedBonds[bond] = true;

            emit BondMinted(bond);
        }
    }

    /**
     * @inheritdoc IBondMinter
     */
    function isInstance(address bond) external view override returns (bool) {
        return _mintedBonds[bond];
    }
}

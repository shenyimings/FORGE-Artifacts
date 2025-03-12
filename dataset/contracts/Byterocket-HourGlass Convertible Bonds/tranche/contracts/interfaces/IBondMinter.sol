pragma solidity >=0.4;

import "./IBondConfigVault.sol";
import "./IBondFactory.sol";

/**
 * @title BondMinter Interface
 * @notice Interface for canonically minting bonds according to a stored vaults of configurations
 */
interface IBondMinter is IBondConfigVault {
    /**
     * @notice Event emitted when a new bond is minted using this minter
     * @param bond The address of the newly minted bond
     */
    event BondMinted(address bond);

    /**
     * @notice Sets the bondFactory
     * @param _bondFactory The bondFactory that will be used mint the bonds
     */
    function setBondFactory(IBondFactory _bondFactory) external;

    /**
     * @notice Sets the waitingPeriod required between minting periods
     * @param _waitingPeriod The minimum waiting period (in seconds) between mints
     */
    function setWaitingPeriod(uint256 _waitingPeriod) external;

    /**
     * @notice Iterates over configurations and mints bonds for each using the bondFactory
     */
    function mintBonds() external;

    /**
     * @notice Checks if a given bond was instantiated by the minter
     */
    function isInstance(address bond) external view returns (bool);
}

pragma solidity 0.5.16;

interface StationConfig {
    /// @dev Return minimum ETH debt size per position.
    function minDebtSize() external view returns (uint256);

    /// @dev Return the interest rate per second, using 1e18 as denom.
    function getInterestRate(uint256 debt, uint256 floating) external view returns (uint256);

    /// @dev Return the bps rate for reserve pool.
    function getStarGateBps() external view returns (uint256);

    /// @dev Return the bps rate for Avada Kill caster.
    function getTerminateBps() external view returns (uint256);

    /// @dev Return whether the given address is a orbit.
    function isOrbit(address orbit) external view returns (bool);

    /// @dev Return whether the given orbit accepts more debt. Revert on non-orbit.
    function acceptDebt(address orbit) external view returns (bool);

    /// @dev Return the work factor for the orbit + ETH debt, using 1e4 as denom. Revert on non-orbit.
    function launcher(address orbit, uint256 debt) external view returns (uint256);

    /// @dev Return the kill factor for the orbit + ETH debt, using 1e4 as denom. Revert on non-orbit.
    function terminator(address orbit, uint256 debt) external view returns (uint256);
}

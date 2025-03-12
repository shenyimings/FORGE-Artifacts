pragma solidity 0.5.16;

interface OrbitConfig {
    /// @dev Return whether the given orbit accepts more debt.
    function acceptDebt(address orbit) external view returns (bool);
    /// @dev Return the work factor for the orbit + ETH debt, using 1e4 as denom.
    function launcher(address orbit, uint256 debt) external view returns (uint256);
    /// @dev Return the kill factor for the orbit + ETH debt, using 1e4 as denom.
    function terminator(address orbit, uint256 debt) external view returns (uint256);
}

pragma solidity 0.5.16;

interface Orbit {
    /// @dev Work on a (potentially new) position. Optionally send ETH back to Bank.
    function launch(uint256 id, address user, uint256 debt, bytes calldata data) external payable;

    /// @dev Re-invest whatever the orbit is working on.
    function refuel() external;

    /// @dev Return the amount of ETH wei to get back if we are to liquidate the position.
    function condition(uint256 id) external view returns (uint256);

    /// @dev Liquidate the given position to ETH. Send all ETH back to Bank.
    function destroy(uint256 id, address user) external;
}

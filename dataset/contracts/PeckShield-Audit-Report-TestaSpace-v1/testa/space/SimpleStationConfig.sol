pragma solidity 0.5.16;
import "openzeppelin-solidity-2.3.0/contracts/ownership/Ownable.sol";
import "./StationConfig.sol";

contract SimpleStationConfig is StationConfig, Ownable {
    /// @notice Configuration for each orbit.
    struct OrbitConfig {
        bool isOrbit;
        bool acceptDebt;
        uint256 launcher;
        uint256 terminator;
    }

    /// The minimum ETH debt size per position.
    uint256 public minDebtSize;
    /// The interest rate per second, multiplied by 1e18.
    uint256 public interestRate;
    /// The portion of interests allocated to the reserve pool.
    uint256 public getStarGateBps;
    /// The reward for successfully killing a position.
    uint256 public getTerminateBps;
    /// Mapping for orbit address to its configuration.
    mapping (address => OrbitConfig) public orbits;

    constructor(
        uint256 _minDebtSize,
        uint256 _interestRate,
        uint256 _reserveGateBps,
        uint256 _terminateBps
    ) public {
        setParams(_minDebtSize, _interestRate, _reserveGateBps, _terminateBps);
    }

    /// @dev Set all the basic parameters. Must only be called by the owner.
    /// @param _minDebtSize The new minimum debt size value.
    /// @param _interestRate The new interest rate per second value.
    /// @param _reserveGateBps The new interests allocated to the reserve pool value.
    /// @param _terminateBps The new reward for killing a position value.
    function setParams(
        uint256 _minDebtSize,
        uint256 _interestRate,
        uint256 _reserveGateBps,
        uint256 _terminateBps
    ) public onlyOwner {
        minDebtSize = _minDebtSize;
        interestRate = _interestRate;
        getStarGateBps = _reserveGateBps;
        getTerminateBps = _terminateBps;
    }

    /// @dev Set the configuration for the given orbit. Must only be called by the owner.
    /// @param orbit The orbit address to set configuration.
    /// @param _isOrbit Whether the given address is a valid orbit.
    /// @param _acceptDebt Whether the orbit is accepting new debts.
    /// @param _launcher The work factor value for this orbit.
    /// @param _terminator The kill factor value for this orbit.
    function setOrbit(
        address orbit,
        bool _isOrbit,
        bool _acceptDebt,
        uint256 _launcher,
        uint256 _terminator
    ) public onlyOwner {
        orbits[orbit] = OrbitConfig({
            isOrbit: _isOrbit,
            acceptDebt: _acceptDebt,
            launcher: _launcher,
            terminator: _terminator
        });
    }

    /// @dev Return the interest rate per second, using 1e18 as denom.
    function getInterestRate(uint256 /* debt */, uint256 /* floating */) external view returns (uint256) {
        return interestRate;
    }

    /// @dev Return whether the given address is a orbit.
    function isOrbit(address orbit) external view returns (bool) {
        return orbits[orbit].isOrbit;
    }

    /// @dev Return whether the given orbit accepts more debt. Revert on non-orbit.
    function acceptDebt(address orbit) external view returns (bool) {
        require(orbits[orbit].isOrbit, "!orbit");
        return orbits[orbit].acceptDebt;
    }

    /// @dev Return the work factor for the orbit + ETH debt, using 1e4 as denom. Revert on non-orbit.
    function launcher(address orbit, uint256 /* debt */) external view returns (uint256) {
        require(orbits[orbit].isOrbit, "!orbit");
        return orbits[orbit].launcher;
    }

    /// @dev Return the kill factor for the orbit + ETH debt, using 1e4 as denom. Revert on non-orbit.
    function terminator(address orbit, uint256 /* debt */) external view returns (uint256) {
        require(orbits[orbit].isOrbit, "!orbit");
        return orbits[orbit].terminator;
    }
}

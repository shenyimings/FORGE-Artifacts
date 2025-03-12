pragma solidity 0.5.16;
import "openzeppelin-solidity-2.3.0/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity-2.3.0/contracts/math/SafeMath.sol";
import "./StationConfig.sol";
import "./OrbitConfig.sol";


interface InterestModel {
    /// @dev Return the interest rate per second, using 1e18 as denom.
    function getInterestRate(uint256 debt, uint256 floating) external view returns (uint256);
}

contract ThreeDegreeTrajectory {
    using SafeMath for uint256;

    /// @dev Return the interest rate per second, using 1e18 as denom.
    function getInterestRate(uint256 debt, uint256 floating) external pure returns (uint256) {
        uint256 total = debt.add(floating);
        uint256 utilization = debt.mul(100e18).div(total);
        if (utilization < 80e18) {
            // Less than 80% utilization - 0%-10% APY
            return utilization.mul(10e16).div(80e18) / 365 days;
        } else if (utilization < 90e18) {
            // Between 80% and 90% - 10% APY
            return uint256(10e16) / 365 days;
        } else if (utilization < 100e18) {
            // Between 90% and 100% - 10%-50% APY
            return (10e16 + utilization.sub(90e18).mul(40e16).div(10e18)) / 365 days;
        } else {
            // Not possible, but just in case - 50% APY
            return uint256(50e16) / 365 days;
        }
    }
}

contract ConfigurableInterestStationConfig is StationConfig, Ownable {
    /// The minimum ETH debt size per position.
    uint256 public minDebtSize;
    /// The portion of interests allocated to the reserve pool.
    uint256 public getStarGateBps;
    /// The reward for successfully killing a position.
    uint256 public getTerminateBps;
    /// Mapping for orbit address to its configuration.
    mapping (address => OrbitConfig) public orbits;
    /// Interest rate model
    InterestModel public interestModel;

    constructor(
        uint256 _minDebtSize,
        uint256 _reserveGateBps,
        uint256 _terminateBps,
        InterestModel _interestModel
    ) public {
        setParams(_minDebtSize, _reserveGateBps, _terminateBps, _interestModel);
    }

    /// @dev Set all the basic parameters. Must only be called by the owner.
    /// @param _minDebtSize The new minimum debt size value.
    /// @param _reserveGateBps The new interests allocated to the reserve pool value.
    /// @param _terminateBps The new reward for killing a position value.
    /// @param _interestModel The new interest rate model contract.
    function setParams(
        uint256 _minDebtSize,
        uint256 _reserveGateBps,
        uint256 _terminateBps,
        InterestModel _interestModel
    ) public onlyOwner {
        minDebtSize = _minDebtSize;
        getStarGateBps = _reserveGateBps;
        getTerminateBps = _terminateBps;
        interestModel = _interestModel;
    }

    /// @dev Set the configuration for the given orbits. Must only be called by the owner.
    function setOrbits(address[] calldata addrs, OrbitConfig[] calldata configs) external onlyOwner {
        require(addrs.length == configs.length, "bad length");
        for (uint256 idx = 0; idx < addrs.length; idx++) {
            orbits[addrs[idx]] = configs[idx];
        }
    }

    /// @dev Return the interest rate per second, using 1e18 as denom.
    function getInterestRate(uint256 debt, uint256 floating) external view returns (uint256) {
        return interestModel.getInterestRate(debt, floating);
    }

    /// @dev Return whether the given address is a orbit.
    function isOrbit(address orbit) external view returns (bool) {
        return address(orbits[orbit]) != address(0);
    }

    /// @dev Return whether the given orbit accepts more debt. Revert on non-orbit.
    function acceptDebt(address orbit) external view returns (bool) {
        return orbits[orbit].acceptDebt(orbit);
    }

    /// @dev Return the work factor for the orbit + ETH debt, using 1e4 as denom. Revert on non-orbit.
    function launcher(address orbit, uint256 debt) external view returns (uint256) {
        return orbits[orbit].launcher(orbit, debt);
    }

    /// @dev Return the kill factor for the orbit + ETH debt, using 1e4 as denom. Revert on non-orbit.
    function terminator(address orbit, uint256 debt) external view returns (uint256) {
        return orbits[orbit].terminator(orbit, debt);
    }
}

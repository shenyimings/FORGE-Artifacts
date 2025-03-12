// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./interfaces/IDackiePool.sol";

contract IDackie is Ownable {
    using SafeMath for uint256;

    IDackiePool public immutable dackiePool;

    address public admin;
    // threshold of locked duration
    uint256 public ceiling;

    // xCredit
    uint256 public multiplier;

    // xFactor
    uint256 public X_FACTOR = 1e12;

    uint256 public constant MIN_CEILING_DURATION = 1 weeks;

    event UpdateCeiling(uint256 newCeiling);
    event UpdateMultiplier(uint256 newMultiplier);

    /**
     * @notice Checks if the msg.sender is the admin address
     */
    modifier onlyAdmin() {
        require(msg.sender == admin, "None admin!");
        _;
    }

    /**
     * @notice Constructor
     * @param _dackiePool: Dackie pool contract
     * @param _admin: admin of the this contract
     * @param _ceiling: the max locked duration which the linear decrease start
     * @param _multiplier: xCredit
     */
    constructor(
        IDackiePool _dackiePool,
        address _admin,
        uint256 _ceiling,
        uint256 _multiplier
    ) public {
        require(_ceiling >= MIN_CEILING_DURATION, "Invalid ceiling duration");
        dackiePool = _dackiePool;
        admin = _admin;
        ceiling = _ceiling;
        multiplier = _multiplier;
    }

    /**
     * @notice calculate iDackie credit per user.
     * @param _user: user address.
     */
    function getUserCredit(address _user) external view returns (uint256) {
        require(_user != address(0), "getUserCredit: Invalid address");

        (, , , , uint256 lockStartTime, uint256 lockEndTime, , bool locked , uint256 lockedAmount) = dackiePool.userInfo(_user);

        if (!locked || block.timestamp > lockEndTime) {
            return 0;
        }

        // lockEndTime always >= lockStartTime
        uint256 lockDuration = lockEndTime.sub(lockStartTime);

        if (lockDuration >= ceiling) {
            return lockedAmount.mul(multiplier).div(X_FACTOR);
        } else if (lockDuration < ceiling && lockDuration >= 0) {
            return ((lockedAmount.mul(multiplier).div(X_FACTOR)).mul(lockDuration)).div(ceiling);
        }

        // If none of the above conditions are met, return 0.
        return 0;
    }

    /**
     * @notice update ceiling thereshold duration for iDackie calculation.
     * @param _newCeiling: new threshold duration.
     */
    function updateCeiling(uint256 _newCeiling) external onlyAdmin {
        require(_newCeiling >= MIN_CEILING_DURATION, "updateCeiling: Invalid ceiling");
        require(ceiling != _newCeiling, "updateCeiling: Ceiling not changed");
        ceiling = _newCeiling;
        emit UpdateCeiling(ceiling);
    }

    function updateMultiplier(uint256 _newMultiplier) external onlyAdmin {
        require(multiplier != _newMultiplier, "updateMultiplier: Multiplier not changed");
        multiplier = _newMultiplier;
        emit UpdateMultiplier(multiplier);
    }
}
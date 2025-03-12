// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

/*
 ██████╗ █████╗ ██╗   ██╗██╗        ██████╗ █████╗ ██╗     ██╗██████╗ ██╗████████╗██╗   ██╗
██╔════╝██╔══██╗██║   ██║██║       ██╔════╝██╔══██╗██║     ██║██╔══██╗██║╚══██╔══╝╚██╗ ██╔╝
╚█████╗ ██║  ██║██║   ██║██║       ╚█████╗ ██║  ██║██║     ██║██║  ██║██║   ██║    ╚████╔╝ 
 ╚═══██╗██║  ██║██║   ██║██║        ╚═══██╗██║  ██║██║     ██║██║  ██║██║   ██║     ╚██╔╝  
██████╔╝╚█████╔╝╚██████╔╝███████╗  ██████╔╝╚█████╔╝███████╗██║██████╔╝██║   ██║      ██║   
╚═════╝  ╚════╝  ╚═════╝ ╚══════╝  ╚═════╝  ╚════╝ ╚══════╝╚═╝╚═════╝ ╚═╝   ╚═╝      ╚═╝   

 * Twitter: https://twitter.com/SoulSolidity
 *  GitHub: https://github.com/SoulSolidity
 *     Web: https://SoulSolidity.com
 */

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Constants} from "../utils/Constants.sol";
import {SoulAccessManaged} from "../access/SoulAccessManaged.sol";

import {ISoulFeeManager} from "./ISoulFeeManager.sol";

/**
 * @title SoulFeeManager_Interface
 * @dev This contract is an interface for the SoulFeeManager. It includes a function for getting the fee based on epoch volume.
 * @author Soul Solidity - Contact for mainnet licensing until 730 days after first deployment transaction with matching bytecode.
 * Otherwise feel free to experiment locally or on testnets.
 */
contract SoulFeeManager is ISoulFeeManager, SoulAccessManaged {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// -----------------------------------------------------------------------
    /// Storage variables - External/Public
    /// -----------------------------------------------------------------------

    bool public override isSoulFeeManager = true;

    /// @dev Represents the fee under the given volume threshold.
    struct VolumeFeeThreshold {
        uint256 volume;
        uint256 fee;
    }
    /// @dev Assumes the volume fee thresholds are in ascending order. Final element assumes infinite volume
    VolumeFeeThreshold[] public volumeFeeThresholds;

    bytes32 public FEE_MANAGER_ROLE = _getRoleHash("FEE_MANAGER_ROLE");
    uint256 public constant FEE_DENOMINATOR = Constants.DENOMINATOR;
    /// @dev The maximum fee is 3%
    uint256 public constant MAX_FEE = (FEE_DENOMINATOR * 3) / 100;

    /// -----------------------------------------------------------------------
    /// Storage variables -  Internal/Private
    /// -----------------------------------------------------------------------

    EnumerableSet.AddressSet private _validFeeTokens;
    address private _feeCollector;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event SoulFeeManager_FeeTokenAdded(address feeToken);
    event SoulFeeManager_FeeTokenRemoved(address feeToken);
    event SoulFeeManager_VolumeFeeThresholdChanged(uint256[] _volumes, uint256[] _fees);

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error SoulFeeManager_InvalidFeeToken();
    error SoulFeeManager_InvalidFeeCollector();
    error SoulFeeManager_NoFeeTokensAdded();

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(
        address _accessRegistry,
        address[] memory _feeTokens,
        address __feeCollector,
        uint256[] memory _volumes,
        uint256[] memory _fees
    ) SoulAccessManaged(_accessRegistry) {
        _addValidFeeTokens(_feeTokens);
        if (__feeCollector == address(0)) {
            revert SoulFeeManager_InvalidFeeCollector();
        }
        _feeCollector = __feeCollector;
        _setVolumeFeeThresholds(_volumes, _fees);
    }

    /// -----------------------------------------------------------------------
    /// Volume Thresholds
    /// -----------------------------------------------------------------------

    function setVolumeFeeThresholds(
        uint256[] memory _volumes,
        uint256[] memory _fees
    ) external onlyAccessRegistryRole(FEE_MANAGER_ROLE) {
        _setVolumeFeeThresholds(_volumes, _fees);
    }

    function _setVolumeFeeThresholds(uint256[] memory _volumes, uint256[] memory _fees) internal {
        require(_volumes.length == _fees.length, "Volumes and fees should have same length");

        // Clear the existing volumeFeeThresholds array
        delete volumeFeeThresholds;

        uint256 previousVolume = 0;
        for (uint256 i = 0; i < _volumes.length; i++) {
            uint256 volume = _volumes[i];
            /// @dev On the first round previousVolume can be 0, so we skip the check
            require(i == 0 || volume > previousVolume, "Volume not in ascending order");
            require(_fees[i] <= MAX_FEE, "Fee exceeds max fee");
            VolumeFeeThreshold memory volumeFeeThreshold = VolumeFeeThreshold({volume: volume, fee: _fees[i]});
            volumeFeeThresholds.push(volumeFeeThreshold);
            previousVolume = volume;
        }
        emit SoulFeeManager_VolumeFeeThresholdChanged(_volumes, _fees);
    }

    /// -----------------------------------------------------------------------
    /// Fee Info
    /// -----------------------------------------------------------------------

    /**
     * @notice Retrieves fee information based on the provided volume.
     * @param _volume The volume of transactions to calculate the fee for.
     * @return feeTokens The list of valid fee tokens.
     * @return currentFeePercentage The calculated fee percentage based on the volume.
     * @return feeDenominator The denominator used to calculate fee percentages.
     * @return feeCollector The address of the fee collector.
     */
    function getFeeInfo(
        uint256 _volume
    )
        external
        view
        override
        returns (address[] memory feeTokens, uint256 currentFeePercentage, uint256 feeDenominator, address feeCollector)
    {
        feeTokens = getFeeTokens();
        currentFeePercentage = getFee(_volume);
        feeDenominator = FEE_DENOMINATOR;
        feeCollector = _feeCollector;
    }

    /**
     * @notice Retrieves the fee based on the provided epoch fee volume.
     * @param epochFeeVolume The volume of transactions in the current epoch.
     * @return fee The fee percentage corresponding to the given volume.
     */
    function getFee(uint256 epochFeeVolume) public view returns (uint256 fee) {
        for (uint256 i = volumeFeeThresholds.length - 1; i >= 0; i--) {
            if (epochFeeVolume >= volumeFeeThresholds[i].volume) {
                return volumeFeeThresholds[i].fee;
            }
        }
        return 0;
    }

    /// -----------------------------------------------------------------------
    /// Fee Collector
    /// -----------------------------------------------------------------------

    function getFeeCollector() external view returns (address feeCollector) {
        return _feeCollector;
    }

    /**
     * @notice Sets a new address as the fee collector.
     * @param newFeeCollector The new address to be set as the fee collector.
     */
    function setFeeCollector(address newFeeCollector) external onlyAccessRegistryRole(FEE_MANAGER_ROLE) {
        require(newFeeCollector != address(0), "Invalid fee collector address");
        _feeCollector = newFeeCollector;
    }

    /// -----------------------------------------------------------------------
    /// Fee Token Management
    /// -----------------------------------------------------------------------

    function getFeeToken(uint256 index) external view override returns (address token) {
        return _validFeeTokens.at(index);
    }

    /**
     * @notice This function returns the valid fee tokens.
     * @dev Warning: This function should not be used in state changing functions as it could be an unbounded length.
     * @return tokens An array of addresses representing the valid fee tokens.
     */
    function getFeeTokens() public view override returns (address[] memory tokens) {
        return _validFeeTokens.values();
    }

    function getFeeTokensLength() external view override returns (uint256 length) {
        return _validFeeTokens.length();
    }

    function isFeeToken(address _token) public view override returns (bool valid) {
        return _validFeeTokens.contains(_token);
    }

    function addValidFeeTokens(address[] memory _newValidFeeTokens) external onlyAccessRegistryRole(FEE_MANAGER_ROLE) {
        _addValidFeeTokens(_newValidFeeTokens);
    }

    /**
     * @notice Removes the specified fee tokens from the list of valid fee tokens.
     * @param tokens The array of fee tokens to be removed.
     */
    function removeValidFeeTokens(address[] memory tokens) external onlyAccessRegistryRole(FEE_MANAGER_ROLE) {
        for (uint256 i = 0; i < tokens.length; i++) {
            address tokenToRemove = tokens[i];
            if (_validFeeTokens.remove(tokenToRemove)) {
                emit SoulFeeManager_FeeTokenRemoved(tokenToRemove);
            }
        }
    }

    function _addValidFeeTokens(address[] memory _newValidFeeTokens) internal {
        bool feeTokenAdded = false;
        for (uint256 i = 0; i < _newValidFeeTokens.length; i++) {
            address newFeeToken = _newValidFeeTokens[i];
            if (newFeeToken == address(0)) {
                revert SoulFeeManager_InvalidFeeToken();
            }
            bool currentTokenAdded = _validFeeTokens.add(newFeeToken);
            // Set feeTokenAdded to tokenAdded if false, otherwise leave it as true
            if (currentTokenAdded) {
                feeTokenAdded = true;
                emit SoulFeeManager_FeeTokenAdded(newFeeToken);
            }
        }
        if (!feeTokenAdded) {
            revert SoulFeeManager_NoFeeTokensAdded();
        }
    }
}

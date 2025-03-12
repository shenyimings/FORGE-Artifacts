// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IFeesFacet } from "../Interfaces/IFeesFacet.sol";
import { LibFees } from "../Libraries/LibFees.sol";
import { LibAccess } from "../Libraries/LibAccess.sol";
import { LibDiamond } from "../Libraries/LibDiamond.sol";
import { ReentrancyGuard } from "../Helpers/ReentrancyGuard.sol";
import { TokenAddressIsZero, InvalidFee, ZeroAddress, AlreadyInitialized } from "../Errors/GenericErrors.sol";

error FeeTooHigh();
error ShareTooHigh();

contract FeesFacet is IFeesFacet, ReentrancyGuard {
    event SetFixedNativeFee(uint256 fee);
    event SetRubicPlatformFee(uint256 fee);
    event SetMaxRubicPlatformFee(uint256 fee);

    modifier onlyAuthorized() {
        if (msg.sender != LibDiamond.contractOwner()) {
            LibAccess.enforceAccessControl();
        }
        _;
    }

    /// @inheritdoc IFeesFacet
    function initialize(
        address _feeTreasure,
        uint256 _maxRubicPlatformFee,
        uint256 _maxFixedNativeFee
    ) external override {
        LibDiamond.enforceIsContractOwner();

        if (_feeTreasure == address(0)) {
            revert TokenAddressIsZero();
        }
        if (_maxRubicPlatformFee == 0) {
            revert InvalidFee();
        }
        if (_maxFixedNativeFee == 0) {
            revert InvalidFee();
        }

        LibFees.FeesStorage storage fs = LibFees.feesStorage();

        if (fs.initialized) {
            revert AlreadyInitialized();
        }

        fs.feeTreasure = _feeTreasure;
        fs.maxFixedNativeFee = _maxFixedNativeFee;
        fs.maxRubicPlatformFee = _maxRubicPlatformFee;
        fs.initialized = true;
    }

    /// @inheritdoc IFeesFacet
    function setFeeTreasure(
        address _feeTreasure
    ) external override onlyAuthorized {
        if (_feeTreasure == address(0)) {
            revert ZeroAddress();
        }

        LibFees.FeesStorage storage fs = LibFees.feesStorage();
        fs.feeTreasure = _feeTreasure;
    }

    /// @inheritdoc IFeesFacet
    function setMaxRubicPlatformFee(
        uint256 _maxFee
    ) external override onlyAuthorized {
        if (_maxFee > LibFees.DENOMINATOR) {
            revert FeeTooHigh();
        }

        LibFees.FeesStorage storage fs = LibFees.feesStorage();
        fs.maxRubicPlatformFee = _maxFee;

        emit SetMaxRubicPlatformFee(_maxFee);
    }

    /// @inheritdoc IFeesFacet
    function setRubicPlatformFee(
        uint256 _platformFee
    ) external override onlyAuthorized {
        LibFees.FeesStorage storage fs = LibFees.feesStorage();

        if (_platformFee > fs.maxRubicPlatformFee) {
            revert FeeTooHigh();
        }

        fs.RubicPlatformFee = _platformFee;

        emit SetRubicPlatformFee(_platformFee);
    }

    /// @inheritdoc IFeesFacet
    function setFixedNativeFee(
        uint256 _fixedNativeFee
    ) external override onlyAuthorized {
        LibFees.FeesStorage storage fs = LibFees.feesStorage();

        if (_fixedNativeFee > fs.maxFixedNativeFee) {
            revert FeeTooHigh();
        }

        fs.fixedNativeFee = _fixedNativeFee;

        emit SetFixedNativeFee(_fixedNativeFee);
    }

    /// @inheritdoc IFeesFacet
    function setIntegratorInfo(
        address _integrator,
        IntegratorFeeInfo memory _info
    ) external override onlyAuthorized {
        if (_info.tokenFee > LibFees.DENOMINATOR) {
            revert FeeTooHigh();
        }
        if (
            _info.RubicTokenShare > LibFees.DENOMINATOR ||
            _info.RubicFixedCryptoShare > LibFees.DENOMINATOR
        ) {
            revert ShareTooHigh();
        }

        LibFees.FeesStorage storage fs = LibFees.feesStorage();

        fs.integratorToFeeInfo[_integrator] = _info;
    }

    /// VIEW FUNCTIONS ///

    function calcTokenFees(
        uint256 _amount,
        address _integrator
    )
        external
        view
        override
        returns (uint256 totalFee, uint256 RubicFee, uint256 integratorFee)
    {
        LibFees.FeesStorage storage fs = LibFees.feesStorage();
        IntegratorFeeInfo memory info = fs.integratorToFeeInfo[_integrator];
        (totalFee, RubicFee) = LibFees._calculateFee(fs, _amount, info);
        integratorFee = totalFee - RubicFee;
    }

    function fixedNativeFee()
        external
        view
        override
        returns (uint256 _fixedNativeFee)
    {
        LibFees.FeesStorage storage s = LibFees.feesStorage();

        _fixedNativeFee = s.fixedNativeFee;
    }

    function RubicPlatformFee()
        external
        view
        override
        returns (uint256 _RubicPlatformFee)
    {
        LibFees.FeesStorage storage s = LibFees.feesStorage();

        _RubicPlatformFee = s.RubicPlatformFee;
    }

    function maxRubicPlatformFee()
        external
        view
        override
        returns (uint256 _maxRubicPlatformFee)
    {
        LibFees.FeesStorage storage s = LibFees.feesStorage();

        _maxRubicPlatformFee = s.maxRubicPlatformFee;
    }

    function maxFixedNativeFee()
        external
        view
        override
        returns (uint256 _maxFixedNativeFee)
    {
        LibFees.FeesStorage storage s = LibFees.feesStorage();

        _maxFixedNativeFee = s.maxFixedNativeFee;
    }

    function feeTreasure()
        external
        view
        override
        returns (address _feeTreasure)
    {
        LibFees.FeesStorage storage s = LibFees.feesStorage();

        _feeTreasure = s.feeTreasure;
    }

    function integratorToFeeInfo(
        address _integrator
    )
        external
        view
        override
        returns (IFeesFacet.IntegratorFeeInfo memory _info)
    {
        LibFees.FeesStorage storage s = LibFees.feesStorage();

        _info = s.integratorToFeeInfo[_integrator];
    }
}

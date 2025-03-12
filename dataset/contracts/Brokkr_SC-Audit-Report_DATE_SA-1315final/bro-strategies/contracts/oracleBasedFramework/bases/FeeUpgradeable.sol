// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../Common.sol";
import "../libraries/InvestableLib.sol";
import "../interfaces/IFee.sol";
import "../libraries/Math.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

struct FeeArgs {
    uint24 depositFee;
    NameValuePair[] depositFeeParams;
    uint24 withdrawalFee;
    NameValuePair[] withdrawFeeParams;
    uint24 performanceFee;
    NameValuePair[] performanceFeeParams;
    uint24 managementFee;
    NameValuePair[] managementFeeParams;
    address feeReceiver;
    NameValuePair[] feeReceiverParams;
}

abstract contract FeeUpgradeable is Initializable, IFee {
    uint24 internal withdrawalFee;
    uint24 internal depositFee;
    uint24 internal performanceFee;
    uint256 internal currentAccumulatedFee;
    uint256 internal claimedFee;
    address internal feeReceiver;
    uint24 internal managementFee;
    uint256 public tokenPriceHighWatermark;
    uint256[39] private __gap;

    // solhint-disable-next-line func-name-mixedcase
    function __FeeUpgradeable_init(
        FeeArgs calldata feeArgs,
        uint8 depositTokenDecimalCount
    ) internal onlyInitializing {
        // assumption: depositTokenDecimalCount >= InvestableLib.PRICE_PRECISION_DIGITS
        _setTokenPriceHighWatermark(
            (10 **
                (depositTokenDecimalCount -
                    InvestableLib.PRICE_PRECISION_DIGITS)) *
                Math.MEDIUM_FIXED_DECIMAL_FACTOR
        );
        _setDepositFee(feeArgs.depositFee, feeArgs.depositFeeParams);
        _setWithdrawalFee(feeArgs.withdrawalFee, feeArgs.withdrawFeeParams);
        _setPerformanceFee(
            feeArgs.performanceFee,
            feeArgs.performanceFeeParams
        );
        _setManagementFee(feeArgs.managementFee, feeArgs.managementFeeParams);
        _setFeeReceiver(feeArgs.feeReceiver, feeArgs.feeReceiverParams);
    }

    modifier checkFee(uint24 fee) {
        if (fee >= uint256(100) * Math.SHORT_FIXED_DECIMAL_FACTOR)
            revert InvalidFeeError();

        _;
    }

    function getDepositFee(NameValuePair[] calldata)
        public
        view
        virtual
        returns (uint24)
    {
        return depositFee;
    }

    function _setDepositFee(uint24 fee, NameValuePair[] calldata params)
        internal
        virtual
        checkFee(fee)
    {
        depositFee = fee;
        emit DepositFeeChange(depositFee, params);
    }

    function getWithdrawalFee(NameValuePair[] calldata)
        public
        view
        virtual
        returns (uint24)
    {
        return withdrawalFee;
    }

    function _setWithdrawalFee(uint24 fee, NameValuePair[] calldata params)
        internal
        virtual
        checkFee(fee)
    {
        withdrawalFee = fee;
        emit WithdrawalFeeChange(withdrawalFee, params);
    }

    function getPerformanceFee(NameValuePair[] calldata)
        public
        view
        virtual
        returns (uint24)
    {
        return performanceFee;
    }

    function _setPerformanceFee(uint24 fee, NameValuePair[] calldata params)
        internal
        virtual
        checkFee(fee)
    {
        performanceFee = fee;
        emit PerformanceFeeChange(performanceFee, params);
    }

    function _setTokenPriceHighWatermark(uint256 newTokenPriceHighWaterMark)
        internal
        virtual
    {
        tokenPriceHighWatermark = newTokenPriceHighWaterMark;
    }

    function getManagementFee(NameValuePair[] calldata)
        public
        view
        virtual
        returns (uint24)
    {
        return managementFee;
    }

    function _setManagementFee(uint24 fee, NameValuePair[] calldata params)
        internal
        virtual
        checkFee(fee)
    {
        managementFee = fee;
        emit ManagementFeeChange(managementFee, params);
    }

    function getFeeReceiver(NameValuePair[] calldata)
        external
        view
        virtual
        returns (address)
    {
        return feeReceiver;
    }

    function _setFeeReceiver(
        address feeReceiver_,
        NameValuePair[] calldata params
    ) internal virtual {
        if (feeReceiver_ == address(0)) revert ZeroFeeReceiver();

        feeReceiver = feeReceiver_;
        emit FeeReceiverChange(feeReceiver, params);
    }

    function getCurrentAccumulatedFee() public view virtual returns (uint256) {
        return currentAccumulatedFee;
    }

    function getClaimedFee() public view virtual returns (uint256) {
        return claimedFee;
    }

    function setClaimedFee(uint256 claimedFee_) internal virtual {
        claimedFee = claimedFee_;
    }

    function setCurrentAccumulatedFee(uint256 currentAccumulatedFee_)
        internal
        virtual
    {
        currentAccumulatedFee = currentAccumulatedFee_;
    }
}

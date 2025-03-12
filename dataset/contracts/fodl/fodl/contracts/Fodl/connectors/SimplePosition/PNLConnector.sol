// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';

import '../interfaces/IPNLConnector.sol';
import '../../modules/SimplePosition/SimplePositionStorage.sol';
import '../../modules/PNL/PNLStorage.sol';
import '../../modules/Lender/LendingDispatcher.sol';

contract PNLConnector is SimplePositionStorage, LendingDispatcher, PNLStorage, IPNLConnector {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 private constant MANTISSA = 1e18;

    function configurePNL(
        uint256 priceTarget,
        uint256 fixedReward,
        uint256 percentageReward,
        uint256 unwindFactor,
        bool isTakeProfit
    ) external override onlyAccountOwner {
        require(isSimplePosition(), 'SP1');
        require(unwindFactor <= MANTISSA, 'PNL1');
        require(percentageReward <= MANTISSA, 'PNL2');

        SimplePositionStore memory sp = simplePositionStore();
        address lender = getLender(sp.platform);

        if (isTakeProfit) {
            require(
                priceTarget >
                    getReferencePrice(lender, sp.platform, sp.supplyToken).mul(MANTISSA) /
                        getReferencePrice(lender, sp.platform, sp.borrowToken),
                'PNL3'
            );
        } else {
            require(
                priceTarget <
                    getReferencePrice(lender, sp.platform, sp.supplyToken).mul(MANTISSA) /
                        getReferencePrice(lender, sp.platform, sp.borrowToken),
                'PNL3'
            );
        }

        pnlStore().pnlSettings.push(
            PNLSettings(priceTarget, fixedReward, percentageReward, unwindFactor, isTakeProfit)
        );
    }

    function removePNLSetting(uint256 index) external override onlyAccountOwner {
        removePNLInternal(index);
    }

    function removeAllPNLSettings() external override onlyAccountOwner {
        delete pnlStore().pnlSettings;
    }

    function executePNL(uint256 index, bool withApproval) external override returns (uint256) {
        PNLSettings memory configuration = pnlStore().pnlSettings[index];
        removePNLInternal(index);
        SimplePositionStore memory sp = simplePositionStore();

        address platform = sp.platform;
        address supplyToken = sp.supplyToken;
        address borrowToken = sp.borrowToken;
        address lender = getLender(platform);
        uint256 priceOfSupplyToken = getReferencePrice(lender, platform, supplyToken);
        uint256 priceOfBorrowToken = getReferencePrice(lender, platform, borrowToken);

        if (configuration.isTakeProfit) {
            require(priceOfSupplyToken.mul(MANTISSA) / priceOfBorrowToken >= configuration.priceTarget, 'PNL4');
        } else {
            require(priceOfSupplyToken.mul(MANTISSA) / priceOfBorrowToken <= configuration.priceTarget, 'PNL4');
        }

        uint256 repayAmount = configuration.unwindFactor.mul(getBorrowBalance(lender, platform, borrowToken)) /
            MANTISSA;

        uint256 redeemAmount = (repayAmount.mul(priceOfBorrowToken.mul(MANTISSA + configuration.percentageReward)) /
            (priceOfSupplyToken.mul(MANTISSA))).add(configuration.fixedReward);

        address caller = aStore().entryCaller;
        if (withApproval) IERC20(borrowToken).safeTransferFrom(caller, address(this), repayAmount);
        repayBorrow(lender, platform, borrowToken, repayAmount);
        redeemSupply(lender, platform, supplyToken, redeemAmount);
        IERC20(supplyToken).safeTransfer(caller, redeemAmount);
        return redeemAmount;
    }

    /// @dev    simply deleting the storage at the index is not enough,
    ///         as it would leave an empty gap in the array. We need to move the
    ///         targeted element to the tail, and then pop.
    function removePNLInternal(uint256 index) internal {
        PNLStore storage store = pnlStore();
        uint256 length = store.pnlSettings.length;
        require(index < length, 'PNL5');

        if (index != length - 1) {
            store.pnlSettings[index] = store.pnlSettings[length - 1];
        }

        store.pnlSettings.pop();
    }

    function getAllPNLSettings() external override returns (PNLSettings[] memory) {
        return pnlStore().pnlSettings;
    }

    function getPNLSettingsAt(uint256 index) external override returns (PNLSettings memory) {
        return pnlStore().pnlSettings[index];
    }

    function getPNLState() external override returns (PNLState memory state) {
        SimplePositionStore memory sp = simplePositionStore();
        if (!isSimplePosition()) return state;

        PNLSettings[] memory settings = pnlStore().pnlSettings;

        state.platform = sp.platform;
        state.supplyToken = sp.supplyToken;
        state.borrowToken = sp.borrowToken;

        state.supplyBalance = getSupplyBalance(getLender(sp.platform), sp.platform, sp.supplyToken);
        state.borrowBalance = getBorrowBalance(getLender(sp.platform), sp.platform, sp.borrowToken);

        state.priceOfBorrowToken = getReferencePrice(getLender(sp.platform), sp.platform, sp.borrowToken);
        state.priceOfSupplyToken = getReferencePrice(getLender(sp.platform), sp.platform, sp.supplyToken);
        state.simulations = new PNLSimulations[](settings.length);

        uint256 currentPrice = state.priceOfSupplyToken.mul(MANTISSA) / state.priceOfBorrowToken;

        for (uint256 i = 0; i < settings.length; i++) {
            uint256 repayAmount = settings[i].unwindFactor.mul(state.borrowBalance) / MANTISSA;
            uint256 redeemAmount = (repayAmount.mul(
                state.priceOfBorrowToken.mul(MANTISSA + settings[i].percentageReward)
            ) / (state.priceOfSupplyToken.mul(MANTISSA))).add(settings[i].fixedReward);

            string memory reason;
            bool canBeTriggered = true;

            if (
                settings[i].isTakeProfit
                    ? currentPrice < settings[i].priceTarget
                    : currentPrice > settings[i].priceTarget
            ) {
                canBeTriggered = false;
                reason = 'Price target not reached';
            } else if (redeemAmount > state.supplyBalance) {
                canBeTriggered = false;
                reason = 'Incentive exceeds supply balance';
            }

            state.simulations[i] = PNLSimulations(canBeTriggered, reason, settings[i]);
        }
    }
}

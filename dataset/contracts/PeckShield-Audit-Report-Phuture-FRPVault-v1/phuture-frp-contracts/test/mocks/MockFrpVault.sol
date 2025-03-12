// SPDX-License-Identifier: Apache-2.0
pragma solidity =0.8.13;

import "../../src/FRPVault.sol";
import "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

contract MockFrpVault is FRPVault {
    function _maxLoss() public view returns (uint16) {
        return maxLoss;
    }

    function _lastTransferTime() public view returns (uint96) {
        return lastTransferTime;
    }

    function _feeRecipient() public view returns (address) {
        return feeRecipient;
    }

    function _VAULT_ADMIN_ROLE() public pure returns (bytes32) {
        return VAULT_ADMIN_ROLE;
    }

    function _VAULT_MANAGER_ROLE() public pure returns (bytes32) {
        return VAULT_MANAGER_ROLE;
    }

    function _HARVESTER_ROLE() public pure returns (bytes32) {
        return HARVESTER_ROLE;
    }

    function _BP() public pure returns (uint16) {
        return BP;
    }

    function _fCashPositions() public view returns (address[] memory) {
        address[] memory positions = new address[](2);
        for (uint i = 0; i < 2; i++) {
            positions[i] = fCashPositions[i];
        }
        return positions;
    }

    function __sortMarketsByOracleRate()
        public
        view
        returns (NotionalMarket memory lowestYieldMarket, NotionalMarket memory highestYieldMarket)
    {
        return _sortMarketsByOracleRate();
    }

    function __getThreeAndSixMonthMarkets() public view returns (NotionalMarket[] memory) {
        return _getThreeAndSixMonthMarkets();
    }

    function getAUMFee(uint _lastTransfer) public view returns (uint) {
        uint timePassed = _lastTransfer - lastTransferTime;
        if (timePassed != 0) {
            return
                ((totalSupply() - balanceOf(feeRecipient)) *
                    (AUMCalculationLibrary.rpow(
                        AUM_SCALED_PER_SECONDS_RATE,
                        timePassed,
                        AUMCalculationLibrary.RATE_SCALE_BASE
                    ) - AUMCalculationLibrary.RATE_SCALE_BASE)) / AUMCalculationLibrary.RATE_SCALE_BASE;
        }
        return 0;
    }
}

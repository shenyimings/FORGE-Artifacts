// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "./ITreasuryTracker.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRWACalculator {
    function calculate(IERC20 treasuryToken)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            bool
        );

    function fetchPaymentTokenAndAmountFtnft(
        address ftnft,
        uint256 fractionId,
        uint256 share
    )
        external
        view
        returns (
            IERC20,
            uint256,
            bool
        );

    function fetchPaymentTokenAndAmountTnft(
        address tnft,
        uint256 fingerprint,
        uint256 tokenId,
        uint256 _years,
        bool unminted
    )
        external
        view
        returns (
            IERC20,
            uint256,
            bool
        );

    function calcFractionNativeValue(address ftnft, uint256 share)
        external
        view
        returns (string memory currency, uint256 value);

    function calcTnftNativeValue(address tnft, uint256 fingerprint)
        external
        view
        returns (string memory currency, uint256 value);
}
